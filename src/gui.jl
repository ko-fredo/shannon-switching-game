# ─────────────────────────────────────────────────────────────────────────────
# Grafische Oberfläche für das Shannon-Switching-Spiel (Gtk4 + Cairo).
#
# Diese GUI ist bewusst schlank gehalten und bietet genau die Standard-Funktionen:
#
#   * Kanten werden nach ihrem Zustand eingefärbt
#       - neutral (noch frei)  → grau
#       - von Short gewählt    → blau (dick)
#       - von Cut entfernt     → rot, gestrichelt
#   * Anzeige, welcher Spieler am Zug ist, bzw. wer gewonnen hat
#   * Klick auf eine freie (neutrale) Kante führt den Zug des aktuellen
#     Spielers aus; abwechselnd ziehen Short und Cut
#   * Schaltfläche "Neues Spiel"  → setzt den aktuellen Graphen zurück
#   * Schaltfläche "Zufallsgraph"  → erzeugt einen neuen, zufälligen Graphen
#
# Bewusst NICHT enthalten (früher optionale Zusatzfunktionen): Grapheditor,
# Computer-/KI-Gegner, Beispielgraph-Auswahl, gewichtete Graphen.
# ─────────────────────────────────────────────────────────────────────────────

using Gtk4     # Fenster, Buttons, Labels, Zeichenfläche, Maus-Gesten
using Cairo    # 2D-Zeichnung auf der Zeichenfläche (Linien, Kreise, Text)

# ── Feste Maße der Darstellung (in Pixel) ────────────────────────────────────
const CANVAS_W = 720      # Breite der Zeichenfläche
const CANVAS_H = 560      # Höhe der Zeichenfläche
const VRADIUS  = 18.0     # Radius eines Knotenkreises
const HIT_EDGE = 9.0      # Klick-Toleranz: so nah muss der Klick an einer Kante sein

# ─────────────────────────────────────────────────────────────────────────────
# Statustext
#
# Liefert die Zeile, die oben im Fenster angezeigt wird: entweder wer am Zug ist
# oder – sobald die Partie entschieden ist – wer gewonnen hat.
# ─────────────────────────────────────────────────────────────────────────────
function status_string(state::GameState)::String
    if state.winner === nothing
        # Noch kein Gewinner: Hinweis, welche Partei ziehen muss.
        return state.current_player == :short ? "Am Zug: Short (verbinden)" :
                                                "Am Zug: Cut (trennen)"
    end
    # Partie entschieden.
    return state.winner == :short ? "Short hat gewonnen!" : "Cut hat gewonnen!"
end

# ─────────────────────────────────────────────────────────────────────────────
# Geometrie-Helfer
# ─────────────────────────────────────────────────────────────────────────────

# Kürzester Abstand des Punktes (px,py) zur Strecke von (ax,ay) nach (bx,by).
# Wird gebraucht, um zu erkennen, welche Kante der Nutzer angeklickt hat.
function _point_segment_dist(px, py, ax, ay, bx, by)
    dx, dy = bx - ax, by - ay
    len2 = dx * dx + dy * dy
    if len2 == 0
        # Start- und Endpunkt fallen zusammen → Abstand zum Punkt.
        return hypot(px - ax, py - ay)
    end
    # Projektion des Punktes auf die Gerade, auf [0,1] begrenzt (= auf die Strecke).
    s = clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0.0, 1.0)
    cx, cy = ax + s * dx, ay + s * dy        # nächster Punkt auf der Strecke
    return hypot(px - cx, py - cy)
end

# Sucht die Kante (Index in g.edges), die am dichtesten am Klickpunkt (x,y) liegt.
# Gibt 0 zurück, wenn keine Kante innerhalb der Klick-Toleranz liegt.
function _edge_at(g::GameGraph, pos, x, y)
    best = 0          # bisher bester Kantenindex
    bestd = HIT_EDGE  # bisher kleinster Abstand (startet bei der Toleranzgrenze)
    for (i, e) in enumerate(g.edges)
        # Beide Endknoten müssen eine bekannte Position haben.
        (haskey(pos, e.u.id) && haskey(pos, e.v.id)) || continue
        (ax, ay) = pos[e.u.id]
        (bx, by) = pos[e.v.id]
        d = _point_segment_dist(x, y, ax, ay, bx, by)
        if d <= bestd
            bestd = d
            best = i
        end
    end
    return best
