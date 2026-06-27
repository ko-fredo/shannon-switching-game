# ═══════════════════════════════════════════════════════════════════════════════
# Vorführ-Skript für die Projektvorstellung
#
# Diese Datei enthält KEINE Spiellogik, sondern nur kleine Hilfen, mit denen man
# in der REPL zeigen kann, dass
#   * die optimale Short-Strategie ein Short-Spiel sicher gewinnt, und
#   * die Heuristiken im gewichteten Spiel sinnvolle Züge machen.
#
# Aufrufen in der REPL:
#   julia> using Shannon_Group_Project
#   julia> demo_short()      # zeigt die optimale Short-Strategie
#   julia> demo_weighted()   # zeigt die gewichteten Heuristiken
# ═══════════════════════════════════════════════════════════════════════════════

"""
    example_graph() -> GameGraph

Ein kleiner fester Beispielgraph auf 5 Knoten (s = 1, t = 5).

Er besteht aus ZWEI kantendisjunkten Spannbäumen und ist damit ein klassisches
"Short-Spiel": mit optimaler Strategie gewinnt Short immer. Bewusst gibt es
KEINE direkte Kante s–t, damit man in `demo_short()` sieht, wie Short die
Verbindung über mehrere Züge aufbaut und auf Cuts Züge reagiert. Dieser Graph
ist auch der Startgraph der grafischen Oberfläche.
"""
function example_graph()::GameGraph
    vertices = [Vertex(i) for i in 1:5]
    # Baum A (ein Weg) + Baum B – zusammen 8 Kanten, kantendisjunkt, ohne 1–5.
    paare = [(1, 2), (2, 3), (3, 4), (4, 5),     # Baum A
             (1, 3), (3, 5), (2, 5), (1, 4)]     # Baum B
    edges = [Edge(i, vertices[a], vertices[b], 0.0, :neutral)
             for (i, (a, b)) in enumerate(paare)]
    return GameGraph(vertices, edges, vertices[1], vertices[5])
end

# Kanten hübsch als "{u,v}" ausgeben.
_edge_label(e::Edge) = "{$(e.u.id),$(e.v.id)}"

"""
    demo_short()

Spielt eine komplette Partie auf `example_graph()`: Short wird von der optimalen
`short_strategy` gesteuert, Cut zieht zufällig. Jeder Zug wird ausgegeben.
Da der Graph ein Short-Spiel ist, gewinnt Short am Ende immer – egal wie Cut zieht.
"""
function demo_short()
    state = new_game(example_graph())
    println("=== Demo: optimale Short-Strategie ===")
    println("Short spielt optimal, Cut spielt zufällig.\n")

    zug = 0
    while state.winner === nothing && !isempty(valid_moves(state))
        zug += 1
        if state.current_player == :short
            e = short_strategy(state)               # optimale Wahl
            println("Zug $zug – Short sichert  $(_edge_label(e))")
        else
            e = rand(valid_moves(state))            # Cut zufällig
            println("Zug $zug – Cut  entfernt $(_edge_label(e))")
        end
        make_move!(state, e)
    end

    println()
    if state.winner == :short
        println("Ergebnis: Short hat gewonnen – wie von der Theorie vorhergesagt. ✓")
    elseif state.winner == :cut
        println("Ergebnis: Cut hat gewonnen (sollte hier nicht passieren!).")
    else
        println("Ergebnis: unentschieden / kein Gewinner.")
    end
    return state
end

"""
    demo_weighted(; n = 6, m = 9, seed = 1)

Spielt eine Partie auf einem zufälligen GEWICHTETEN Graphen: `weighted_short`
gegen `weighted_cut`. Jeder Zug und sein Gewicht werden ausgegeben, am Ende der
Wert des günstigsten s-t-Wegs, den Short erreicht hat (= Shorts Punktzahl;
kleiner ist besser).
"""
function demo_weighted(; n::Int = 6, m::Int = 9, seed::Int = 1)
    Random.seed!(seed)                              # reproduzierbar für die Vorführung
    state = new_game(random_graph(n, m; weighted = true))
    println("=== Demo: gewichtete Heuristiken ($n Knoten, $m Kanten) ===")
    println("weighted_short gegen weighted_cut.\n")

    zug = 0
    while state.winner === nothing && !isempty(valid_moves(state))
        zug += 1
        if state.current_player == :short
            e = weighted_short(state)
            println("Zug $zug – Short sichert  $(_edge_label(e))  (Gewicht $(e.weight))")
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
        println("Short hat KEINE Verbindung geschafft → hohe Strafpunktzahl.")
    else
        kosten = sum(g.edges[i].weight for i in weg; init = 0.0)
        println("Short hat s und t verbunden.")
        println("Gewicht von Shorts Weg (= Punktzahl, kleiner ist besser): $kosten")
    end
    return state
end
