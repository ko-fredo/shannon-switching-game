# Optimale Strategien für beide Spieler.
#
# Short: Satz von Lehman, geprüft mit dem Kishi-Kajitani-Algorithmus.
# Cut:   Zugvorausschau über dieselbe Prüfung (siehe cut_strategy).
#
# Bezeichnungen in den Laufzeitkommentaren: n = Knotenanzahl, m = Kantenanzahl.

include("union_find.jl")


# ═══════════════════════════════════════════════════════════════════════════
# Wege
# ═══════════════════════════════════════════════════════════════════════════

"""
    find_path(g, from, to, allowed) -> Vector{Int}

Kürzester Weg von `from` nach `to` über Kanten, deren Zustand `allowed`
erfüllt, als Liste von Kantenindizes. Leer, wenn es keinen gibt oder
`from == to`.
"""
function find_path(g::GameGraph, from::Int, to::Int, allowed::Function)::Vector{Int} # O(n+m)
    adj = adjacency_list(g, allowed)
    n = length(adj)
    vor_knoten = zeros(Int, n)
    vor_kante  = zeros(Int, n)
    besucht    = falses(n)
    besucht[from] = true

    # Breitensuche mit Lesezeiger statt popfirst!, das wäre pro Zugriff O(n).
    queue = Vector{Int}(undef, n)
    queue[1] = from
    kopf, ende = 1, 1
    while kopf <= ende
        u = queue[kopf]; kopf += 1
        u == to && break
        for (v, kante) in adj[u]
            if !besucht[v]
                besucht[v]    = true
                vor_knoten[v] = u
                vor_kante[v]  = kante
                ende += 1; queue[ende] = v
            end
        end
    end

    (from == to || !besucht[to]) && return Int[]

    weg = Int[]
    aktuell = to
    while aktuell != from
        push!(weg, vor_kante[aktuell])
        aktuell = vor_knoten[aktuell]
    end
    return weg
end


# ═══════════════════════════════════════════════════════════════════════════
# Zwei kantendisjunkte Spannbäume (Kishi-Kajitani)
# ═══════════════════════════════════════════════════════════════════════════

# Baut einen Spannbaum auf. Rückgabe: Menge von Kantenindizes oder nothing.
function spanning_tree(n::Int, kantenliste::Vector{Tuple{Int,Int}})::Union{Set{Int},Nothing} # O(m)
    nodes = union_find([(i, [i]) for i in 1:n])   # jeder Knoten ein eigener Baum
    tree  = Set{Int}()
    for (i, (u, v)) in enumerate(kantenliste)
        if find_set!(nodes[u]).value != find_set!(nodes[v]).value   # Kreis vermeiden
            union!(nodes[u], nodes[v])
            push!(tree, i)
        end
    end
    return length(tree) == n - 1 ? tree : nothing
end

# Adjazenz eines Baumes als Vector: Knoten -> [(Nachbar, Kantenindex)].
function _baum_adjazenz(tree, kantenliste, n::Int)
    adj = [Tuple{Int,Int}[] for _ in 1:n]
    for i in tree
        (u, v) = kantenliste[i]
        push!(adj[u], (v, i)); push!(adj[v], (u, i))
    end
    return adj
end

# Fundamentalkreis der Sehne `chord` bezüglich eines Baumes, dessen Adjazenz
# schon gebaut ist. Rückgabe: Kantenindizes des Baumwegs (ohne die Sehne).
function _fundamental_cycle(adj, kantenliste, n::Int, chord::Int)::Vector{Int} # O(n)
    (a, b) = kantenliste[chord]
    a == b && return Int[]

    vor_knoten = zeros(Int, n)
    vor_kante  = zeros(Int, n)
    seen = falses(n); seen[a] = true
    queue = Vector{Int}(undef, n); queue[1] = a
    kopf, ende = 1, 1
    while kopf <= ende
        x = queue[kopf]; kopf += 1
        x == b && break
        for (y, i) in adj[x]
            if !seen[y]
                seen[y] = true
                vor_knoten[y] = x; vor_kante[y] = i
                ende += 1; queue[ende] = y
            end
        end
    end
    seen[b] || return Int[]

    path = Int[]
    cur = b
    while cur != a
        push!(path, vor_kante[cur])
        cur = vor_knoten[cur]
    end
    return path
end