end

# Berechnet für jede Kante einen seitlichen Versatz, damit mehrere Kanten
# zwischen denselben zwei Knoten (Mehrfachkanten) nebeneinander sichtbar sind
# und nicht übereinander liegen.
function _parallel_offsets(g::GameGraph)
    # Kanten nach ihrem (kleineres,größeres) Knotenpaar gruppieren.
    groups = Dict{Tuple{Int,Int}, Vector{Int}}()
    for (i, e) in enumerate(g.edges)
        key = e.u.id <= e.v.id ? (e.u.id, e.v.id) : (e.v.id, e.u.id)
        push!(get!(groups, key, Int[]), i)
    end
    # Jeder Kante einen Versatz symmetrisch um die Mittellinie zuweisen.
    offset = zeros(length(g.edges))
    for (_, idxs) in groups
        c = length(idxs)
        for (r, i) in enumerate(idxs)
            offset[i] = (r - (c + 1) / 2) * 14.0
        end
    end
    return offset
end

# ─────────────────────────────────────────────────────────────────────────────
# Layout: ordnet die Knoten gleichmäßig auf einem Kreis an.
#
# Ergebnis ist ein Dict  Knoten-id  →  (x, y)-Pixelposition.
# ─────────────────────────────────────────────────────────────────────────────
function _circular_layout(g::GameGraph)
    pos = Dict{Int, Tuple{Float64,Float64}}()
    cx, cy = CANVAS_W / 2, CANVAS_H / 2                 # Mittelpunkt der Fläche
    R = min(CANVAS_W, CANVAS_H) * 0.36                 # Radius des Knotenkreises
    ids = [v.id for v in g.vertices]
    n = max(length(ids), 1)
    for (i, id) in enumerate(ids)
        θ = π + 2π * (i - 1) / n                        # Winkel des i-ten Knotens
        pos[id] = (cx + R * cos(θ), cy + R * sin(θ))
    end
    return pos
end

