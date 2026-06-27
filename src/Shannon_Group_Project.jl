module Shannon_Group_Project

using Random

include("game.jl")      # Datenstrukturen + Spiellogik
include("strategy.jl")  # Computerstrategie (Short) + Wettbewerbsheuristiken
include("gui.jl")       # Gtk4-Fenster + Cairo-Zeichnung
include("demo.jl")      # Vorführ-Funktionen für die Präsentation

# Datenstrukturen
export Vertex, Edge, GameGraph, GameState

# Spiellogik
export new_game, valid_moves, make_move!, check_winner, random_graph

# Optimale Strategie für das klassische Spiel (nur Short)
export short_strategy

# Wettbewerbsstrategien (gewichtetes Spiel)
export TEAM_NAME, weighted_short, weighted_cut

# Visualisierung
export run_game

# Beispielgraph + Vorführung
export example_graph, demo_short, demo_weighted

end # module Shannon_Group_Project