"""
    fundamental_cycle(tree, kantenliste, n, chord) -> Vector{Int}

Kantenindizes des eindeutigen Weges in `tree` zwischen den Endknoten der
Sehne `chord`. Die Sehne selbst ist nie enthalten.
"""
fundamental_cycle(tree::Set{Int}, kantenliste::Vector{Tuple{Int,Int}}, n, chord::Int) =
    _fundamental_cycle(_baum_adjazenz(tree, kantenliste, n), kantenliste, n, chord)

# Augmentierung entlang einer gemeinsamen Sehne e. Verändert T1 und T2 und
# gibt zurück, ob der Tausch geklappt hat.
#
# Die Suche nach der Tauschkette muss schichtweise (BFS) laufen: Eine naive
# rekursive Tiefensuche liefert keine kürzesten alternierenden Ketten und
# damit in einem erheblichen Teil der Fälle ein falsches Ergebnis.
function augment_along_common_chord!(T1::Set{Int}, T2::Set{Int}, kantenliste, n, e::Int) # O(n²)
    par      = Dict{Int,Int}()   # Vorgängerkante in der Kette, eindeutig wegen BFS
    entdeckt = Set{Int}()
    schicht  = Int[]

    for f in _fundamental_cycle(_baum_adjazenz(T1, kantenliste, n), kantenliste, n, e)
        push!(schicht, f); push!(entdeckt, f)
    end

    k = 1
    while !isempty(schicht)
        andererbaum = isodd(k) ? T2 : T1
        f = 0
        for c in schicht
            if c in andererbaum
                f = c; break
            end
        end

        if f != 0                      # Kette über die Vorgänger rekonstruieren
            chain = Int[f]
            x = f
            while haskey(par, x)
                x = par[x]; pushfirst!(chain, x)
            end
            push!(T1, e)               # entlang der Kette wechseln die Kanten den Baum
            for (i, c) in enumerate(chain)
                if isodd(i)
                    delete!(T1, c); push!(T2, c)
                else
                    delete!(T2, c); push!(T1, c)
                end
            end
            return true
        end

        # Nächste Schicht. Die Adjazenz des Baumes wird einmal gebaut und für
        # alle Kanten der Schicht wiederverwendet.
        adj = _baum_adjazenz(andererbaum, kantenliste, n)
        naechste = Int[]
        for g in schicht
            for neue_kante in _fundamental_cycle(adj, kantenliste, n, g)
                if neue_kante ∉ entdeckt
                    push!(entdeckt, neue_kante); par[neue_kante] = g
                    push!(naechste, neue_kante)
                end
            end
        end
        schicht = naechste
        k += 1
    end
    return false
end

# Treibt T1 und T2 so weit auseinander, wie es geht.
function maximally_distant_trees!(T1::Set{Int}, T2::Set{Int}, edgelist, n) # O(mn³)
    changed = true
    while changed
        changed = false
        isempty(intersect(T1, T2)) && break      # disjunkt, mehr brauchen wir nicht
        for e in 1:length(edgelist)
            if e ∉ T1 && e ∉ T2                  # gemeinsame Sehne
                augment_along_common_chord!(T1, T2, edgelist, n, e) && (changed = true)
            end
        end
    end
    return T1, T2
end

# Besitzt der Graph zwei kantendisjunkte Spannbäume?
function _has_two_disjoint_spanning_trees(n, edgelist)::Bool # O(mn³)
    n <= 1 && return true
    length(edgelist) < 2 * (n - 1) && return false    # Abkürzung über die Kantenzahl
    T1 = spanning_tree(n, edgelist)
    T1 === nothing && return false
    T2 = spanning_tree(n, edgelist)
    maximally_distant_trees!(T1, T2, edgelist, n)
    return isempty(intersect(T1, T2))
end


# ═══════════════════════════════════════════════════════════════════════════
# Kontraktion der Short-Kanten
# ═══════════════════════════════════════════════════════════════════════════

# Verschmilzt alle Short-Kanten. Rückgabe: Anzahl Zusammenhangskomponenten
# und eine Funktion, die eine Knoten-id auf ihre Komponentennummer abbildet.
function _contract_short(g::GameGraph) # O(m+n)
    n = maximum(v.id for v in g.vertices)
    nodes = union_find([(i, [i]) for i in 1:n])
    for e in g.edges
        e.state == :short && union!(nodes[e.u.id], nodes[e.v.id])
    end
    reps = unique(find_set!(nodes[v.id]).value for v in g.vertices)
    idx = Dict{Int,Int}()
    for (i, r) in enumerate(reps)
        idx[r] = i
    end
    repof(id) = idx[find_set!(nodes[id]).value]
    return length(reps), repof
