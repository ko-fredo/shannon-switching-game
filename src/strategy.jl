```
Strategien

```

const TEAM_NAME = "WT19"

include("union_find.jl")

```
find_path
Sucht einen Weg von Knoten from nach to, der nur über erlaubte Kanten läuft.
allowed bekommt den Zustand einer Kante neutral,short,cut und gibt 
true/false zurück. Die Funktion gibt Liste der benutzten Kanten für 
den weg zurück, oder leere Liste
```

function find_path(g::GameGraph, from::Int, to::Int, allowed::Function)::Vector{Int}
    adj = adjacency_list(g, allowed)            # Nachbarn je Knoten

    vorgaenger = Dict{Int,Tuple{Int,Int}}()     # Knoten -> (woher, über welche Kante)
    besucht    = Set{Int}([from])
    queue      = Int[from]

    # Standard-BFS: Knoten Schicht für Schicht abarbeiten.
    while !isempty(queue)
        u = popfirst!(queue)
        u == to && break
        for (v, kante) in adj[u]
            if v ∉ besucht
                push!(besucht, v)
                vorgaenger[v] = (u, kante)
                push!(queue, v)
            end
        end
    end

    # Ziel nicht erreichbar?
    (from == to || haskey(vorgaenger, to)) || return Int[]

    # Weg von `to` rückwärts bis `from` zusammensetzen.
    weg     = Int[]
    aktuell = to
    while aktuell != from
        vor, kante = vorgaenger[aktuell]
        push!(weg, kante)
        aktuell = vor
    end
    return weg
end


# ═══════════════════════════════════════════════════════════════════════════════
# TEIL 1 der Short-Strategie: "Habe ich noch eine Gewinnstellung?"
#
# Grundidee (Satz von Lehman): Short kann das Spiel sicher gewinnen, wenn der
# Graph (genauer: ein Teil davon, der s und t enthält) ZWEI Spannbäume besitzt,
# die sich keine neutrale Kante teilen. Anschaulich: Short hat dann zwei
# voneinander unabhängige "Reserve-Verbindungen". Egal welche Kante Cut entfernt,
# Short kann mit der jeweils anderen reparieren.
#
# Um das zu prüfen, müssen wir zwei kantendisjunkte Bäume finden ("packen").
# Das erledigen die folgenden Hilfsfunktionen.
# ═══════════════════════════════════════════════════════════════════════════════

# Liegen die Knoten a und b im selben Teilbaum von Wald `wald_nr`?  (via Union-Find)
function _same_component(assign, edgelist, wald_nr, n, a, b)
    a == b && return true
    nodes = union_find([(i, [i]) for i in 1:n])
    for (i, (u, v)) in enumerate(edgelist)
        assign[i] == wald_nr && union!(nodes[u], nodes[v])
    end
    return find_set!(nodes[a]).value == find_set!(nodes[b]).value
end

# Kanten-Indizes auf dem eindeutigen Weg von a nach b innerhalb von Wald `wald_nr`.
# (Ein Baum/Wald hat zwischen zwei verbundenen Knoten genau einen Weg.)
# Rückgabe: leere Liste, falls a und b im Wald nicht verbunden sind.
function _path_in_forest(assign, edgelist, wald_nr, n, a, b)
    # Adjazenzliste nur aus den Kanten dieses Waldes aufbauen.
    adj = [Tuple{Int,Int}[] for _ in 1:n]
    for (i, (u, v)) in enumerate(edgelist)
        if assign[i] == wald_nr
            push!(adj[u], (v, i)); push!(adj[v], (u, i))
        end
    end

    # BFS von a nach b, Vorgänger merken.
    prev = Dict{Int,Tuple{Int,Int}}()
    seen = falses(n); seen[a] = true
    queue = [a]
    while !isempty(queue)
        x = popfirst!(queue)
        x == b && break
        for (y, i) in adj[x]
            seen[y] || (seen[y] = true; prev[y] = (x, i); push!(queue, y))
        end
    end

    haskey(prev, b) || return Int[]

    # Weg von b nach a rückwärts rekonstruieren.
    path, cur = Int[], b
    while cur != a
        p, i = prev[cur]; push!(path, i); cur = p
    end
    return path
end