# ─────────────────────────────────────────────────────────────────────────────
# Zeichnen des Graphen
#
# ctx           – Cairo-Zeichenkontext der Zeichenfläche
# state         – aktueller Spielzustand (Graph + Spieler + Gewinner)
# pos           – Positionen der Knoten (siehe _circular_layout)
# show_hints    – true, solange die Partie läuft: freie Kanten werden dezent
#                 grün hervorgehoben, um anklickbare Züge zu zeigen
# ─────────────────────────────────────────────────────────────────────────────
function _draw_graph(ctx, state::GameState, pos, show_hints::Bool)
    g = state.graph

    # Hintergrund füllen (helles Beige).
    set_source_rgb(ctx, 0.97, 0.97, 0.94)
    paint(ctx)

    # Versatz für parallele Kanten vorberechnen.
    offset = _parallel_offsets(g)

    # ── Kanten zeichnen ──────────────────────────────────────────────────────
    for (i, e) in enumerate(g.edges)
        (haskey(pos, e.u.id) && haskey(pos, e.v.id)) || continue
        (ax, ay) = pos[e.u.id]
        (bx, by) = pos[e.v.id]

        # Senkrechten Versatz anwenden, damit Mehrfachkanten getrennt erscheinen.
        dx, dy = bx - ax, by - ay
        len = hypot(dx, dy)
        len = len == 0 ? 1.0 : len
        ox, oy = -dy / len * offset[i], dx / len * offset[i]
        ax2, ay2, bx2, by2 = ax + ox, ay + oy, bx + ox, by + oy

        # Freie Kanten während des Spiels dezent grün unterlegen (= "hier klickbar").
        if e.state == :neutral && show_hints
            set_source_rgba(ctx, 0.20, 0.70, 0.25, 0.55)
            set_line_width(ctx, 11.0)
            set_dash(ctx, Float64[])
            move_to(ctx, ax2, ay2); line_to(ctx, bx2, by2); stroke(ctx)
        end

        # Eigentliche Kante je nach Zustand einfärben.
        if e.state == :neutral
            set_source_rgb(ctx, 0.55, 0.55, 0.55)         # neutral = grau
            set_line_width(ctx, 3.0)
            set_dash(ctx, Float64[])
        elseif e.state == :short
            set_source_rgb(ctx, 0.10, 0.30, 0.85)         # Short = blau, dick
            set_line_width(ctx, 6.0)
            set_dash(ctx, Float64[])
        else # :cut
            set_source_rgba(ctx, 0.80, 0.12, 0.12, 0.65)  # Cut = rot, gestrichelt
            set_line_width(ctx, 2.0)
            set_dash(ctx, [6.0, 5.0])
        end
        move_to(ctx, ax2, ay2); line_to(ctx, bx2, by2); stroke(ctx)
        set_dash(ctx, Float64[])                          # Strichmuster zurücksetzen
    end

    # ── Knoten zeichnen ──────────────────────────────────────────────────────
    for v in g.vertices
        haskey(pos, v.id) || continue
        (vx, vy) = pos[v.id]
        is_s = v.id == g.s.id      # Startknoten s
        is_t = v.id == g.t.id      # Zielknoten t

        # Füllfarbe: s grün, t orange, sonst dunkelgrau.
        if is_s
            set_source_rgb(ctx, 0.15, 0.55, 0.20)
        elseif is_t
            set_source_rgb(ctx, 0.90, 0.55, 0.10)
        else
            set_source_rgb(ctx, 0.30, 0.30, 0.35)
        end
        arc(ctx, vx, vy, VRADIUS, 0.0, 2π); fill(ctx)

        # Dünner schwarzer Rand um den Knoten.
        set_source_rgb(ctx, 0.1, 0.1, 0.1)
        set_line_width(ctx, 1.5)
        arc(ctx, vx, vy, VRADIUS, 0.0, 2π); stroke(ctx)

        # Beschriftung: "s", "t" oder die Knotennummer, zentriert.
        label = is_s ? "s" : is_t ? "t" : string(v.id)
        set_source_rgb(ctx, 1.0, 1.0, 1.0)
        select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
        set_font_size(ctx, 16.0)
        te = text_extents(ctx, label)
        move_to(ctx, vx - te[3] / 2 - te[1], vy - te[4] / 2 - te[2])
        show_text(ctx, label)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Hauptfenster
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_game(graph::GameGraph = example_graph())

Öffnet ein Gtk4-Fenster und macht das Shannon-Switching-Spiel spielbar.

Zwei Personen ziehen abwechselnd: **Short** klickt eine freie Kante an, um sie
zu sichern (blau), **Cut** klickt eine freie Kante an, um sie zu entfernen (rot).
Short gewinnt, sobald seine Kanten s und t verbinden; Cut gewinnt, sobald das
unmöglich geworden ist.