end

# Der kontrahierte Graph aus Shorts Sicht: Komponentenzahl, neutrale Kanten
# zwischen verschiedenen Komponenten, Nummer von s und von t.
function _contracted_neutral(g::GameGraph) # O(m+n)
    N, repof = _contract_short(g)
    sN, tN   = repof(g.s.id), repof(g.t.id)
    kanten   = Tuple{Int,Int}[(repof(e.u.id), repof(e.v.id)) for e in g.edges
                              if e.state == :neutral && repof(e.u.id) != repof(e.v.id)]
    return N, kanten, sN, tN
end


# ═══════════════════════════════════════════════════════════════════════════
# Lehman-Bedingung
# ═══════════════════════════════════════════════════════════════════════════

"""
    _degree(edgelist, alive, v) -> Int

Anzahl Kanten an `v`, deren beide Endknoten noch leben.
"""
function _degree(edgelist, alive, v) # O(m)
    d = 0
    for (u, w) in edgelist
        d += (alive[u] && alive[w] && (u == v || w == v)) ? 1 : 0
    end
    return d
end

# Alle Grade in einem Durchlauf statt m-mal einzeln.
function _grade(N::Int, kanten, alive, aktiv::Vector{Int})::Vector{Int} # O(m)
    grad = zeros(Int, N)
    for j in aktiv
        (u, v) = kanten[j]
        if alive[u] && alive[v]
            grad[u] += 1; grad[v] += 1
        end
    end
    return grad
end

# Zusammenhangskomponente von `start` über die aktiven Kanten.
function _komponente(N::Int, kanten, alive, aktiv::Vector{Int}, start::Int) # O(n+m)
    adj = [Int[] for _ in 1:N]
    for j in aktiv
        (u, v) = kanten[j]
        if alive[u] && alive[v]
            push!(adj[u], v); push!(adj[v], u)
        end
    end
    drin = falses(N); drin[start] = true
    stapel = Int[start]
    while !isempty(stapel)
        x = pop!(stapel)
        for y in adj[x]
            if !drin[y]
                drin[y] = true; push!(stapel, y)
            end
        end
    end
    return drin
end

# Brücken über Tiefensuche mit Lowlink. Parallelkanten werden korrekt
# behandelt, weil über den Kantenindex zurückgesperrt wird, nicht über den
# Vorgängerknoten.
function _bruecken(N::Int, kanten, alive, aktiv::Vector{Int})::Vector{Int} # O(n+m)
    adj = [Tuple{Int,Int}[] for _ in 1:N]
    for j in aktiv
        (u, v) = kanten[j]
        if alive[u] && alive[v] && u != v
            push!(adj[u], (v, j)); push!(adj[v], (u, j))
        end
    end

    disc = zeros(Int, N); low = zeros(Int, N)
    zeit = Ref(0); brueck = Int[]

    function dfs(u::Int, eingang::Int)
        zeit[] += 1
        disc[u] = zeit[]; low[u] = zeit[]
        for (v, j) in adj[u]
            j == eingang && continue
            if disc[v] == 0
                dfs(v, j)
                low[u] = min(low[u], low[v])
                low[v] > disc[u] && push!(brueck, j)
            else
                low[u] = min(low[u], disc[v])
            end
        end
        return nothing
    end

    for u in 1:N
        (alive[u] && disc[u] == 0) && dfs(u, 0)
    end
    return brueck
end

# Hat der von `drin` induzierte Teilgraph zwei kantendisjunkte Spannbäume?
function _teilgraph_hat_zwei_baeume(N::Int, kanten, aktiv::Vector{Int}, drin)::Bool
    neu = zeros(Int, N); k = 0
    for v in 1:N
        if drin[v]
            k += 1; neu[v] = k
        end
    end
    sub = Tuple{Int,Int}[]
    for j in aktiv
        (u, v) = kanten[j]
        if drin[u] && drin[v] && u != v
            push!(sub, (neu[u], neu[v]))
        end
    end
    return _has_two_disjoint_spanning_trees(k, sub)
end

"""
    _alive_has_two_trees(N, edgelist, alive) -> Bool

Besitzt der von den lebenden Knoten induzierte Teilgraph zwei
kantendisjunkte Spannbäume?
"""
function _alive_has_two_trees(N, edgelist, alive)
    return _teilgraph_hat_zwei_baeume(N, edgelist, collect(1:length(edgelist)), alive)
end