# Versucht, Kante e0 in einen der beiden Wälder einzufügen – notfalls per Kette
# von Tausch-Operationen (das ist der Kern des "Matroid-Union"-Algorithmus).
# Idee: Eine BFS, deren "Knoten" Paare (Kante, Wald) sind. Gibt true zurück,
# falls die Einfügung gelungen ist.
function _place!(assign, fixed, edgelist, n, e0)
    from  = Dict{Tuple{Int,Int}, Union{Nothing,Tuple{Int,Int}}}()
    queue = Tuple{Int,Int}[]
    for wald in (1, 2)
        from[(e0, wald)] = nothing
        push!(queue, (e0, wald))
    end

    ziel = nothing
    while !isempty(queue)
        (kante, wald) = popfirst!(queue)
        (u, v)        = edgelist[kante]

        if !_same_component(assign, edgelist, wald, n, u, v)
            ziel = (kante, wald); break        # kein Kreis → Kante passt direkt rein
        end

        # Kante würde einen Kreis bilden → Kanten auf dem Kreis als Tausch-Kandidaten.
        anderer = wald == 1 ? 2 : 1
        for g in _path_in_forest(assign, edgelist, wald, n, u, v)
            fixed[g] && continue
            if !haskey(from, (g, anderer))
                from[(g, anderer)] = (kante, wald)
                push!(queue, (g, anderer))
            end
        end
    end

    ziel === nothing && return false

    # Gefundene Tausch-Kette rückwärts abgehen und Zuweisungen aktualisieren.
    node = ziel
    while node !== nothing
        (kante, wald) = node
        assign[kante] = wald
        node = from[(kante, wald)]
    end
    return true
end

# Verteilt die Kanten auf zwei möglichst große, kantendisjunkte Wälder.
# Rückgabe: Vektor `assign` mit assign[i] ∈ {0,1,2}
#   0 = Kante in keinem Wald, 1 oder 2 = Nummer des Waldes.
function _two_disjoint_forests(n, edgelist)
    m      = length(edgelist)
    assign = zeros(Int, m)
    fixed  = falses(m)
    for e0 in 1:m
        _place!(assign, fixed, edgelist, n, e0)
    end
    return assign
end


# ───────────────────────────────────────────────────────────────────────────────
# Short-Kanten verschmelzen + neutralen Graphen aufbereiten
# ───────────────────────────────────────────────────────────────────────────────
# Bereits von Short gesicherte Kanten sind "fertig" – ihre beiden Endknoten sind
# für Short praktisch ein einziger Knoten. Wir verschmelzen sie daher zu
# "Superknoten" und betrachten danach nur noch die neutralen Kanten.

# Verschmilzt alle Short-Kanten zu Superknoten.
# Rückgabe: (Anzahl Superknoten, Funktion id -> Superknoten-Nummer).
function _contract_short(g::GameGraph)
    n = maximum(v.id for v in g.vertices)
    nodes = union_find([(i, [i]) for i in 1:n])
    for e in g.edges
        e.state == :short && union!(nodes[e.u.id], nodes[e.v.id])
    end
    reps  = unique(find_set!(nodes[v.id]).value for v in g.vertices)
    idx   = Dict(r => i for (i, r) in enumerate(reps))
    repof = id -> idx[find_set!(nodes[id]).value]
    return length(reps), repof
end

# Liefert den verschmolzenen Graphen aus den neutralen Kanten.
# Rückgabe: (Anzahl Superknoten, Liste neutraler Kanten, s-Nummer, t-Nummer).
function _contracted_neutral(g::GameGraph)
    N, repof = _contract_short(g)
    sN, tN   = repof(g.s.id), repof(g.t.id)
    kanten   = [(repof(e.u.id), repof(e.v.id)) for e in g.edges
                if e.state == :neutral && repof(e.u.id) != repof(e.v.id)]
    return N, kanten, sN, tN
end

# Grad (= Anzahl Nachbarkanten) von Knoten v unter den noch "lebenden" Knoten.
function _degree(edgelist, alive, v)
    d = 0
    for (u, w) in edgelist
        d += (alive[u] && alive[w] && (u == v || w == v)) ? 1 : 0
    end
    return d
end

# Wie viele Kanten lassen sich auf den lebenden Knoten in zwei disjunkte Wälder
# packen? Zwei kantendisjunkte Spannbäume auf k Knoten haben genau 2*(k-1) Kanten.
function _pack_size(N, edgelist, alive)
    neu = zeros(Int, N); k = 0
    for v in 1:N; alive[v] && (k += 1; neu[v] = k); end
    kanten = [(neu[u], neu[w]) for (u, w) in edgelist if alive[u] && alive[w] && u != w]
    return count(>(0), _two_disjoint_forests(k, kanten)), k
end

