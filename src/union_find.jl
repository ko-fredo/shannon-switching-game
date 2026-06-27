mutable struct Node
    value::Int
    parent::Union{Node,Nothing}
end

"""
    union_find(data::Vector{Tuple{Int, Vector{Int}}})::Dict{Int, Node}

gibt ein Dictionary von Int zu Node zuruck, dass die Bäume der Union-Find Datenstruktur
speichert. Jedes Tupel besteht aus dem Repr¨asentanten i und der Liste aller Elemente seiner
Komponente; der Repr¨asentant muss in seiner eigenen Liste enthalten sein.

# Beispiel
```julia
julia> partition = [(1, [1, 2, 3]), (4, [4, 5]), (6, [6, 7, 8, 9])];
julia> nodes = union_find(partition)
Dict{Int64, Node} with 9 entries:
  5 => Node(5, Node(4, nothing))
  4 => Node(4, nothing)
  ...
```
"""

function union_find(data::Vector{Tuple{Int,Vector{Int}}})::Dict{Int,Node}
    nodes = Dict{Int,Node}() # legt dictionary an

    for (i, set) in data
        root = Node(i, nothing) # repräsentant zur wurzel
        nodes[i] = root
        for s in set # geht set durch und lässt alle knoten in set auf die wurzel zeigen 
            s == i && continue
            nodes[s] = Node(s, root)
        end
    end
    return nodes
end

"""
    find_set(node::Node)::Node

Gibt den Wurzelknoten des Baumes zurück, in dem sich node befindet.


# Beispiel
```julia
julia> nodes = union_find([(1, [1, 2, 3]), (4, [4, 5])]);
julia> find_set(nodes[5])
Node(4, nothing)
```
"""

function find_set(node::Node)::Node
    while node.parent !== nothing # klettert baum so lange hoch bis knoten ohne eltern gefunden wird
        node = node.parent
    end
    return node
    
end

"""
    find_set!(node::Node)::Node

Gibt den Wurzelknoten des Baumes zurück, in dem sich node befindet.
Wendet vollständige Pfadkompression 

Bei der vollst¨andigen Pfadkompression werden alle Knoten auf dem
Pfad von node zur Wurzel so umgeh¨angt, dass sie direkt auf die Wurzel zeigen.
Dadurch werden sp¨atere Anfragen deutlich schneller

# Beispiel
```julia
julia> root = Node(1, nothing); mid = Node(4, root); leaf = Node(5, mid);
julia> find_set!(leaf)
Node(1, nothing)
julia> leaf.parent === root
true
```
"""

function find_set!(node::Node)::Node
    root = find_set(node) # gibt wurzel zurück
    
    while node.parent !== nothing # geht pfad nochmal entlang und lässt jede besuchte node auf die wurzel zeigen
        next = node.parent # nächsten node merken
        node.parent = root # node auf root setzen
        node = next # gespeicherten nächsten knoten besuchen
    end
    return root
end

"""
    union!(node1::Node, node2::Node)::Nothing

Vereinigt die Bäume, in denen sich `node1` und `node2` befinden.

# Beispiel
```julia
julia> union!(nodes[1], nodes[4])
julia> nodes
Dict{Int64, Node} with 9 entries:
5 => Node(5, Node(4, Node(1, nothing)))
4 => Node(4, Node(1, nothing))
...
```
"""

function union!(node1::Node, node2::Node)::Nothing
    root_1 = find_set!(node1) # wurzel der beiden bäume bestimmen
    root_2 = find_set!(node2)

    if root_1 == root_2 # nichts tun wenn bereits im selben baum
        return nothing
    end

    root_2.parent = root_1 # wurzel von baum zwei als kind von baum 1 anhängen

    return nothing
end

"""
    add!(nodes::Dict{Int, Node}, value::Int)::Nothing

Fügt einen neuen Knoten mit dem Wert value zu den Bäumen hinzu

# Beispiel
```julia
julia> add!(nodes, 5)
ERROR: AssertionError: The element 5 is already in the partition
julia> add!(nodes, 11)
julia> nodes
Dict{Int64, Node} with 10 entries:
11 => Node(11, nothing)
...
```
"""

function add!(nodes::Dict{Int,Node}, value::Int)::Nothing
    if value in keys(nodes) # guckt ob wert schon im dict ist
        throw(AssertionError("The element $value is already in the partition"))
    end
    nodes[value] = Node(value,nothing) # fügt ihn ein
    return nothing
end