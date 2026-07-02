```
Strategie für Short Spiel
n Knotenanzahl, m Kantenanzahl
```
include("union_find.jl")

```
Findet Weg zwischen from und to mittels breitensuche. Ausgabe: Liste von besuchten Kanten
```
function find_path(g::GameGraph, from::Int, to::Int, allowed::Function)::Vector{Int} #(O(n^2 +m))
    adj = adjacency_list(g, allowed)            # adjacency list gibt adj_nodes = Dict{Int, Vector{Tuple{Int,Int}}}() zurück
    vorgaenger = Dict{Int,Tuple{Int,Int}}()     
    besucht    = Set{Int}([from])
    queue      = Int[from]
    # BFS
    while !isempty(queue) # beschränkt durch knotenanzahl
        u = popfirst!(queue)
        if u == to 
            break
        end     
        for (v, kante) in adj[u] # insgesamt beschränkt durch kantenanzahl
            if v ∉ besucht
                push!(besucht, v)
                vorgaenger[v] = (u, kante)
                push!(queue, v)
            end
        end
    end

    # wurde Ziel erreicht? 
    if from != to && !haskey(vorgaenger, to)
        return Int[]
    end
    # Weg zusammensetzen
    weg     = Int[]
    aktuell = to
    while aktuell != from
        vor, kante = vorgaenger[aktuell]
        push!(weg, kante)
        aktuell = vor
    end
    return weg
end

# Baut Spannbaum auf, Gibt Set von Kanten zurück oder nothing
function spanning_tree(n::Int, kantenliste::Vector{Tuple{Int,Int}} )::Union{Set{Int},Nothing} #O(m)
    nodes = union_find([(i,[i]) for i in 1:n]) # jeder knoten einzelner baum
    tree  = Set{Int}()
    for (i, (u, v)) in enumerate(kantenliste) # iteriert über kanten in reihenfolge, beschränkt durch kantenanzahl
        if find_set!(nodes[u]).value != find_set!(nodes[v]).value # checken ob kantenenden im gleichen baum sind und Pfadkompression
            union!(nodes[u], nodes[v]) 
            push!(tree, i)
        end
    end
    if length(tree) == n - 1 # checken ob alles richtig
        return tree 
    else 
        return nothing 
    end
end 

# Gibt Vector{Int}} zurück mit Kantenindizes aus tree
function fundamental_cycle(tree::Set{Int}, kantenliste::Vector{Tuple{Int,Int}}, n, chord::Int)::Vector{Int} #O(n^2)
    a, b = kantenliste[chord]  
    adj = [Tuple{Int,Int}[] for _ in 1:n] #Vector{Vector{Tuple{Int,Int}}}
    for i in tree # beschränkt durch kanten
        (u, v) = kantenliste[i]
        push!(adj[u], (v, i))
        push!(adj[v], (u, i))
    end

    # Breitensuche um Pfad von a nach b zu finden
    prev = Dict{Int,Tuple{Int,Int}}()
    seen = falses(n); seen[a] = true
    queue = [a]
    while !isempty(queue) # beschränkt durch knoten
        x = popfirst!(queue)
        if x == b 
            break
        end
        for (y, i) in adj[x] # beschränkt durch kantenanzahl
            if !seen[y]
                seen[y] = true
                prev[y] = (x, i)
                push!(queue, y)
            end
        end
    end
    if !haskey(prev, b) #wurde kreis gefunden
        return Int[]
    end

    path, cur = Int[], b# weg konstruieren mit Kantenindizes zu 
    while cur != a
        p, i = prev[cur]
        push!(path, i)
        cur = p
    end
    return path
end