# Lehman-Test: Gibt es eine Knotenmenge mit s und t, auf der zwei kantendisjunkte
# Spannbäume existieren? Vorgehen: Knoten, die offensichtlich nicht helfen können
# (Grad < 2), nach und nach entfernen und dann das Packing prüfen.
function _two_tree_connected(N, edgelist, s, t)
    s == t && return true
    alive = trues(N)

    while true
        # Alle Knoten mit Grad < 2 entfernen (außer s und t) – sie können in
        # keinem Kreis liegen und damit zu keinem zweiten Baum beitragen.
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

        pack, k = _pack_size(N, edgelist, alive)
        pack == 2(k - 1)       && return true     # zwei volle Spannbäume → Short gewinnt!

        # Sonst: Knoten mit kleinstem Grad entfernen und erneut versuchen.
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

# Gewinnt Short, wenn als Nächstes Cut zieht (Short also "antwortet")?
_short_wins_as_second(g) = _two_tree_connected(_contracted_neutral(g)...)

# Würde das Sichern von Kante e SOFORT einen s-t-Weg aus lauter Short-Kanten
# vervollständigen (also direkt gewinnen)?
function _completes_short_path(g::GameGraph, e::Edge)
    e.state == :neutral || return false
    e.state = :short
    result  = path_exists(g, g.s.id, g.t.id, s -> s == :short)
    e.state = :neutral
    return result
end


# ───────────────────────────────────────────────────────────────────────────────
# Optimale Strategie für Short (klassisches, ungewichtetes Spiel)
# ───────────────────────────────────────────────────────────────────────────────

"""
    short_strategy(state::GameState) -> Edge

Optimale Strategie für Short im klassischen Spiel.

Die Strategie wählt einen Zug in dieser Reihenfolge:
1. **Sofortgewinn** – gibt es eine Kante, die direkt einen s-t-Weg aus
   Short-Kanten vollendet, wird sie genommen.
2. **Gewinnstellung halten** – sonst wird eine Kante gesucht, nach deren Sicherung
   Short immer noch gewinnt (geprüft mit dem Satz von Lehman: es existieren zwei
   Spannbäume mit disjunkten neutralen Kanten). Solange Short das schafft, kann
   Cut nie alle Verbindungen zerstören.
3. **Notnagel** – ist keine Gewinnstellung mehr erreichbar (Short steht schon
   verloren), wird einfach eine neutrale Kante auf einem s-t-Weg gewählt.
"""
function short_strategy(state::GameState)::Edge
    g, zuege = state.graph, valid_moves(state)
    isempty(zuege) && error("short_strategy: keine Züge möglich")

    # 1) Sofortgewinn?
    for e in zuege
        _completes_short_path(g, e) && return e
    end

    # 2) Zug suchen, der die Gewinnstellung erhält.
    for e in zuege
        e.state = :short                 # Zug versuchsweise ausführen ...
        gut     = _short_wins_as_second(g)
        e.state = :neutral               # ... und wieder zurücknehmen.
        gut && return e
    end

    # 3) Notnagel: neutrale Kante auf einem s-t-Weg, sonst irgendeine Kante.
    for i in find_path(g, g.s.id, g.t.id, s -> s == :neutral || s == :short)
        g.edges[i].state == :neutral && return g.edges[i]
    end
    return first(zuege)
end


# ═══════════════════════════════════════════════════════════════════════════════
# TEIL 5: Heuristiken für das GEWICHTETE Spiel (Strategiewettbewerb)
#
# Im gewichteten Spiel zählt das Gewicht von Shorts s-t-Weg: Short will es klein
# halten, Cut will es groß machen. Unsere Heuristik ist bewusst einfach und für
# beide Spieler symmetrisch:
#
#   Beide schauen auf DIESELBE Zahl – die Kosten des aktuell günstigsten s-t-Wegs
#   (schon gesicherte Short-Kanten kosten 0, entfernte Kanten sind unbenutzbar).
#
#   * Short sichert auf diesem günstigsten Weg die "Engpass-Kante": die Kante,
#     deren Verlust den Weg am stärksten verteuern würde. So friert Short den
#     billigen Weg ein, bevor Cut ihn kaputtmachen kann.
#   * Cut entfernt genau diese Engpass-Kante – die, die den günstigsten Weg am
#     stärksten verteuert. So zwingt Cut Short auf einen teureren Umweg.
# ═══════════════════════════════════════════════════════════════════════════════