Über die Schaltflächen lässt sich die laufende Partie zurücksetzen
("Neues Spiel") oder ein neuer Zufallsgraph erzeugen ("Zufallsgraph").
"""
function run_game(graph::GameGraph = example_graph(); _setup_only::Bool = false)
    # Aktueller Spielzustand. Eine Kopie, damit der übergebene Graph unangetastet bleibt.
    state = new_game(deepcopy(graph))
    # Knotenpositionen für die Zeichnung.
    pos = _circular_layout(state.graph)
    # Kurze Beschreibung des aktuellen Graphen (für das Info-Label).
    info_text = Ref("Beispielgraph")

    # ── Widgets aufbauen ─────────────────────────────────────────────────────
    win    = GtkWindow("Shannon-Switching-Spiel", CANVAS_W, CANVAS_H + 110)
    vbox   = GtkBox(:v)                                   # vertikale Anordnung
    status = GtkLabel(status_string(state))              # Zeile "Am Zug: …"
    info   = GtkLabel(info_text[])                       # Zeile mit Graph-Info
    canvas = GtkCanvas(CANVAS_W, CANVAS_H)               # Zeichenfläche

    # Knopfleiste mit den beiden Schaltflächen.
    row     = GtkBox(:h)
    btn_new  = GtkButton("Neues Spiel")
    btn_rand = GtkButton("Zufallsgraph")

    # Ein bisschen Abstand für Labels und Knopfleiste.
    for w in (status, info)
        Gtk4.G_.set_margin_top(w, 6); Gtk4.G_.set_margin_bottom(w, 2)
    end
    Gtk4.G_.set_margin_top(row, 4); Gtk4.G_.set_margin_bottom(row, 4)

    # Widgets ins Fenster einhängen (Reihenfolge = Anordnung von oben nach unten).
    push!(win, vbox)
    push!(vbox, status)
    push!(vbox, canvas)
    push!(vbox, info)
    push!(vbox, row)
    push!(row, btn_new)
    push!(row, btn_rand)

    # ── Hilfsfunktionen ──────────────────────────────────────────────────────

    # Oberfläche an den aktuellen Spielzustand anpassen: Statuszeile, Info und
    # Neuzeichnen der Zeichenfläche.
    function refresh!()
        Gtk4.G_.set_label(status, status_string(state))
        Gtk4.G_.set_label(info, info_text[])
        draw(canvas)
    end

    # Übernimmt einen neuen Graphen und startet damit eine frische Partie.
    function load_graph!(g::GameGraph, label::String)
        empty!(pos); merge!(pos, _circular_layout(g))    # neue Positionen
        info_text[] = label
        state = new_game(deepcopy(g))
        refresh!()
    end

    # ── Zeichnen ─────────────────────────────────────────────────────────────
    # Wird von Gtk aufgerufen, sobald die Zeichenfläche neu gemalt werden muss.
    @guarded draw(canvas) do widget
        ctx = getgc(widget)
        # Hinweise (grüne Hervorhebung freier Kanten) nur zeigen, solange offen.
        _draw_graph(ctx, state, pos, state.winner === nothing)
    end

    # ── Schaltfläche "Neues Spiel": gleichen Graphen zurücksetzen ────────────
    signal_connect(btn_new, "clicked") do _
        # Alle Kanten wieder freigeben und Partie neu starten.
        for e in state.graph.edges
            e.state = :neutral
        end
        state = new_game(state.graph)
        refresh!()
    end

    # ── Schaltfläche "Zufallsgraph": neuen zufälligen Graphen erzeugen ───────
    signal_connect(btn_rand, "clicked") do _
        n = rand(5:9)                                    # zufällige Knotenzahl
        m = rand(n:min(n*(n-1)÷2, n + 6))                # zufällige Kantenzahl
        load_graph!(random_graph(n, m),
                    "Zufallsgraph ($n Knoten, $m Kanten)")
    end

    # ── Maus-Klick auf die Zeichenfläche: Zug ausführen ──────────────────────
    click = GtkGestureClick()
    push!(canvas, click)
    signal_connect(click, "pressed") do _ctrl, _n, x, y
        # Bei entschiedener Partie sind keine Züge mehr möglich.
        state.winner === nothing || return
        # Welche Kante wurde angeklickt?
        i = _edge_at(state.graph, pos, x, y)
        i == 0 && return                                 # daneben geklickt
        e = state.graph.edges[i]
        e.state == :neutral || return                    # bereits belegte Kante
        # Zug des aktuellen Spielers ausführen und Anzeige aktualisieren.
        make_move!(state, e)
        refresh!()
    end

    # ── Fenster anzeigen und Ereignisschleife starten ───────────────────────
    _setup_only && return win        # Testhaken: nur Aufbau prüfen, nicht öffnen
    show(win)
    Gtk4.start_main_loop()
    # Beim nicht-interaktiven Start blockieren, bis das Fenster geschlossen wird.
    if !isinteractive()
        done = Channel{Nothing}(1)
        signal_connect(win, "close-request") do _
            isopen(done) && put!(done, nothing)
            return false
        end
        take!(done)
    end
end
