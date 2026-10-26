

"""
    example_graph() -> GameGraph

Ein kleiner fester Beispielgraph auf 5 Knoten (s = 1, t = 5).
"""
function example_graph()::GameGraph
    vertices = [Vertex(i) for i in 1:5]
    paare = [(1, 2), (2, 3), (3, 4), (4, 5),     
             (1, 3), (3, 5), (2, 5), (1, 4)]     
    edges = [Edge(i, vertices[a], vertices[b], 0.0, :neutral)
             for (i, (a, b)) in enumerate(paare)]
    return GameGraph(vertices, edges, vertices[1], vertices[5])
end

_edge_label(e::Edge) = "{$(e.u.id),$(e.v.id)}" 


"""
    demo_short()

Spielt eine komplette Partie auf example_graph(): Short wird von der optimalen
short_strategy gesteuert, Cut zieht zufällig. Jeder Zug wird ausgegeben.

"""
function demo_short()
    state = new_game(example_graph())
    println("Demo: optimale Short-Strategie\n")

    zug = 0
    while state.winner === nothing && !isempty(valid_moves(state))
        zug += 1
        if state.current_player == :short
            e = short_strategy(state)               # optimale Wahl
            println("Zug $zug – Short spielt  $(_edge_label(e))") 
        else
            e = rand(valid_moves(state))            # Cut zufällig
            println("Zug $zug – Cut entfernt $(_edge_label(e))")
        end
        make_move!(state, e) # ziehe den zug
    end

    println()
    if state.winner == :short
        println("Short hat gewonnen!")
    elseif state.winner == :cut
        println("Cut hat gewonnen.")
    end
    return state
end

"""
    demo_bots(graph = spielgraph())

Lässt beide optimalen Strategien gegeneinander antreten und gibt jeden Zug
aus. Wer gewinnt, entscheidet allein der Graph: Erfüllt er die Bedingung des
Satzes von Lehman, gewinnt Short, sonst Cut. Beide Seiten spielen fehlerfrei,
also ist das Ergebnis bei gleichem Graphen immer dasselbe.
"""
function demo_bots(graph::GameGraph = spielgraph())
    state = new_game(deepcopy(graph))
    println("Demo: optimale Short-Strategie gegen optimale Cut-Strategie")
    println("Graph: $(length(state.graph.vertices)) Knoten, ",
            "$(length(state.graph.edges)) Kanten, ",
            "s = $(state.graph.s.id), t = $(state.graph.t.id)\n")

    zug = 0
    while state.winner === nothing && !isempty(valid_moves(state))
        zug += 1
        if state.current_player == :short
            e = short_strategy(state)
            println("Zug $zug – Short sichert  $(_edge_label(e))")
        else
            e = cut_strategy(state)
            println("Zug $zug – Cut  entfernt $(_edge_label(e))")
        end
        make_move!(state, e)
    end

    println()
    println(state.winner == :short ? "Short hat gewonnen." : "Cut hat gewonnen.")
    return state
end

"""
    demo_weighted(; n = 6, m = 9, seed = 1)

Spielt eine Partie auf einem zufälligen GEWICHTETEN Graphen: weighted_short
gegen weighted_cut. Jeder Zug und sein Gewicht werden ausgegeben, am Ende der
Wert des günstigsten s-t-Wegs, den Short erreicht hat (= Shorts Punktzahl;
kleiner ist besser).
"""
function demo_weighted(; n::Int = 6, m::Int = 9)
    state = new_game(random_graph(n, m; weighted = true))
    println("Demo: gewichtete Heuristiken ($n Knoten, $m Kanten), random_graph")

    zug = 0
    while state.winner === nothing && !isempty(valid_moves(state))
        zug += 1
        if state.current_player == :short
            e = weighted_short(state)
            println("Zug $zug – Short spielt  $(_edge_label(e))  (Gewicht $(e.weight))")
        else
            e = weighted_cut(state)
            println("Zug $zug – Cut  entfernt $(_edge_label(e))  (Gewicht $(e.weight))")
        end
        make_move!(state, e)
    end

    # Günstigsten s-t-Weg unter Shorts gesicherten Kanten bestimmen.
    g   = state.graph
    weg = find_path(g, g.s.id, g.t.id, s -> s == :short)
    println()
    if isempty(weg) && g.s.id != g.t.id
        println("Short hat keine Verbindung geschafft.")
    else
        kosten = sum(g.edges[i].weight for i in weg; init = 0.0) # summe aller gewichte der kanten von short
        println("Short hat s und t verbunden.")
        println("Gewicht von Short: $kosten")
    end
    return state
end