# Günstigster s-t-Weg (Dijkstra). Schon gesicherte Short-Kanten kosten 0.
# Rückgabe: Kanten-Indizes des Weges (oder [], falls es keinen Weg gibt).
function _cheapest_path(g::GameGraph)
    INF  = Inf
    dist = Dict(v.id => INF for v in g.vertices)
    dist[g.s.id] = 0.0
    prev = Dict{Int,Tuple{Int,Int}}()
    done = Set{Int}()
    adj  = adjacency_list(g, s -> s == :neutral || s == :short)

    while true
        # Nächsten noch unbesuchten Knoten mit kleinster Distanz wählen.
        u, d_u = -1, INF
        for (v, d) in dist
            v ∉ done && d < d_u && (u = v; d_u = d)
        end
        (u == -1 || u == g.t.id) && break
        push!(done, u)

        for (v, idx) in adj[u]
            v in done && continue
            e = g.edges[idx]
            w = e.state == :short ? 0.0 : e.weight     # gesicherte Kanten sind gratis
            if dist[u] + w < get(dist, v, INF)
                dist[v] = dist[u] + w
                prev[v] = (u, idx)
            end
        end
    end

    haskey(prev, g.t.id) || return Int[]

    path, cur = Int[], g.t.id
    while cur != g.s.id
        haskey(prev, cur) || return Int[]
        p, i = prev[cur]; push!(path, i); cur = p
    end
    return path
end

# Gesamtkosten des günstigsten s-t-Wegs (Short-Kanten zählen 0).
# Gibt Inf zurück, wenn s und t nicht mehr verbunden werden können.
function _cheapest_path_weight(g::GameGraph)
    path = _cheapest_path(g)
    isempty(path) && return (g.s.id == g.t.id ? 0.0 : Inf)
    return sum(g.edges[i].state == :short ? 0.0 : g.edges[i].weight for i in path; init = 0.0)
end

"""
    weighted_short(state::GameState) -> Edge

Heuristik für Short im gewichteten Spiel: sichert auf dem günstigsten s-t-Weg
die Engpass-Kante – die Kante, deren Entfernung den Weg am stärksten verteuern
würde.
"""
function weighted_short(state::GameState)::Edge
    g, zuege = state.graph, valid_moves(state)
    isempty(zuege) && error("weighted_short: keine Züge möglich")

    # Wenn ein Zug direkt eine Verbindung fertigstellt: machen (sichert Punkte).
    for e in zuege
        _completes_short_path(g, e) && return e
    end

    # Neutrale Kanten auf dem aktuell günstigsten Weg.
    weg        = _cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && return first(zuege)     # kein günstiger Weg → Notnagel

    # Engpass-Kante bestimmen: simulieren, Cut würde sie entfernen, und schauen,
    # um wie viel die Wegkosten dann steigen. Die Kante mit dem größten Anstieg
    # ist am wertvollsten und wird gesichert.
    basiskosten = _cheapest_path_weight(g)
    beste, max_schaden = kandidaten[1], -Inf
    for e in kandidaten
        e.state = :cut
        schaden = _cheapest_path_weight(g) - basiskosten
        e.state = :neutral
        schaden > max_schaden && (max_schaden = schaden; beste = e)
    end
    return beste
end

"""
    weighted_cut(state::GameState) -> Edge

Heuristik für Cut im gewichteten Spiel: entfernt die Kante, die den günstigsten
s-t-Weg am stärksten verteuert (und damit Short den teuersten Umweg aufzwingt).
"""
function weighted_cut(state::GameState)::Edge
    g, zuege = state.graph, valid_moves(state)
    isempty(zuege) && error("weighted_cut: keine Züge möglich")

    # Sofortgewinn: trennt ein Zug s und t vollständig?
    for e in zuege
        e.state  = :cut
        getrennt = isempty(find_path(g, g.s.id, g.t.id, s -> s == :neutral || s == :short))
        e.state  = :neutral
        getrennt && return e
    end

    # Kandidaten: bevorzugt Kanten auf dem günstigsten Weg, sonst alle Züge.
    weg        = _cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && (kandidaten = zuege)

    # Kante wählen, deren Entfernung die Wegkosten am stärksten erhöht.
    # (Wird der Weg ganz unmöglich = Inf, ist das für Cut natürlich am besten.)
    basis = _cheapest_path_weight(g)
    grosse_zahl(x) = isinf(x) ? 1e9 : x            # Inf für den Vergleich ersetzen
    beste, max_schaden = kandidaten[1], -Inf
    for e in kandidaten
        e.state = :cut
        neu     = _cheapest_path_weight(g)
        e.state = :neutral
        schaden = grosse_zahl(neu) - grosse_zahl(basis)
        schaden > max_schaden && (max_schaden = schaden; beste = e)
    end
    return beste
end
