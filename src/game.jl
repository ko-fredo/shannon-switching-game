
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

# Adjazenzliste über die Kanten, deren Zustand `allowed` erfüllt:
# Knoten-id -> [(Nachbar, Kantenindex)]. Ein Vector statt eines Dict, weil
# die Knoten von 1 bis n durchnummeriert sind — spart Hashing und eine
# Dictionary-Allokation pro Aufruf, und die Funktion liegt im heißen Pfad.
function adjacency_list(g::GameGraph, allowed::Function)   # O(n+m)
    nmax = 0
    for v in g.vertices
        v.id > nmax && (nmax = v.id)
    end

    adj = [Tuple{Int,Int}[] for _ in 1:nmax]
    for (edge_id, edge) in enumerate(g.edges)
        if allowed(edge.state)
            push!(adj[edge.u.id], (edge.v.id, edge_id))
            push!(adj[edge.v.id], (edge.u.id, edge_id))
        end
    end
    return adj
end

function path_exists(g::GameGraph, x::Int, y::Int, allowed::Function)::Bool   # O(n+m)
    x == y && return true

    adj = adjacency_list(g, allowed)
    n = length(adj)

    # Breitensuche mit Lesezeiger statt popfirst!, das wäre pro Zugriff O(n).
    besucht = falses(n); besucht[x] = true
    queue = Vector{Int}(undef, n); queue[1] = x
    kopf, ende = 1, 1

    while kopf <= ende
        current = queue[kopf]; kopf += 1
        for (nachbar, _) in adj[current]
            nachbar == y && return true     # Zielknoten gefunden
            if !besucht[nachbar]
                besucht[nachbar] = true
                ende += 1; queue[ende] = nachbar
            end
        end
    end

    return false    # y nie erreicht, also gibt es keinen Weg
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

"""
    spielgraph(; n = rand(5:7), weighted = false) -> GameGraph

Zufallsgraph, auf dem sich eine Partie lohnt. `random_graph` darf alles von
einem Baum bis zum vollständigen Graphen liefern; beides ergibt keine
Partie: Auf einem Baum gewinnt Cut mit dem ersten beliebigen Zug auf dem
einzigen Weg, und sind s und t benachbart, gewinnt Short sofort im ersten
Zug.

Dieser Erzeuger garantiert deshalb: s und t sind nie benachbart, es ist nie
ein Baum, und die Knotenzahl bleibt klein genug, dass die Bots flüssig
ziehen.
"""
function spielgraph(; n::Int = rand(5:7), weighted::Bool = false)::GameGraph
    n >= 4 || throw(ArgumentError("spielgraph: es werden mindestens 4 Knoten benötigt"))
    s, t = 1, n

    # Alle Kanten außer s-t.
    moeglich = Tuple{Int,Int}[(a, b) for a in 1:n for b in (a + 1):n
                              if !(a == s && b == t)]
    untere = n + 2                                   # mehr als ein Baum
    obere  = min(length(moeglich), 3 * n)
    m = rand(untere:max(untere, obere))

    vertices = [Vertex(i) for i in 1:n]
    nextweight() = weighted ? round(1.0 + 9.0 * rand(); digits = 2) : 0.0

    # Zufälliger Spannbaum über eine gemischte Kantenreihenfolge sichert den
    # Zusammenhang, ohne dass s-t gebraucht wird.
    reihenfolge = shuffle(moeglich)
    eltern = collect(1:n)
    function wurzel(a::Int)
        while eltern[a] != a
            eltern[a] = eltern[eltern[a]]
            a = eltern[a]
        end
        return a
    end

    gewaehlt = Tuple{Int,Int}[]
    for (a, b) in reihenfolge
        ra, rb = wurzel(a), wurzel(b)
        if ra != rb
            eltern[ra] = rb
            push!(gewaehlt, (a, b))
        end
    end

    # Mit weiteren Kanten auffüllen, bis m erreicht ist.
    drin = Set(gewaehlt)
    for kante in reihenfolge
        length(gewaehlt) >= m && break
        if kante ∉ drin
            push!(drin, kante); push!(gewaehlt, kante)
        end
    end

    edges = [Edge(i, vertices[a], vertices[b], nextweight(), :neutral)
             for (i, (a, b)) in enumerate(gewaehlt)]
    return GameGraph(vertices, edges, vertices[s], vertices[t])
end