# ═══════════════════════════════════════════════════════════════════════════════
# Shannon-Switching-Spiel – Optimale Strategie für Short (klassisches Spiel)
# TU Berlin, CoMa II, SoSe 2026
#
#   short_strategy – optimale Strategie für Short im ungewichteten Spiel
#
# Kern der Strategie sind zwei kantendisjunkte Spannbäume, berechnet mit dem
# Verfahren aus Anhang A der PDF (maximally_distant_trees! = Kishi-Kajitani,
# augment_along_common_chord! = Augmentierung entlang einer gemeinsamen Sehne).
#
# Hinweis: Eine optimale Cut-Strategie für das klassische Spiel ist laut Aufgabe
# nicht verpflichtend und wird hier bewusst NICHT implementiert. Die Heuristiken
# für das GEWICHTETE Spiel (weighted_short/weighted_cut, TEAM_NAME) stehen in der
# eigenständigen Wettbewerbsdatei WT19_submission.jl.
#
# Voraussetzung: Die Datenstrukturen (Vertex, Edge, GameGraph, GameState) sowie
# valid_moves, path_exists und adjacency_list sind in game.jl definiert.
# ═══════════════════════════════════════════════════════════════════════════════

include("union_find.jl")


# ───────────────────────────────────────────────────────────────────────────────
# Kleiner Helfer: einen Weg als Liste von Kanten-Indizes finden (Breitensuche/BFS)
# ───────────────────────────────────────────────────────────────────────────────
# Sucht einen Weg von Knoten `from` nach `to`, der nur über "erlaubte" Kanten läuft.
# `allowed` ist eine Funktion, die den Zustand einer Kante (:neutral/:short/:cut)
# bekommt und true/false zurückgibt. Rückgabe: Liste der benutzten Kanten-Indizes
# (oder eine leere Liste, falls es keinen solchen Weg gibt).
function find_path(g::GameGraph, from::Int, to::Int, allowed::Function)::Vector{Int}
    adj = adjacency_list(g, allowed)            # adjacency list gibt adj_nodes = Dict{Int, Vector{Tuple{Int,Int}}}() zurück
    vorgaenger = Dict{Int,Tuple{Int,Int}}()     
    besucht    = Set{Int}([from])
    queue      = Int[from]
    # BFS
    while !isempty(queue)
        u = popfirst!(queue)
        if u == to 
            break
        end     
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
# Diese zwei kantendisjunkten Spannbäume berechnen wir GENAU mit dem Verfahren
# aus Anhang A der Aufgaben-PDF:
#   * maximally_distant_trees!   – Algorithmus 3 (Kishi-Kajitani)
#   * augment_along_common_chord! – Algorithmus 4 (Augmentierung)
# Man startet mit zwei beliebigen Spannbäumen und erhöht ihren "Abstand"
# |T1\T2| Schritt für Schritt, bis er maximal ist. Besitzt der Graph zwei
# kantendisjunkte Spannbäume, kommen am Ende genau solche heraus.
# ═══════════════════════════════════════════════════════════════════════════════

# Baut einen Spannbaum (Menge von Kanten-Indizes) per Union-Find auf.
# Rückgabe: die Kantenmenge, oder `nothing`, falls der Graph nicht zusammenhängt.
function _spanning_tree(n, edgelist)::Union{Set{Int},Nothing}
    nodes = union_find([(i, [i]) for i in 1:n])
    tree  = Set{Int}()
    for (i, (u, v)) in enumerate(edgelist)
        if find_set!(nodes[u]).value != find_set!(nodes[v]).value
            union!(nodes[u], nodes[v])
            push!(tree, i)
        end
    end
    return length(tree) == n - 1 ? tree : nothing
end

# Fundamentalkreis FC(chord, tree): Fügt man die Sehne `chord` zum Spannbaum
# `tree` hinzu, entsteht genau ein Kreis. Zurückgegeben werden die BAUMKANTEN
# auf diesem Kreis (= der eindeutige Baumweg zwischen den Endpunkten von `chord`).
function fundamental_cycle(tree::Set{Int}, edgelist, n, chord::Int)::Vector{Int}
    (a, b) = edgelist[chord]
    adj = [Tuple{Int,Int}[] for _ in 1:n]
    for i in tree
        (u, v) = edgelist[i]
        push!(adj[u], (v, i)); push!(adj[v], (u, i))
    end

    # BFS von a nach b im Baum, Vorgänger merken.
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

    path, cur = Int[], b
    while cur != a
        p, i = prev[cur]; push!(path, i); cur = p
    end
    return path
end

