
struct Vertex
    id::Int
end

mutable struct Edge
    id::Int
    u::Vertex
    v::Vertex
    weight::Float64
    state::Symbol
end

struct GameGraph
    vertices::Vector{Vertex}
    edges::Vector{Edge}
    s::Vertex
    t::Vertex
end

mutable struct GameState
    graph::GameGraph
    current_player::Symbol
    history::Vector{Tuple{Symbol, Edge}}
    winner::Union{Symbol, Nothing}
end

"""
    new_game(g::GameGraph) -> GameState

Erstellt einen neuen Spielzustand für den Graphen `g`: alle Kanten werden auf
`:neutral` gesetzt, Short beginnt, kein Gewinner.
"""
function new_game(g::GameGraph)::GameState
    for e in g.edges
        e.state = :neutral
    end

    GameState(g, :short, Tuple{Symbol, Edge}[], nothing)
end


"""
    valid_moves(state::GameState) -> Vector{Edge}

Gibt alle neutralen Kanten zurück, die der aktuelle Spieler wählen darf.
"""
function valid_moves(state::GameState)::Vector{Edge}
    return Edge[e for e in state.graph.edges if e.state == :neutral]
end

"""
    make_move!(state::GameState, e::Edge) -> Nothing

Führt den Zug des aktuellen Spielers auf Kante `e` aus: Short setzt
`e.state = :short`, Cut setzt `e.state = :cut`. Aktualisiert `history`,
wechselt den aktiven Spieler und prüft die Gewinnbedingung.
"""
function make_move!(state::GameState, e::Edge)::Nothing
    if e.state != :neutral
        println("Diese Kante wurde bereits gewählt")
        return nothing
    end
    if !isnothing(state.winner)
        println("Das Spiel ist bereits beendet")
        return nothing
    end

    player = state.current_player

    if player == :short     # Kante dem current_player zuordnen
        e.state = :short
    else
        e.state = :cut
    end

    push!(state.history, (player, e))   # kante in history speichern

    if player == :short     # spieler wechseln
        state.current_player = :cut
    else
        state.current_player = :short
    end

    state.winner = check_winner(state)  # guckt ob jemand gewonnen hat

    return nothing
end

"""
    check_winner(state::GameState) -> Union{Symbol, Nothing}

Gibt `:short` zurück, falls Shorts beanspruchte Kanten einen s-t-Weg
umfassen; `:cut`, falls im verbleibenden Graphen kein s-t-Weg mehr
existiert; sonst `nothing`.
"""
function check_winner(state::GameState)::Union{Symbol, Nothing}
    g = state.graph

    # schaue ob es pfad gibt der nur über short-kanten verläuft
    if path_exists(g, g.s.id, g.t.id, is_short)
        return :short
    end

    # guckt ob short noch einen weg hat, selbst wenn man alle neutralen und short kanten verwendet. existiert kein weg, hat cut gewonnen
    if !path_exists(g, g.s.id, g.t.id, is_neutral_or_short)
        return :cut
    end

    return nothing
end

# Hilfsfunktionen

function adjacency_list(g::GameGraph, allowed::Function)
    adj_nodes = Dict{Int, Vector{Tuple{Int,Int}}}()
    for nodes in g.vertices               # leere liste für alle knoten
        adj_nodes[nodes.id] = Tuple{Int,Int}[]
    end

    for (edge_id, edge) in enumerate(g.edges)       # geht alle kanten durch
        if allowed(edge.state)                      # fragt ab ob state der edge short ist oder short und neutral (is_short und is_neurtal_or_short)
            push!(adj_nodes[edge.u.id], (edge.v.id, edge_id))       
            push!(adj_nodes[edge.v.id], (edge.u.id, edge_id))
        end
    end
    return adj_nodes
end

function path_exists(g::GameGraph, x::Int, y::Int, allowed::Function)::Bool
    if x==y
        return true
    end

    adj_nodes = adjacency_list(g, allowed)  #dict von adjacent knoten für BFS

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

    return false # wenn y nie gefunden wird gibt es keinen weg
end

function is_short(state::Symbol)::Bool
    return state == :short
end


function is_neutral_or_short(state::Symbol)::Bool
    return state == :neutral || state == :short
end

# Testgraphen

function random_graph(n::Int, m::Int; weighted::Bool=false)::GameGraph
    n >= 2 || throw(ArgumentError("Es werden mindestens 2 Knoten benötigt"))
    maxedges = n * (n - 1) ÷ 2
    (n - 1 <= m <= maxedges) ||
        throw(ArgumentError("m muss zwischen n-1 ($(n-1)) und n(n-1)/2 ($maxedges) liegen"))

    vertices = [Vertex(i) for i in 1:n]
    edges = Edge[]
    present = Set{Tuple{Int,Int}}()
    nextweight() = weighted ? round(1.0 + 9.0 * rand(); digits = 2) : 0.0
    edgekey(a, b) = a < b ? (a, b) : (b, a)

    # Zufälliger Spannbaum garantiert Zusammenhang.
    perm = randperm(n)
    for i in 2:n
        a = perm[i]
        b = perm[rand(1:i-1)]
        push!(present, edgekey(a, b))
        push!(edges, Edge(length(edges) + 1, vertices[a], vertices[b], nextweight(), :neutral))
    end

    # Restliche Kanten zufällig ergänzen (einfacher Graph, keine Schlingen).
    while length(edges) < m
        a = rand(1:n)
        b = rand(1:n)
        a == b && continue
        k = edgekey(a, b)
        k in present && continue
        push!(present, k)
        push!(edges, Edge(length(edges) + 1, vertices[a], vertices[b], nextweight(), :neutral))
    end

    return GameGraph(vertices, edges, vertices[1], vertices[n])
end