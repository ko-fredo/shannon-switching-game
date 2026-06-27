
const TEAM_NAME = "WT19"


# Hilfsfunktionen

_wt_neutral_edges(state::GameState) = [e for e in state.graph.edges if e.state == :neutral] # alle neutralen kanten


function _wt_adj(g::GameGraph, allowed::Function) # genau das gleiche wie in game.jl
    d = Dict{Int,Vector{Tuple{Int,Int}}}()
    for v in g.vertices
        d[v.id] = Tuple{Int,Int}[]
    end
    for (i, e) in enumerate(g.edges)
        if allowed(e.state)
            push!(d[e.u.id], (e.v.id, i))
            push!(d[e.v.id], (e.u.id, i))
        end
    end
    return d
end


function _wt_path_exists(g::GameGraph, from::Int, to::Int, allowed::Function)::Bool # wie game.jl
    from == to && return true
    adj  = _wt_adj(g, allowed)
    seen = Set{Int}([from]); queue = Int[from]
    while !isempty(queue)
        u = popfirst!(queue)
        for (v, _) in adj[u]
            v == to && return true
            if v ∉ seen
                push!(seen, v); push!(queue, v)
            end
        end
    end
    return false
end

# Günstigster s-t-Weg (Dijkstra). Schon gesicherte Short-Kanten kosten 0.
# Rückgabe: Kanten-Indizes des Weges (oder [], falls keiner existiert).
function _wt_cheapest_path(g::GameGraph)
    dist = Dict(v.id => Inf for v in g.vertices); dist[g.s.id] = 0.0
    prev = Dict{Int,Tuple{Int,Int}}(); done = Set{Int}()
    adj  = _wt_adj(g, s -> s == :neutral || s == :short)

    while true
        u, d_u = -1, Inf
        for (v, d) in dist
            (v ∉ done && d < d_u) && (u = v; d_u = d)
        end
        (u == -1 || u == g.t.id) && break
        push!(done, u)
        for (v, idx) in adj[u]
            v in done && continue
            e = g.edges[idx]
            w = e.state == :short ? 0.0 : e.weight
            if dist[u] + w < get(dist, v, Inf)
                dist[v] = dist[u] + w; prev[v] = (u, idx)
            end
        end
    end

    haskey(prev, g.t.id) || return Int[]
    path, cur = Int[], g.t.id
    while cur != g.s.id
        haskey(prev, cur) || return Int[]
        p, i = prev[cur]; push!(path, i); cur = p
    end
    return path
end


function _wt_cheapest_path_weight(g::GameGraph) # kosten des günstigsten s-t-wegs
    path = _wt_cheapest_path(g)
    isempty(path) && return (g.s.id == g.t.id ? 0.0 : Inf)
    return sum(g.edges[i].state == :short ? 0.0 : g.edges[i].weight for i in path; init = 0.0)
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
    g     = state.graph
    zuege = _wt_neutral_edges(state)
    isempty(zuege) && error("weighted_short: keine Züge möglich")

    # Direkte Fertigstellung einer Verbindung sichert Punkte.
    for e in zuege
        _wt_completes_short_path(g, e) && return e
    end

    weg        = _wt_cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && return first(zuege)

    basis = _wt_cheapest_path_weight(g)
    beste, max_schaden = kandidaten[1], -Inf
    for e in kandidaten
        e.state = :cut
        schaden = _wt_cheapest_path_weight(g) - basis
        e.state = :neutral
        schaden > max_schaden && (max_schaden = schaden; beste = e)
    end
    return beste
end

"""
    weighted_cut(state::GameState) -> Edge

Entfernt die Kante, die den günstigsten s-t-Weg am stärksten verteuert.
"""
function weighted_cut(state::GameState)::Edge
    g     = state.graph
    zuege = _wt_neutral_edges(state)
    isempty(zuege) && error("weighted_cut: keine Züge möglich")

    # Sofortgewinn: trennt ein Zug s und t vollständig?
    for e in zuege
        e.state  = :cut
        getrennt = !_wt_path_exists(g, g.s.id, g.t.id, s -> s == :neutral || s == :short)
        e.state  = :neutral
        getrennt && return e
    end

    weg        = _wt_cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && (kandidaten = zuege)

    grosse_zahl(x) = isinf(x) ? 1e9 : x
    basis = _wt_cheapest_path_weight(g)
    beste, max_schaden = kandidaten[1], -Inf
    for e in kandidaten
        e.state = :cut
        neu     = _wt_cheapest_path_weight(g)
        e.state = :neutral
        schaden = grosse_zahl(neu) - grosse_zahl(basis)
        schaden > max_schaden && (max_schaden = schaden; beste = e)
    end
    return beste
end