# Algorithmus 4 (PDF): Augmentierung entlang einer gemeinsamen Sehne.
# `e` ist eine "gemeinsame Sehne" (liegt in keinem der beiden Bäume). Die Funktion
# sucht eine alternierende Tauschkette c1, c2, …, f (abwechselnd aus T1 und T2),
# die bei einer GEMEINSAMEN Baumkante f endet, und führt den Tausch aus. Dadurch
# steigt der Abstand |T1\T2| um genau 1. Rückgabe: true, falls ein Tausch gelang.
function augment_along_common_chord!(T1::Set{Int}, T2::Set{Int}, edgelist, n, e::Int)
    par = Dict{Int,Int}()                 # Kante -> Vorgängerkante in der Suche
    entdeckt = Set{Int}()                 # bereits besuchte Kanten

    # Schicht 1: L¹ = FC(e, T1) – das sind Kanten aus T1.
    schicht = Int[]
    for f in fundamental_cycle(T1, edgelist, n, e)
        push!(schicht, f); push!(entdeckt, f)
    end

    k = 1
    while !isempty(schicht)
        # In Schicht k liegen Kanten des einen Baums; "andererbaum" ist der jeweils
        # andere. Liegt eine Schichtkante auch im anderen Baum, ist sie gemeinsam
        # → Endpunkt f der Tauschkette gefunden.
        andererbaum = isodd(k) ? T2 : T1
        f = 0
        for c in schicht
            if c in andererbaum
                f = c; break
            end
        end

        if f != 0
            # Kette von f über die Vorgänger zurück bis zur Wurzel (Schicht 1).
            chain = Int[f]
            x = f
            while haskey(par, x)
                x = par[x]; pushfirst!(chain, x)
            end
            # Tausch (PDF Z. 11–12): e kommt nach T1; entlang der Kette wechseln
            # die Kanten abwechselnd den Baum.
            push!(T1, e)
            for (i, c) in enumerate(chain)
                if isodd(i)
                    delete!(T1, c); push!(T2, c)
                else
                    delete!(T2, c); push!(T1, c)
                end
            end
            return true
        end

        # Keine gemeinsame Kante in dieser Schicht → nächste Schicht aufbauen:
        # für jede Kante g die Fundamentalkreis-Kanten im anderen Baum sammeln.
        naechste = Int[]
        for g in schicht
            for fp in fundamental_cycle(andererbaum, edgelist, n, g)
                if fp ∉ entdeckt
                    push!(entdeckt, fp); par[fp] = g; push!(naechste, fp)
                end
            end
        end
        schicht = naechste
        k += 1
    end
    return false
end

# Algorithmus 3 (PDF): Maximal distante Spannbäume (Kishi-Kajitani).
# Solange sich noch eine gemeinsame Sehne augmentieren lässt, wird der Abstand
# der beiden Bäume erhöht. Danach sind T1 und T2 maximal distant – und falls der
# Graph zwei kantendisjunkte Spannbäume besitzt, sind sie es dann auch.
function maximally_distant_trees!(T1::Set{Int}, T2::Set{Int}, edgelist, n)
    changed = true
    while changed
        changed = false
        for e in 1:length(edgelist)
            if e ∉ T1 && e ∉ T2                            # gemeinsame Sehne
                augment_along_common_chord!(T1, T2, edgelist, n, e) && (changed = true)
            end
        end
    end
    return T1, T2
end

# Besitzt der Graph zwei KANTENDISJUNKTE Spannbäume? Wir bauen zwei Spannbäume
# und machen sie mit Kishi-Kajitani maximal distant; bleibt keine gemeinsame
# Kante übrig, ist die Antwort ja.
function _has_two_disjoint_spanning_trees(n, edgelist)::Bool
    n <= 1 && return true
    T1 = _spanning_tree(n, edgelist)
    T1 === nothing && return false                          # nicht zusammenhängend
    T2 = _spanning_tree(n, edgelist)
    maximally_distant_trees!(T1, T2, edgelist, n)
    return isempty(intersect(T1, T2))
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

# Baut aus den "lebenden" Knoten einen kompakten Teilgraphen (Knoten auf 1..k
# umnummeriert) und prüft, ob er zwei kantendisjunkte Spannbäume besitzt.
function _alive_has_two_trees(N, edgelist, alive)
    neu = zeros(Int, N); k = 0
    for v in 1:N; alive[v] && (k += 1; neu[v] = k); end
    kanten = [(neu[u], neu[w]) for (u, w) in edgelist if alive[u] && alive[w] && u != w]
    return _has_two_disjoint_spanning_trees(k, kanten)
end

# Lehman-Test: Gibt es eine Knotenmenge mit s und t, auf der zwei kantendisjunkte
# Spannbäume existieren? Vorgehen: Knoten, die offensichtlich nicht helfen können
# (Grad < 2), nach und nach entfernen und dann (per Kishi-Kajitani) prüfen.
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

        _alive_has_two_trees(N, edgelist, alive) && return true   # Short gewinnt!

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
