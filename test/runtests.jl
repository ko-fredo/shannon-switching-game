# Ausführen aus dem Projektordner:
#   julia --project=. test/runtests.jl

using Test
using Random

include("../src/game.jl")
include("../src/strategy.jl")
include("../src/demo.jl")

# Kleiner Helfer: ein "Diamant"-Graph s-a-b-t wie in der Aufgaben-PDF.
#   Knoten 1=s, 2=a, 3=b, 4=t ; Kanten s-a, a-t, s-b, b-t
function diamond_graph()
    v = [Vertex(i) for i in 1:4]
    e = [Edge(1, v[1], v[2], 0.0, :neutral),
         Edge(2, v[2], v[4], 0.0, :neutral),
         Edge(3, v[1], v[3], 0.0, :neutral),
         Edge(4, v[3], v[4], 0.0, :neutral)]
    return GameGraph(v, e, v[1], v[4])
end

# GameState bauen, OHNE die Kantenzustände zurückzusetzen (anders als new_game).
# Praktisch, um check_winner mit von Hand gesetzten Zuständen zu prüfen.
mkstate(g) = GameState(g, :short, Tuple{Symbol,Edge}[], nothing)

@testset "Shannon-Switching-Spiel" begin

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
        # Short gewinnt: s-a und a-t gehören Short -> durchgehender Weg.
        g = diamond_graph()
        g.edges[1].state = :short
        g.edges[2].state = :short
        @test check_winner(mkstate(g)) == :short

        # Cut gewinnt: beide Wege unterbrochen.
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
end
