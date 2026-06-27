# ═══════════════════════════════════════════════════════════════════════════════
# Wettbewerbs-Abgabe für den comajudge – Shannon-Switching (gewichtetes Spiel)
# Team WT19
#
# Abgeben mit:   comajudge submit -t WT19_submission.jl -p Shannon
# Ergebnis mit:  comajudge result -p Shannon
#
# Diese Datei ist EIGENSTÄNDIG: Sie enthält nur die Wettbewerbsstrategie
# (weighted_short / weighted_cut), TEAM_NAME und alle benötigten Hilfsfunktionen.
# Die Datenstrukturen (Vertex, Edge, GameGraph, GameState) stellt der comajudge
# bereit (laut Aufgaben-PDF, Abschnitt 5.3).
#
# Idee der Heuristik (für beide Spieler dieselbe Größe): die Kosten des aktuell
# günstigsten s-t-Wegs (gesicherte Short-Kanten kosten 0, entfernte sind unbenutzbar).
#   * Short sichert die "Engpass-Kante" – deren Verlust den Weg am meisten verteuert.
#   * Cut entfernt genau diese Engpass-Kante.
# ═══════════════════════════════════════════════════════════════════════════════

const TEAM_NAME = "WT19"


# ── Hilfsfunktionen (eigenständig, hängen nur an den Datenstrukturen) ──────────

# Alle neutralen (= noch wählbaren) Kanten.
_neutral_edges(state::GameState) = [e for e in state.graph.edges if e.state == :neutral]

# Adjazenzliste über "erlaubte" Kanten. `allowed` bekommt den Kantenzustand
# (:neutral/:short/:cut) und gibt true/false zurück. Eintrag: (Nachbar, Kanten-Index).
function _adj(g::GameGraph, allowed::Function)
    d = Dict{Int,Vector{Tuple{Int,Int}}}()
    for v in g.vertices
        d[v.id] = Tuple{Int,Int}[]
    end
    for (i, e) in enumerate(g.edges)
        if allowed(e.state)
            push!(d[e.u.id], (e.v.id, i))
            push!(d[e.v.id], (e.u.id, i))
        end
    end
    return d
end

# Gibt es einen Weg from→to über erlaubte Kanten? (Breitensuche)
function _path_exists(g::GameGraph, from::Int, to::Int, allowed::Function)::Bool
    from == to && return true
    adj  = _adj(g, allowed)
    seen = Set{Int}([from]); queue = Int[from]
    while !isempty(queue)
        u = popfirst!(queue)
        for (v, _) in adj[u]
            v == to && return true
            if v ∉ seen
                push!(seen, v); push!(queue, v)
            end
        end
    end
    return false
end

# Günstigster s-t-Weg (Dijkstra). Schon gesicherte Short-Kanten kosten 0.
# Rückgabe: Kanten-Indizes des Weges (oder [], falls keiner existiert).
function _cheapest_path(g::GameGraph)
    dist = Dict(v.id => Inf for v in g.vertices); dist[g.s.id] = 0.0
    prev = Dict{Int,Tuple{Int,Int}}(); done = Set{Int}()
    adj  = _adj(g, s -> s == :neutral || s == :short)

    while true
        u, d_u = -1, Inf
        for (v, d) in dist
            (v ∉ done && d < d_u) && (u = v; d_u = d)
        end
        (u == -1 || u == g.t.id) && break
        push!(done, u)
        for (v, idx) in adj[u]
            v in done && continue
            e = g.edges[idx]
            w = e.state == :short ? 0.0 : e.weight
            if dist[u] + w < get(dist, v, Inf)
                dist[v] = dist[u] + w; prev[v] = (u, idx)
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

# Kosten des günstigsten s-t-Wegs (Inf, falls s und t nicht verbunden werden können).
function _cheapest_path_weight(g::GameGraph)
    path = _cheapest_path(g)
    isempty(path) && return (g.s.id == g.t.id ? 0.0 : Inf)
    return sum(g.edges[i].state == :short ? 0.0 : g.edges[i].weight for i in path; init = 0.0)
end

# Würde das Sichern von Kante e sofort einen s-t-Weg aus lauter Short-Kanten schließen?
function _completes_short_path(g::GameGraph, e::Edge)
    e.state == :neutral || return false
    e.state = :short
    ok = _path_exists(g, g.s.id, g.t.id, s -> s == :short)
    e.state = :neutral
    return ok
end


# ── Wettbewerbsstrategie ──────────────────────────────────────────────────────

"""
    weighted_short(state::GameState) -> Edge

Sichert auf dem günstigsten s-t-Weg die Engpass-Kante (deren Verlust den Weg am
stärksten verteuern würde).
"""
function weighted_short(state::GameState)::Edge
    g     = state.graph
    zuege = _neutral_edges(state)
    isempty(zuege) && error("weighted_short: keine Züge möglich")

    # Direkte Fertigstellung einer Verbindung sichert Punkte.
    for e in zuege
        _completes_short_path(g, e) && return e
    end

    weg        = _cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && return first(zuege)

    basis = _cheapest_path_weight(g)
    beste, max_schaden = kandidaten[1], -Inf
    for e in kandidaten
        e.state = :cut
        schaden = _cheapest_path_weight(g) - basis
        e.state = :neutral
        schaden > max_schaden && (max_schaden = schaden; beste = e)
    end
    return beste
end

"""
    weighted_cut(state::GameState) -> Edge

Entfernt die Kante, die den günstigsten s-t-Weg am stärksten verteuert.
"""
function weighted_cut(state::GameState)::Edge
    g     = state.graph
    zuege = _neutral_edges(state)
    isempty(zuege) && error("weighted_cut: keine Züge möglich")

    # Sofortgewinn: trennt ein Zug s und t vollständig?
    for e in zuege
        e.state  = :cut
        getrennt = !_path_exists(g, g.s.id, g.t.id, s -> s == :neutral || s == :short)
        e.state  = :neutral
        getrennt && return e
    end

    weg        = _cheapest_path(g)
    kandidaten = [g.edges[i] for i in weg if g.edges[i].state == :neutral]
    isempty(kandidaten) && (kandidaten = zuege)

    grosse_zahl(x) = isinf(x) ? 1e9 : x
    basis = _cheapest_path_weight(g)
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