#Augmentierung, e geimeinsame Sehne, Rückgabe Bool, verändert Spannbäume
function augment_along_common_chord!(T1::Set{Int}, T2::Set{Int}, kantenliste, n, e::Int) #O(n^3)
    par = Dict{Int,Int}()                 # Zu jeder Kante vorgänger, eindeutig wegen BFS
    entdeckt = Set{Int}()                 # besuchte Kanten
    schicht = Int[]                       # Schicht 1 erstellen 
    for f in fundamental_cycle(T1, kantenliste, n, e) # beschränkt durch knotenanzahl, n-1+1
        push!(schicht, f); push!(entdeckt, f)
    end
    
    k = 1 # counter für schicht
    while !isempty(schicht) # beschränkt durch n-1
        andererbaum = isodd(k) ? T2 : T1
        f = 0
        for c in schicht # beschränkt durch n-1
            if c in andererbaum
                f = c; break
            end
        end

        if f != 0  #Kette von f über die Vorgänger rekonstruieren
            chain = Int[f]
            x = f
            while haskey(par, x)  #beschränkt durch n-1
                x = par[x]; pushfirst!(chain, x)
            end
            push!(T1, e) # Tausch entlang der Kette wechseln die Kanten abwechselnd den Baum.
            for (i, c) in enumerate(chain) # 
                if isodd(i)
                    delete!(T1, c); push!(T2, c)
                else
                    delete!(T2, c); push!(T1, c)
                end
            end
            return true
        end

        # nächste Schicht aufbauen
        naechste = Int[]
        for g in schicht
            for neue_kante in fundamental_cycle(andererbaum, kantenliste, n, g)
                if neue_kante ∉ entdeckt
                    push!(entdeckt, neue_kante); par[neue_kante] = g; push!(naechste, neue_kante)
                end
            end
        end
        schicht = naechste
        k += 1
    end
    return false
end

#Maximal distante Spannbäume, 
function maximally_distant_trees!(T1::Set{Int}, T2::Set{Int}, edgelist, n) #O(mn^4)
    changed = true
    while changed == true # muss wiederholen weil bäume und Kreise sich ändern. maximal n-1 Iterationen
        changed = false #bricht ab wenn nix mehr ändert
        for e in 1:length(edgelist)
            if e ∉ T1 && e ∉ T2         #gemeinsame Sehne
                augment_along_common_chord!(T1, T2, edgelist, n, e) && (changed = true) # abbruch verhindern
            end
        end
    end
    return T1, T2
end

# prüft ob disjunkte spann bäume, gibt nur wahr oder falsch aber ändert und erstellt  Bäume
function _has_two_disjoint_spanning_trees(n, edgelist)::Bool  #O(mn^4)
    n <= 1 && return true
    T1 = spanning_tree(n, edgelist)
    T1 === nothing && return false #kann spannbaum erstellt werden?
    T2 = spanning_tree(n, edgelist)
    maximally_distant_trees!(T1, T2, edgelist, n)
    return isempty(intersect(T1, T2))
end

# Verschmilzt alle Short-Kanten Rückgabe: Anzahl zusammenhangselemente von short(Int), und repof funktion
function _contract_short(g::GameGraph) #O(m+n)
    n = maximum(v.id for v in g.vertices)
    nodes = union_find([(i, [i]) for i in 1:n]) # in zusammenhangselemente unterteilen, dictionary
    for e in g.edges
        e.state == :short && union!(nodes[e.u.id], nodes[e.v.id]) # zusammenhängende vereinen
    end
    reps  = unique(find_set!(nodes[v.id]).value for v in g.vertices) #unique wirft doppelte raus, find_set! pfadkompression, alle zusammenhangselemente aus dem baum
    idx = Dict{Int,Int}()
    for (i, r) in enumerate(reps)
        idx[r] = i
    end
    function repof(id)
        knoten = nodes[id]              # Union-Find-Knoten zu dieser id holen
        wurzel = find_set!(knoten)      # zur Wurzel klettern
        nummer = wurzel.value           # deren Repräsentanten-Nummer
        return idx[nummer]              # kompakte Zusammenhangsrepräsentant-Nummer nachschlagen
    end

    return length(reps), repof
end

