using Test
using Random

include("../src/game.jl")
include("../src/strategy.jl")
include("../src/submission.jl")   
include("../src/demo.jl")

function diamond_graph()
    v = [Vertex(i) for i in 1:4]
    e = [Edge(1, v[1], v[2], 0.0, :neutral),
         Edge(2, v[2], v[4], 0.0, :neutral),
         Edge(3, v[1], v[3], 0.0, :neutral),
         Edge(4, v[3], v[4], 0.0, :neutral)]
    return GameGraph(v, e, v[1], v[4])
end

mkstate(g) = GameState(g, :short, Tuple{Symbol,Edge}[], nothing) # baut gamestate ohne kantenzustände zurückzusetzen 

# ───────────────────────────────────────────────────────────────────────────
# Test-Helfer
# ───────────────────────────────────────────────────────────────────────────

# Baut einen GameGraph aus Knotenzahl und (u,v)-Paaren; alle Kanten neutral.
function mach_graph(n::Int, paare; s::Int = 1, t::Int = n)
    vertices = [Vertex(i) for i in 1:n]
    edges = [Edge(i, vertices[a], vertices[b], 0.0, :neutral)
             for (i, (a, b)) in enumerate(paare)]
    return GameGraph(vertices, edges, vertices[s], vertices[t])
end

# Ist T (Menge von Kantenindizes) ein Spannbaum von (n, kanten)?
function ist_spannbaum(T, kanten, n)::Bool
    length(T) == n - 1 || return false
    parent = collect(1:n)
    find(a) = (while parent[a] != a; parent[a] = parent[parent[a]]; a = parent[a]; end; a)
    for i in T
        (u, v) = kanten[i]
        ru, rv = find(u), find(v)
        ru == rv && return false          # Kreis
        parent[ru] = rv
    end
    return length(unique(find(v) for v in 1:n)) == 1   # zusammenhängend
end

# Bilden die Kantenindizes `weg` einen einfachen s-t-Weg in `kanten`?
# (Endknoten s,t haben Grad 1, alle inneren Knoten Grad 2.)
function bildet_st_weg(weg, kanten, s, t)::Bool
    isempty(weg) && return s == t
    grad = Dict{Int,Int}()
    for i in weg
        (u, v) = kanten[i]
        grad[u] = get(grad, u, 0) + 1
        grad[v] = get(grad, v, 0) + 1
    end
    get(grad, s, 0) == 1 || return false
    get(grad, t, 0) == 1 || return false
    for (v, d) in grad
        v == s || v == t || d == 2 || return false
    end
    return true
end

# Feste Kantenlisten (Erwartungswerte extern gegen Brute-Force verifiziert):
const K4   = [(1,2),(1,3),(1,4),(2,3),(2,4),(3,4)]                     # 2 EDST: ja
const C5   = [(1,2),(2,3),(3,4),(4,5),(1,5)]                           # 2 EDST: nein
const P4   = [(1,2),(2,3),(3,4)]                                       # Baum: nein
const E6   = [(1,2),(1,5),(1,6),(2,5),(2,6),(3,4),(3,5),(3,6),(4,6),(5,6)]  # 2 EDST: ja
const EXP  = [(1,2),(2,3),(3,4),(4,5),(1,3),(3,5),(2,5),(1,4)]         # example_graph

# Block A: besitzt zwei kantendisjunkte Spannbäume, und s = 1 und t = 5 sind
# darin NICHT benachbart — Short gewinnt also, aber nicht im ersten Zug.
const BLOCK_A   = [(1,2),(1,3),(1,4),(2,4),(2,5),(3,4),(3,5),(4,5)]
const K4_HINTEN = [(6,7),(6,8),(6,9),(7,8),(7,9),(8,9)]
const A_PLUS_K4 = vcat(BLOCK_A, K4_HINTEN)                  # zweiter Block, unverbunden
const A_BRUECKE = vcat(BLOCK_A, [(5,6)], K4_HINTEN)         # zweiter Block über eine Brücke

