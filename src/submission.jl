
const TEAM_NAME = "WT19"


# Hilfsfunktionen

_wt_neutral_edges(state::GameState) = [e for e in state.graph.edges if e.state == :neutral] # alle neutralen kanten


function _wt_adj(g::GameGraph, allowed::Function) # genau das gleiche wie in game.jl
    adj_nodes = Dict{Int, Vector{Tuple{Int,Int}}}()
    for nodes in g.vertices               
        adj_nodes[nodes.id] = Tuple{Int,Int}[]
    end

    for (edge_id, edge) in enumerate(g.edges)       
        if allowed(edge.state)                      
            push!(adj_nodes[edge.u.id], (edge.v.id, edge_id))       
            push!(adj_nodes[edge.v.id], (edge.u.id, edge_id))
        end
    end
    return adj_nodes
end




function _wt_path_exists(g::GameGraph, x::Int, y::Int, allowed::Function)::Bool # wie game.jl
    if x==y
        return true
    end

    adj_nodes = _wt_adj(g, allowed)  #dict von adjacent knoten für BFS

    # basically BFS identisch zur Vorlesung und vorheriger PA
    visited = Set{Int}()
    push!(visited, x)
    queue = Int[x]

    while !isempty(queue)
        current = popfirst!(queue)      # erstes element aus queue

        for (adj_node, node_id) in adj_nodes[current] # geht alle nachbarn von knoten durch
            if adj_node == y        # guckt ob zielknoten y gefunden wurde
                return true
            end

            if adj_node ∉ visited # nicht besuchte in queue 
                push!(visited, adj_node)
                push!(queue, adj_node)
            end
        end
    end

    return false # wenn y nie gefunden wird -> kein weg
end


function _wt_cheapest_path(g::GameGraph) # Dijkstra Algorithmus
    dist = Dict(v.id => Inf for v in g.vertices); dist[g.s.id] = 0.0 # setzt die kosten aller knoten auf unendlich und den startknoten auf 0
    prev = Dict{Int,Tuple{Int,Int}}() # speichert vorherigen knoten + kanten id
    done = Set{Int}() # besuchte knoten
    adj  = _wt_adj(g, s -> s == :neutral || s == :short) # alle neutralen oder short kanten adjazenz

    while true
        u = -1
        d_u = Inf 
        for (v, d) in dist # geht alle knoten durch und sucht den mit den kleinsten kosten
            if v ∉ done && d < d_u # nur wenn noch nicht besucht
                u = v
                d_u = d
            end
        end


        if u == -1 || u == g.t.id # wenn kein knoten mehr gefunden wurde oder das ziel erreicht wurde break
            break
        end

        push!(done, u) # u ist done

        # Schaue alle Nachbarn von u an und versuche deren Distanz zu verbessern
        for (v, idx) in adj[u]
            v in done && continue  # bereits fertige Nachbarn überspringen

            e = g.edges[idx] # kante zwischen u und v

            w = e.state == :short ? 0.0 : e.weight # ist kante short, dann kostet sie nichts, sonst kostet sie das gewicht der kante

            # Gibt es über u einen günstigeren Weg zu v als den bisher bekannten?
            if dist[u] + w < get(dist, v, Inf) # get(dist, v, Inf) gibt dist[v] zurück, oder Inf wenn v nicht in dist ist
                dist[v] = dist[u] + w
                prev[v] = (u, idx) # speichert den vorherigen knoten u und die kanten id idx, die zu v führt
            end
        end
    end

    # Wenn das Ziel keinen Vorgänger hat, ist es nicht erreichbar
    if !haskey(prev, g.t.id)
        return Int[]
    end

    # pfad rekonstruieren
    path = Int[]
    cur = g.t.id
    while cur != g.s.id
        if !haskey(prev, cur)
            return Int[]  # wenn kein vorgänger existiert, dann ist kein weg möglich
        end
        p, i = prev[cur]   # vorgänger und kanten id
        push!(path, i)     
        cur = p            
    end

    return path