# Rückgabe: (Anzahl Zusammenhangsknoten mit mehr als einem Knoten, Liste neutraler Kanten, s-Repräsentanten-Nummer, t-Repräsentanten-Nummer).
function _contracted_neutral(g::GameGraph) #O(m+n)
    N, repof = _contract_short(g)
    sN, tN   = repof(g.s.id), repof(g.t.id)
    kanten   = [(repof(e.u.id), repof(e.v.id)) for e in g.edges
                if e.state == :neutral && repof(e.u.id) != repof(e.v.id)]
    return N, kanten, sN, tN
end

# Grad, Anzahl freier Nachbarkanten zu lebenden Knoten, von Knoten v 
function _degree(edgelist, alive, v )# O(m)
    d = 0
    for (u, w) in edgelist
        d += (alive[u] && alive[w] && (u == v || w == v)) ? 1 : 0
    end
    return d
end

# Prüft ob lebende Knoten einen kompakten Teilgraphen mit zwei kantendisjunkte Spannbäume besitzt. Rückgabe Bool
function _alive_has_two_trees(N, edgelist, alive)
    neu = zeros(Int, N); k = 0
    for v in 1:N; alive[v] && (k += 1; neu[v] = k); end
    kanten = [(neu[u], neu[w]) for (u, w) in edgelist if alive[u] && alive[w] && u != w]
    return _has_two_disjoint_spanning_trees(k, kanten)
end

# Gibt es eine Knotenmenge mit zwei disjunkten Spannbäumen
function _two_tree_connected(N, edgelist, s, t) #O(mn^5)
    s == t && return true
    alive = trues(N)

    while true   # Alle Knoten mit Grad < 2 entfernen (außer s und t) 
        changed = true
        while changed
            changed = false
            for v in 1:N
                if alive[v] && v != s && v != t && _degree(edgelist, alive, v) < 2
                    alive[v] = false; changed = true
                end
            end
        end

        (alive[s] && alive[t]) || return false
        count(alive) <= 1      && return false

        _alive_has_two_trees(N, edgelist, alive) && return true   # Short hat Gewinnstrategie

        # Sonst knoten mit kleinstem grad entfernen und erneut versuchen.
        bester, min_grad = 0, typemax(Int)
        for v in 1:N
            if alive[v] && v != s && v != t
                d = _degree(edgelist, alive, v)
                d < min_grad && (min_grad = d; bester = v)
            end
        end
        bester == 0 && return false
        alive[bester] = false
    end
end

# Gewinnt Short wenn als nächstes cut zieht:: Bool
_short_wins_as_second(g) = _two_tree_connected(_contracted_neutral(g)...) #Funktionsdefinition... entpackt Tupel in einzelne ELemente, O(mn^5)

# gewinnt short mit e direkt? ::Bool
function _completes_short_path(g::GameGraph, e::Edge) #O(n^2 +m)
    e.state == :neutral || return false
    e.state = :short
    result  = path_exists(g, g.s.id, g.t.id, zustand -> zustand == :short) # allowed wenn zusatnd = short
    e.state = :neutral
    return result
end
# ZUsammenssetzung von allem 
function short_strategy(state::GameState)::Edge
    g, zuege = state.graph, valid_moves(state)
    isempty(zuege) && error("short_strategy: keine Züge möglich")
    # Sofortgewinn?
    for e in zuege  # O(m(n^2+m))
        _completes_short_path(g, e) && return e
    end

    # Zug suchen, der die Gewinnstellung erhält.
    for e in zuege #O(m^2n^5
        e.state = :short                 # Zug versuchsweise ausführen
        gut = _short_wins_as_second(g)
        e.state = :neutral               # 
        gut && return e
    end

    # neutrale Kante auf einem s-t-Weg, sonst irgendeine Kante
    for i in find_path(g, g.s.id, g.t.id, s -> s == :neutral || s == :short) #O(n^2 +m)
        g.edges[i].state == :neutral && return g.edges[i]
    end
    return first(zuege)
end