# Ab wie vielen Restknoten die erschöpfende Suche abgebrochen wird. Nach der
# Reduktion bleiben in der Praxis unter zehn übrig, der Wert ist nur eine
# Sicherung gegen Entartung.
const _MAX_AUFZAEHLUNG = 14

"""
    _two_tree_connected(N, edgelist, s, t) -> Bool

Gibt es eine Knotenmenge mit `s` und `t`, deren induzierter Teilgraph zwei
kantendisjunkte Spannbäume besitzt? Das ist nach dem Satz von Lehman genau
die Gewinnbedingung für Short als Nachziehenden.

Zuerst wird entfernt, was in keinem solchen Teilgraphen liegen kann. Jede
der drei Regeln ist einzeln begründbar:

1. Knoten mit Grad < 2 — in einem Graphen mit zwei kantendisjunkten
   Spannbäumen braucht jeder Knoten mindestens eine Kante in jedem Baum.
2. Alles außerhalb der Komponente von `s` — ein solcher Teilgraph ist
   zusammenhängend und enthält beide Endknoten.
3. Brücken — eine Brücke liegt in jedem Spannbaum des Teilgraphen, der sie
   enthält, kann also nie in zweien liegen, die disjunkt sind.

Hält die Restmenge dem Test nicht stand, werden ihre Teilmengen durchsucht.
Nach der Reduktion sind das sehr wenige.

Frühere Fassungen haben an dieser Stelle stattdessen den Knoten mit dem
kleinsten Grad entfernt und es erneut versucht. Das ist eine Vermutung und
kein Argument: Zerfällt der Graph in mehrere dichte Blöcke, entfernt die
Regel Knoten aus dem gesuchten Teilgraphen und meldet falsch `false`.
"""
function _two_tree_connected(N::Int, edgelist, s::Int, t::Int)::Bool
    s == t && return true
    N < 1 && return false

    alive = trues(N)
    aktiv = Int[j for j in 1:length(edgelist) if edgelist[j][1] != edgelist[j][2]]

    while true
        geaendert = false

        # 1. Knoten mit Grad < 2
        while true
            grad = _grade(N, edgelist, alive, aktiv)
            tot = false
            for v in 1:N
                if alive[v] && v != s && v != t && grad[v] < 2
                    alive[v] = false; tot = true; geaendert = true
                end
            end
            tot || break
        end
        (alive[s] && alive[t]) || return false

        # 2. Komponente von s
        drin = _komponente(N, edgelist, alive, aktiv, s)
        drin[t] || return false
        for v in 1:N
            if alive[v] && !drin[v]
                alive[v] = false; geaendert = true
            end
        end
        aktiv = Int[j for j in aktiv if alive[edgelist[j][1]] && alive[edgelist[j][2]]]

        # 3. Brücken
        br = _bruecken(N, edgelist, alive, aktiv)
        if !isempty(br)
            weg = Set(br)
            aktiv = Int[j for j in aktiv if j ∉ weg]
            geaendert = true
        end

        geaendert || break
    end

    count(alive) <= 1 && return false
    _teilgraph_hat_zwei_baeume(N, edgelist, aktiv, alive) && return true

    # Erschöpfende Suche auf der reduzierten Menge, größte Teilmengen zuerst.
    rest = Int[v for v in 1:N if alive[v] && v != s && v != t]
    r = length(rest)
    r > _MAX_AUFZAEHLUNG && return false
    for groesse in (r - 1):-1:0
        for maske in 0:((1 << r) - 1)
            count_ones(maske) == groesse || continue
            teil = falses(N)
            teil[s] = true; teil[t] = true
            for i in 1:r
                ((maske >> (i - 1)) & 1) == 1 && (teil[rest[i]] = true)
            end
            _teilgraph_hat_zwei_baeume(N, edgelist, aktiv, teil) && return true
        end
    end
    return false
end

# Gewinnt Short, wenn als nächstes Cut zieht?
_short_wins_as_second(g) = _two_tree_connected(_contracted_neutral(g)...)

# Stellt e sofort einen s-t-Weg aus Short-Kanten her?
function _completes_short_path(g::GameGraph, e::Edge) # O(n+m)
    e.state == :neutral || return false
    e.state = :short
    result  = path_exists(g, g.s.id, g.t.id, zustand -> zustand == :short)
    e.state = :neutral
    return result
end