@testset "Shannon Switching Game" begin

    @testset "new_game" begin
        state = new_game(diamond_graph())
        @test state.current_player == :short          # Short beginnt
        @test state.winner === nothing
        @test isempty(state.history)
        @test all(e.state == :neutral for e in state.graph.edges)
    end

    @testset "valid_moves" begin
        state = new_game(diamond_graph())
        @test length(valid_moves(state)) == 4         # anfangs alle Kanten frei
        make_move!(state, state.graph.edges[1])
        @test length(valid_moves(state)) == 3         # eine Kante belegt
        @test all(e.state == :neutral for e in valid_moves(state))
    end

    @testset "make_move! (Zug, Spielerwechsel, History)" begin
        state = new_game(diamond_graph())
        e = state.graph.edges[1]
        make_move!(state, e)
        @test e.state == :short                       # Short sichert
        @test state.current_player == :cut            # Spieler gewechselt
        @test state.history == [(:short, e)]
        e2 = state.graph.edges[3]
        make_move!(state, e2)
        @test e2.state == :cut                         # Cut entfernt
        @test state.current_player == :short
        @test length(state.history) == 2
    end

    @testset "check_winner" begin
        # short gewinnt
        g = diamond_graph()
        g.edges[1].state = :short
        g.edges[2].state = :short
        @test check_winner(mkstate(g)) == :short

        # cut gewinnt
        g2 = diamond_graph()
        g2.edges[1].state = :cut      # s-a weg
        g2.edges[4].state = :cut      # b-t weg
        @test check_winner(mkstate(g2)) == :cut

        # Noch offen.
        g3 = diamond_graph()
        g3.edges[1].state = :short
        @test check_winner(mkstate(g3)) === nothing
    end

    @testset "find_path" begin
        g = diamond_graph()
        weg = find_path(g, g.s.id, g.t.id, s -> s == :neutral || s == :short)
        @test !isempty(weg)                            # es gibt einen Weg
        # Alle Kanten entfernen -> kein Weg mehr.
        for e in g.edges; e.state = :cut; end
        @test isempty(find_path(g, g.s.id, g.t.id, s -> s == :neutral))
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "find_path (Beispielgraph)" begin
        g = mach_graph(5, EXP)                      # s=1, t=5, alles neutral

        weg = find_path(g, 1, 5, st -> st == :neutral)
        @test !isempty(weg)
        @test all(g.edges[i].state == :neutral for i in weg)
        @test bildet_st_weg(weg, EXP, 1, 5)
        @test length(weg) == 2                      # BFS: kürzester Weg (z. B. 1-3-5)

        @test find_path(g, 3, 3, st -> st == :neutral) == Int[]   # from == to
        @test find_path(g, 1, 5, st -> st == :short) == Int[]     # keine Short-Kanten -> kein Weg

        # Weg respektiert `allowed`: blockiere alle Kanten an Knoten 5 außer (4,5)
        for i in (4, 6, 7)                          # (4,5),(3,5),(2,5)
            g.edges[i].state = :cut
        end
        @test find_path(g, 1, 5, st -> st == :neutral) == Int[]   # 5 ist abgeschnitten
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "spanning_tree" begin
        kanten = [(1,2),(2,3),(3,4),(1,4),(1,3)]
        T = spanning_tree(4, kanten)
        @test T == Set([1,2,3])                     # deterministisch: erste kreisfreie Kanten
        @test ist_spannbaum(T, kanten, 4)

        @test spanning_tree(4, [(1,2),(3,4)]) === nothing    # unzusammenhängend
        @test spanning_tree(2, [(1,2)]) == Set([1])          # Minimalfall

        TK4 = spanning_tree(4, K4)
        @test TK4 !== nothing && ist_spannbaum(TK4, K4, 4)
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "fundamental_cycle" begin
        kanten = [(1,2),(2,3),(3,4),(1,4),(1,3)]
        T = Set([1,2,3])                            # Weg 1-2-3-4

        fc4 = fundamental_cycle(T, kanten, 4, 4)    # Sehne (1,4)
        @test Set(fc4) == Set([1,2,3])
        fc5 = fundamental_cycle(T, kanten, 4, 5)    # Sehne (1,3)
        @test Set(fc5) == Set([1,2])

        @test all(i in T for i in fc4)              # nur Baumkanten
        @test 4 ∉ fc4 && 5 ∉ fc5                    # die Sehne selbst nie enthalten
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "augment_along_common_chord!" begin
        # Multigraph: 3 Parallelkanten zwischen 1 und 2 (n = 2)
        multi = [(1,2),(1,2),(1,2)]
        T1, T2 = Set([1]), Set([1])
        @test augment_along_common_chord!(T1, T2, multi, 2, 2) == true
        @test length(setdiff(T1, T2)) == 1          # Distanz 0 -> 1 (Maximum bei n=2)
        @test ist_spannbaum(T1, multi, 2) && ist_spannbaum(T2, multi, 2)
        # T1, T2 jetzt disjunkt -> weitere Augmentierung muss scheitern:
        T1, T2 = Set([2]), Set([1])
        @test augment_along_common_chord!(T1, T2, multi, 2, 3) == false
        @test T1 == Set([2]) && T2 == Set([1])      # Fehlschlag lässt Bäume unverändert

        # E6-Instanz (verifizierte Spur): T1/T2 mit |T1 ∩ T2| = 2
        T1 = Set([1,4,5,6,9]);  T2 = Set([3,5,7,8,9])
        d0 = length(setdiff(T1, T2))
        @test augment_along_common_chord!(T1, T2, E6, 6, 2) == true
        @test 2 in T1                               # Sehne e landet in T1
        @test length(setdiff(T1, T2)) == d0 + 1     # Distanz steigt um genau 1
        @test ist_spannbaum(T1, E6, 6) && ist_spannbaum(T2, E6, 6)
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "maximally_distant_trees! / _has_two_disjoint_spanning_trees" begin
        T1 = spanning_tree(6, E6); T2 = spanning_tree(6, E6)
        maximally_distant_trees!(T1, T2, E6, 6)
        @test isempty(intersect(T1, T2))            # E6 zerfällt in 2 disjunkte Bäume
        @test ist_spannbaum(T1, E6, 6) && ist_spannbaum(T2, E6, 6)

        @test _has_two_disjoint_spanning_trees(4, K4) == true
        @test _has_two_disjoint_spanning_trees(6, E6) == true
        @test _has_two_disjoint_spanning_trees(5, C5) == false   # Kreis: zu wenig Kanten
        @test _has_two_disjoint_spanning_trees(4, P4) == false   # Baum
        @test _has_two_disjoint_spanning_trees(4, [(1,2),(3,4)]) == false  # unzush.
        @test _has_two_disjoint_spanning_trees(1, Tuple{Int,Int}[]) == true  # n <= 1
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "_contract_short / _contracted_neutral" begin
        # Dreieck: (1,2) short, (2,3) cut, (1,3) neutral; s=1, t=3
        g = mach_graph(3, [(1,2),(2,3),(1,3)]; s = 1, t = 3)
        g.edges[1].state = :short
        g.edges[2].state = :cut

        N, repof = _contract_short(g)
        @test N == 2                                # {1,2} verschmolzen, {3} einzeln
        @test repof(1) == repof(2)
        @test repof(1) != repof(3)

        N2, kanten, sN, tN = _contracted_neutral(g)
        @test N2 == 2
        @test length(kanten) == 1                   # nur (1,3); Cut-Kante fehlt
        @test sN != tN
        @test Set(kanten[1]) == Set((repof(1), repof(3)))

        # Ohne Short-Kanten: Identität
        g2 = mach_graph(5, EXP)
        N3, kanten3, s3, t3 = _contracted_neutral(g2)
        @test N3 == 5 && length(kanten3) == length(EXP) && s3 != t3

        # Short verbindet s und t -> gleicher Superknoten
        g3 = mach_graph(3, [(1,2),(2,3),(1,3)]; s = 1, t = 3)
        g3.edges[1].state = :short; g3.edges[2].state = :short
        _, _, s4, t4 = _contracted_neutral(g3)
        @test s4 == t4

        # Neutrale Kante INNERHALB eines Superknotens wird verworfen (Schlinge)
        g4 = mach_graph(3, [(1,2),(1,2),(2,3)]; s = 1, t = 3)   # Parallelkante
        g4.edges[1].state = :short
        _, kanten4, _, _ = _contracted_neutral(g4)
        @test length(kanten4) == 1                  # nur (2,3); die parallele (1,2) fällt weg
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "_degree / _alive_has_two_trees" begin
        kanten = [(1,2),(1,3),(2,3),(1,4)]
        alive  = trues(4)
        @test _degree(kanten, alive, 1) == 3
        @test _degree(kanten, alive, 4) == 1
        alive[4] = false
        @test _degree(kanten, alive, 1) == 2        # (1,4) zählt nicht mehr

        alive_k4 = trues(4)
        @test _alive_has_two_trees(4, K4, alive_k4) == true
        alive_k4[4] = false                          # K4 minus Knoten = Dreieck
        @test _alive_has_two_trees(4, K4, alive_k4) == false
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "_two_tree_connected" begin
        @test _two_tree_connected(3, [(1,2)], 2, 2) == true     # s == t
        @test _two_tree_connected(5, C5, 1, 5) == false
        @test _two_tree_connected(4, K4, 1, 4) == true
        @test _two_tree_connected(6, E6, 1, 6) == true
        # E6 plus toter Anhang (Knoten 7 am Blatt): Peeling muss ihn entfernen
        E6b = vcat(E6, [(1,7)])
        @test _two_tree_connected(7, E6b, 1, 6) == true
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "_completes_short_path / _short_wins_as_second" begin
        g = mach_graph(3, [(1,2),(2,3),(1,3)]; s = 1, t = 3)

        @test _completes_short_path(g, g.edges[3]) == true       # (1,3) direkt
        @test g.edges[3].state == :neutral                       # Zustand restauriert
        @test _completes_short_path(g, g.edges[1]) == false      # (1,2) reicht nicht

        g.edges[1].state = :short
        @test _completes_short_path(g, g.edges[2]) == true       # 1-2 short + (2,3)
        g.edges[1].state = :neutral

        g.edges[2].state = :cut
        @test _completes_short_path(g, g.edges[2]) == false      # nicht-neutrale Kante
        @test g.edges[2].state == :cut                           # bleibt cut
        g.edges[2].state = :neutral

        # example_graph ist so stark, dass Short sogar als ZWEITER gewinnt:
        @test _short_wins_as_second(mach_graph(5, EXP)) == true
        # Auf dem Kreis hat Short als Zweiter keine Chance:
        @test _short_wins_as_second(mach_graph(5, C5)) == false
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "short_strategy: Einzelzug" begin
        # Sofortgewinn-Zweig, deterministisch: Dreieck, Kante (1,3) gewinnt sofort
        g = mach_graph(3, [(1,2),(2,3),(1,3)]; s = 1, t = 3)
        state = new_game(g)
        e = short_strategy(state)
        @test e.id == 3                              # muss die Direktkante wählen

        # Rückgabe ist immer eine neutrale Kante; kein Zustand wird verändert
        g2 = mach_graph(5, EXP)
        state2 = new_game(g2)
        vorher = [e.state for e in g2.edges]
        e2 = short_strategy(state2)
        @test e2.state == :neutral
        @test [e.state for e in g2.edges] == vorher
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "short_strategy: volle Partien" begin
        # example_graph ist ein Short-Spiel -> Short muss mit optimaler Strategie
        # JEDE Partie gegen einen beliebig (zufällig) spielenden Cut gewinnen.
        for seed in 1:25
            Random.seed!(seed)
            state = new_game(mach_graph(5, EXP))
            while state.winner === nothing && !isempty(valid_moves(state))
                e = state.current_player == :short ?
                    short_strategy(state) : rand(valid_moves(state))
                make_move!(state, e)
            end
            @test state.winner == :short
        end

        # Robustheit auf Zufallsgraphen: Strategie liefert stets legale Züge,
        # Spiel terminiert mit einem Gewinner (egal welchem).
        for seed in 1:10
            Random.seed!(seed)
            state = new_game(random_graph(6, rand(6:12)))
            while state.winner === nothing && !isempty(valid_moves(state))
                e = state.current_player == :short ?
                    short_strategy(state) : rand(valid_moves(state))
                @test e.state == :neutral            # nur legale Züge
                make_move!(state, e)
            end
            @test state.winner !== nothing
        end
    end

    @testset "short_strategy gewinnt das Short-Spiel" begin
        # example_graph ist ein Short-Spiel: Short gewinnt gegen jedes Cut-Spiel.
        for seed in 1:20
            Random.seed!(seed)
            state = new_game(example_graph())
            while state.winner === nothing && !isempty(valid_moves(state))
                e = state.current_player == :short ? short_strategy(state) :
                                                     rand(valid_moves(state))
                make_move!(state, e)
            end
            @test state.winner == :short
        end
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Regression: Graphen, die in mehrere dichte Blöcke zerfallen.
    #
    # Block A enthält s und t und besitzt zwei kantendisjunkte Spannbäume.
    # Hängt man einen zweiten dichten Block an — unverbunden oder über eine
    # Brücke —, ändert das an Block A nichts, Short gewinnt weiterhin.
    #
    # Eine frühere Fassung entfernte an dieser Stelle den Knoten mit dem
    # kleinsten Grad und versuchte es erneut. Haben beide Blöcke denselben
    # Mindestgrad, trifft das einen Knoten aus Block A, zerstört die Lösung und
    # meldet fälschlich, Short habe keine Gewinnstellung. Zufallsgraphen sehen
    # praktisch nie so aus, deshalb blieb das lange unentdeckt.
    # ───────────────────────────────────────────────────────────────────────────
    @testset "Blockstrukturen" begin
        @test _two_tree_connected(5, BLOCK_A,   1, 5) == true
        @test _two_tree_connected(9, A_PLUS_K4, 1, 5) == true
        @test _two_tree_connected(9, A_BRUECKE, 1, 5) == true

        # Zwei K4 über eine Brücke: die Brücke selbst kann nie dazugehören.
        zwei_k4 = vcat(K4, [(4,5)], [(a + 4, b + 4) for (a, b) in K4])
        @test _two_tree_connected(8, zwei_k4, 1, 3) == true

        # Und in der Partie: Short muss gewinnen, egal wie Cut spielt.
        for seed in 1:5
            Random.seed!(seed)
            state = new_game(mach_graph(9, A_PLUS_K4; s = 1, t = 5))
            while state.winner === nothing && !isempty(valid_moves(state))
                e = state.current_player == :short ? short_strategy(state) :
                                                     rand(valid_moves(state))
                make_move!(state, e)
            end
            @test state.winner == :short
        end
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "cut_strategy: Einzelzug" begin
        # Sofortgewinn: auf einem Weg trennt jede Kante s von t.
        g = mach_graph(3, [(1,2),(2,3)]; s = 1, t = 3)
        state = GameState(g, :cut, Tuple{Symbol,Edge}[], nothing)
        make_move!(state, cut_strategy(state))
        @test state.winner == :cut

        # Rückgabe ist eine neutrale Kante; kein Zustand wird verändert.
        g2 = mach_graph(5, EXP)
        state2 = new_game(g2)
        make_move!(state2, g2.edges[1])             # Short zieht, dann ist Cut dran
        @test state2.current_player == :cut
        vorher = [x.state for x in g2.edges]
        e2 = cut_strategy(state2)
        @test e2.state == :neutral
        @test [x.state for x in g2.edges] == vorher
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "cut_strategy gewinnt das Cut-Spiel" begin
        # Der Fünferkreis mit s = 1 und t = 3 ist ein Cut-Spiel: Cut gewinnt,
        # egal wer beginnt. Mit optimalem Cut darf also keine Partie verloren
        # gehen, wie auch immer Short spielt.
        for seed in 1:15
            Random.seed!(seed)
            state = new_game(mach_graph(5, C5; s = 1, t = 3))
            while state.winner === nothing && !isempty(valid_moves(state))
                e = state.current_player == :cut ? cut_strategy(state) :
                                                   rand(valid_moves(state))
                make_move!(state, e)
            end
            @test state.winner == :cut
        end
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "beide Strategien gegeneinander" begin
        # Spielen beide Seiten fehlerfrei, hängt der Ausgang nur am Graphen:
        # Short-Spiel -> Short gewinnt, Cut-Spiel -> Cut gewinnt.
        for (paare, n, s, t, erwartet) in ((EXP, 5, 1, 5, :short),
                                           (K4,  4, 1, 4, :short),
                                           (C5,  5, 1, 3, :cut),
                                           ([(1,2),(2,3)], 3, 1, 3, :cut))
            state = new_game(mach_graph(n, paare; s = s, t = t))
            while state.winner === nothing && !isempty(valid_moves(state))
                e = state.current_player == :short ? short_strategy(state) :
                                                     cut_strategy(state)
                make_move!(state, e)
            end
            @test state.winner == erwartet
        end
    end

    # ───────────────────────────────────────────────────────────────────────────
    @testset "spielgraph" begin
        for seed in 1:20
            Random.seed!(seed)
            g = spielgraph()
            n = length(g.vertices)
            @test 5 <= n <= 7
            @test length(g.edges) > n - 1                 # nie ein Baum
            @test all(e.state == :neutral for e in g.edges)
            @test path_exists(g, g.s.id, g.t.id, z -> z == :neutral)   # zusammenhängend
            # s und t sind nie benachbart
            @test !any((e.u.id == g.s.id && e.v.id == g.t.id) ||
                       (e.u.id == g.t.id && e.v.id == g.s.id) for e in g.edges)
        end
    end
end
