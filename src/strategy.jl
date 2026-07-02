```
Strategie für Short Spiel
n Knotenanzahl, m Kantenanzahl
```
include("union_find.jl")


#Findet Weg zwischen from und to mittels breitensuche. Ausgabe: Liste von besuchten Kanten
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




# ═══════════════════════════════════════════════════════════════════════════
# Tests für die Short-Strategie (strategy.jl)
#
# Ausführen z. B. mit:  julia --project -e 'include("test/test_strategy.jl")'
# Die include-Pfade unten ggf. an eure Ordnerstruktur anpassen.
# ═══════════════════════════════════════════════════════════════════════════

using Test
using Random

include("../src/game.jl")       # Pfade anpassen falls nötig
include("../src/strategy.jl")   # inkludiert selbst union_find.jl

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

# ───────────────────────────────────────────────────────────────────────────
@testset "find_path" begin
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

println("Alle Strategie-Tests bestanden.")