# Gewinnt Short, wenn Short als nächstes zieht?
function _short_am_zug_gewinnt(g::GameGraph)::Bool
    for e in g.edges
        e.state == :neutral || continue
        e.state = :short
        gewinnt = path_exists(g, g.s.id, g.t.id, zustand -> zustand == :short) ||
                  _short_wins_as_second(g)
        e.state = :neutral
        gewinnt && return true
    end
    return false
end


# ═══════════════════════════════════════════════════════════════════════════
# Strategien
# ═══════════════════════════════════════════════════════════════════════════

# Kanten auf einem kürzesten s-t-Weg nach vorn. Ändert das Ergebnis nicht,
# aber der teure Test trifft meist schon nach wenigen Kandidaten.
function _wegkanten_zuerst(g::GameGraph, zuege::Vector{Edge})::Vector{Edge}
    weg = find_path(g, g.s.id, g.t.id, zustand -> zustand == :neutral || zustand == :short)
    isempty(weg) && return zuege
    aufweg = Set{Edge}(g.edges[i] for i in weg)
    vorne, hinten = Edge[], Edge[]
    for e in zuege
        (e in aufweg) ? push!(vorne, e) : push!(hinten, e)
    end
    return vcat(vorne, hinten)
end

"""
    short_strategy(state::GameState) -> Edge

Optimaler Zug für den Short-Spieler. Solange eine Gewinnstellung im Sinne
des Satzes von Lehman existiert, erhält der zurückgegebene Zug sie.
"""
function short_strategy(state::GameState)::Edge
    g, zuege = state.graph, valid_moves(state)
    isempty(zuege) && error("short_strategy: keine Züge möglich")

    for e in zuege                       # Sofortgewinn?
        _completes_short_path(g, e) && return e
    end

    for e in _wegkanten_zuerst(g, zuege) # Gewinnstellung erhalten
        e.state = :short
        gut = _short_wins_as_second(g)
        e.state = :neutral
        gut && return e
    end

    # Verloren: neutrale Kante auf einem s-t-Weg, sonst irgendeine.
    for i in find_path(g, g.s.id, g.t.id, zustand -> zustand == :neutral || zustand == :short)
        g.edges[i].state == :neutral && return g.edges[i]
    end
    return first(zuege)
end

# Zug, der den kürzesten verbliebenen s-t-Weg trifft.
function _cut_heuristik(g::GameGraph, zuege::Vector{Edge})::Edge
    for i in find_path(g, g.s.id, g.t.id, zustand -> zustand == :neutral || zustand == :short)
        g.edges[i].state == :neutral && return g.edges[i]
    end
    return first(zuege)
end

"""
    cut_strategy(state::GameState) -> Edge

Optimaler Zug für den Cut-Spieler.

Cut hat kein eigenes Gegenstück zum Satz von Lehman — das wäre die duale
Bedingung über zwei kantendisjunkte s-t-Schnitte und bräuchte Matroid-Union
auf dem kographischen Matroid. Stattdessen wird hier eine Stufe
vorausgeschaut: Da die Lehman-Bedingung exakt entscheidet, ob Short gewinnt,
wenn Cut am Zug ist, lässt sich daraus auch entscheiden, ob Short gewinnt,
wenn Short am Zug ist. Cut wählt also einen Zug, nach dem Short am Zug
verliert — existiert ein solcher, ist er optimal.

Kostet gegenüber `short_strategy` etwa den Faktor m. Zwei Abkürzungen halten
das klein: Gewinnt Short ohnehin schon als Nachziehender, ist Cut verloren
und es wird gar nicht erst gesucht; und die Prüfung bricht ab, sobald ein
Gewinnzug für Short gefunden ist.
"""
function cut_strategy(state::GameState)::Edge
    g, zuege = state.graph, valid_moves(state)
    isempty(zuege) && error("cut_strategy: keine Züge möglich")

    for e in zuege                       # Sofortgewinn: trennt e s von t?
        e.state = :cut
        getrennt = !path_exists(g, g.s.id, g.t.id,
                                zustand -> zustand == :neutral || zustand == :short)
        e.state = :neutral
        getrennt && return e
    end

    # Gewinnt Short schon als Nachziehender, hilft kein Zug mehr.
    _short_wins_as_second(g) && return _cut_heuristik(g, zuege)

    for e in _wegkanten_zuerst(g, zuege) # Zug, nach dem Short am Zug verliert
        e.state = :cut
        gut = !_short_am_zug_gewinnt(g)
        e.state = :neutral
        gut && return e
    end

    return _cut_heuristik(g, zuege)
end
