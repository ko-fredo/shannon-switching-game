module Shannon_Group_Project

using Random

include("game.jl")      
include("strategy.jl") 
include("demo.jl")     
include("gui.jl")       

export Vertex, Edge, GameGraph, GameState
export new_game, valid_moves, make_move!, check_winner, random_graph
export short_strategy
export TEAM_NAME, weighted_short, weighted_cut
export run_game
export example_graph, demo_short, demo_weighted

end 