end


function _wt_cheapest_path_weight(g::GameGraph) # kosten des günstigsten s-t-wegs
    path = _wt_cheapest_path(g)
    if isempty(path)
        return g.s.id == g.t.id ? 0.0 : Inf # wenn s==t dann weg 0 sonst inf
    end
    total = 0.0
    for i in path
        edge = g.edges[i]
        if edge.state != :short
            total += edge.weight        # addiert das gewicht der kanten wenn sie nicht short sind
        end
    end
    return total
end


function _wt_completes_short_path(g::GameGraph, e::Edge) # guckt ob mit dem spielen von e ein weg gefunden worden ist
    e.state == :neutral || return false # nur wenn e neutral
    e.state = :short 
    ok = _wt_path_exists(g, g.s.id, g.t.id, s -> s == :short)
    e.state = :neutral
    return ok
end


# Wettbewerbsstrategie

"""
    weighted_short(state::GameState)::Edge

sichert auf dem günstigstem s-t-weg die Kante, deren Verlust den Weg am stärksten verteuern würde.
"""
function weighted_short(state::GameState)::Edge
    g = state.graph
    moves = _wt_neutral_edges(state)
    isempty(moves) && error("weighted_short: keine Züge möglich")

    
    for e in moves  # guckt ob weg fertiggestellt werden kann
        _wt_completes_short_path(g, e) && return e
    end

    weg = _wt_cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]  # alle neutralen kanten auf dem günstigsten weg
    isempty(kandidaten) && return first(moves)  # wenn keine kandidaten auf dem günstisten weg, dann einfach erste neutrale kante

    basis = _wt_cheapest_path_weight(g) # günstigster weg kosten
    beste, max_schaden = kandidaten[1], -Inf 
    for e in kandidaten
        e.state = :cut      # setzt die kante auf cut
        schaden = _wt_cheapest_path_weight(g) - basis # berechnet wieviel teurer der weg geworden ist 
        e.state = :neutral

        if schaden > max_schaden # wenn der schaden größer ist als der bisher größte, dann wird die kante als beste gesetzt
            max_schaden = schaden
            beste = e # setzt beste kante auf aktuelle kante
        end
    end

    return beste 
end

function very_large_number(x)
    if isinf(x)
        return 1e9
    else
        return x
    end
end

"""
    weighted_cut(state::GameState)::Edge

Entfernt die Kante, die den günstigsten s-t-Weg am stärksten verteuert.
"""
function weighted_cut(state::GameState)::Edge
    g = state.graph
    moves = _wt_neutral_edges(state)
    isempty(moves) && error("weighted_cut: keine Züge möglich")

    for e in moves  # guckt ob es einen direkten Sieg gibt
        e.state = :cut
        getrennt = !_wt_path_exists(g, g.s.id, g.t.id, s -> s == :neutral || s == :short) # wenn kein weg existiert hat cut gewonnen
        e.state = :neutral

        if getrennt
            return e
        end
    end

    weg = _wt_cheapest_path(g)   # analog zu short strategie
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && (kandidaten = moves) # nimmt einfach die neutralen kanten wenn keine kandidaten auf dem günstigsten weg sind
 
    basis = _wt_cheapest_path_weight(g)
    beste, max_schaden = kandidaten[1], -Inf # alles analog
    for e in kandidaten 
        e.state = :cut
        neu     = _wt_cheapest_path_weight(g)
        e.state = :neutral
        schaden = very_large_number(neu) - very_large_number(basis) # berechnet wieviel teurer der weg geworden ist. Wenn es unendlich ist, dann wird es auf eine milliarde gesetzt

        if schaden > max_schaden # entfernt genau die kante die den weg am meisten verteuert
            max_schaden = schaden
            beste = e
        end
    end
    return beste
end
