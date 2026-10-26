using Gtk4
using Cairo

const CANVAS_W = 760      # Breite der Zeichenfläche
const CANVAS_H = 600      # Höhe der Zeichenfläche
const VRADIUS  = 22       # Radius eines Knotenkreises
const HIT_EDGE = 12       # Klick-Toleranz: so nah muss der Klick an einer Kante sein
const BOT_PAUSE = 700     # Millisekunden zwischen zwei Bot-Zügen


# Text in der Kopfzeile: wer am Zug ist bzw. wer gewonnen hat.
function status_string(state::GameState, short_bot::Bool, cut_bot::Bool)::String
    if state.winner === nothing
        wer  = state.current_player == :short ? "Short" : "Cut"
        art  = (state.current_player == :short ? short_bot : cut_bot) ? "Bot" : "Mensch"
        return "Am Zug: $wer ($art)        s = grün, t = rot"
    end
    return state.winner == :short ? "Short hat gewonnen!" : "Cut hat gewonnen!"
end

# Kürzester Abstand von p zur Strecke ab -> erkennen, welche Kante angeklickt wird.
function _point_segment_dist(px, py, ax, ay, bx, by)
    dx, dy = bx - ax, by - ay
    len2 = dx * dx + dy * dy
    if len2 == 0
        return hypot(px - ax, py - ay)      # falls a == b: euklidischer Abstand
    end
    # Projektion von p auf ab; liegt sie außerhalb, der nächste Punkt dazwischen.
    s = clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0.0, 1.0)
    cx, cy = ax + s * dx, ay + s * dy
    return hypot(px - cx, py - cy)
end

# Nächste Kante am Klickpunkt, 0 wenn keine in Toleranz liegt.
# Belegte Kanten werden übersprungen: Bei dichten Graphen liegen die Sehnen
# im Mittelpunkt übereinander, und ein Treffer auf eine schon gespielte Kante
# wäre ohnehin wirkungslos.
function _edge_at(g::GameGraph, pos, x, y)
    best  = 0
    bestd = HIT_EDGE
    for (i, e) in enumerate(g.edges)
        e.state == :neutral || continue
        (haskey(pos, e.u.id) && haskey(pos, e.v.id)) || continue
        (ax, ay) = pos[e.u.id]
        (bx, by) = pos[e.v.id]
        d = _point_segment_dist(x, y, ax, ay, bx, by)
        if d < bestd
            bestd = d
            best  = i
        end
    end
    return best
end

# Knoten auf einem Kreis anordnen: Knoten-id -> Koordinaten.
function _circular_layout(g::GameGraph)
    pos = Dict{Int, Tuple{Float64,Float64}}()
    cx, cy = CANVAS_W / 2, CANVAS_H / 2
    R = CANVAS_H * 0.36                                 # Abstand zum Rand bleibt
    ids = [v.id for v in g.vertices]
    n = max(length(ids), 1)
    for (i, id) in enumerate(ids)
        θ = -(1/8)*π + 2π * (i - 1) / n
        pos[id] = (cx + R * cos(θ), cy + R * sin(θ))
    end
    return pos
end

function _draw_graph(ctx, state::GameState, pos, show_hints::Bool)
    g = state.graph

    set_source_rgb(ctx, 1, 1, 1)
    paint(ctx)

    for e in g.edges
        (haskey(pos, e.u.id) && haskey(pos, e.v.id)) || continue
        (ax, ay) = pos[e.u.id]
        (bx, by) = pos[e.v.id]

        # Freie Kanten blau unterlegen, solange das Spiel läuft.
        if e.state == :neutral && show_hints
            set_source_rgba(ctx, 0, 0.367, 0.719, 0.20)
            set_line_width(ctx, 11.0)
            move_to(ctx, ax, ay); line_to(ctx, bx, by); stroke(ctx)
        end

        if e.state == :neutral
            set_source_rgb(ctx, 0, 0.367, 0.719)          # neutral: blau, dünn
            set_line_width(ctx, 3.0)
        elseif e.state == :short
            set_source_rgb(ctx, 0.05, 0.30, 0.65)         # Short: blau, dick
            set_line_width(ctx, 7.0)
        else
            set_source_rgba(ctx, 0.80, 0.12, 0.12, 0.55)  # Cut: rot, gestrichelt
            set_line_width(ctx, 2.0)
            set_dash(ctx, [6.0, 5.0])
        end
        move_to(ctx, ax, ay)
        line_to(ctx, bx, by)
        stroke(ctx)
        set_dash(ctx, Float64[])
    end

    set_font_size(ctx, 16.0)

    for v in g.vertices
        haskey(pos, v.id) || continue
        (vx, vy) = pos[v.id]

        if v.id == g.s.id
            set_source_rgb(ctx, 0.10, 0.60, 0.20)     # s: grün
        elseif v.id == g.t.id
            set_source_rgb(ctx, 0.85, 0.12, 0.12)     # t: rot
        else
            set_source_rgb(ctx, 0, 0.367, 0.719)      # übrige: blau
        end
        arc(ctx, vx, vy, VRADIUS, 0.0, 2π)
        fill(ctx)

        # Knotennummer in den Kreis, damit die Knoten unterscheidbar sind.
        txt = string(v.id)
        set_source_rgb(ctx, 1, 1, 1)
        move_to(ctx, vx - 4.5 * length(txt), vy + 5.5)
        show_text(ctx, txt)
    end
end

"""
    run_game(graph::GameGraph = spielgraph())

Öffnet ein Fenster und macht das Shannon-Switching-Spiel spielbar.

Short sichert Kanten (dick blau), Cut entfernt sie (rot gestrichelt). Der
grüne Knoten ist s, der rote ist t. Für jede Seite lässt sich per Knopf
umschalten, ob ein Mensch oder der Bot zieht — auch mitten im Spiel. Short
spielt dann die optimale Strategie nach dem Satz von Lehman, Cut die
optimale Gegenstrategie. Spielen beide Seiten als Bot, liegt zwischen den
Zügen eine kurze Pause.
"""
function run_game(graph::GameGraph = spielgraph())
    state = new_game(deepcopy(graph))     # deepcopy: die Kanten sind veränderlich
    pos   = _circular_layout(state.graph)

    short_bot = Ref(false)
    cut_bot   = Ref(true)
    rechnet   = Ref(false)

    win    = GtkWindow("Shannon-Switching-Spiel", CANVAS_W, CANVAS_H + 110)
    vbox   = GtkBox(:v)
    status = GtkLabel(status_string(state, short_bot[], cut_bot[]))
    canvas = GtkCanvas(CANVAS_W, CANVAS_H)
    reihe1 = GtkBox(:h)
    reihe2 = GtkBox(:h)
    btn_short = GtkButton("Short: Mensch")
    btn_cut   = GtkButton("Cut: Bot")
    btn_new   = GtkButton("Neues Spiel")
    btn_rand  = GtkButton("Zufallsgraph")

    push!(win, vbox)
    push!(vbox, status)
    push!(vbox, canvas)
    push!(vbox, reihe1)
    push!(vbox, reihe2)
    push!(reihe1, btn_short)
    push!(reihe1, btn_cut)
    push!(reihe2, btn_new)
    push!(reihe2, btn_rand)

    function refresh!()
        Gtk4.G_.set_label(status, status_string(state, short_bot[], cut_bot[]))
        draw(canvas)
    end

    ist_bot() = state.current_player == :short ? short_bot[] : cut_bot[]

    # Ist ein Bot am Zug, wird sein Zug zeitversetzt ausgeführt. Dadurch sieht
    # man bei Bot gegen Bot die einzelnen Züge, statt nur das Endergebnis.
    function plane_bot_zug!()
        rechnet[] && return nothing
        state.winner === nothing || return nothing
        isempty(valid_moves(state)) && return nothing
        ist_bot() || return nothing

        rechnet[] = true
        Gtk4.G_.set_label(status, "… rechnet")
        Gtk4.GLib.g_timeout_add(BOT_PAUSE) do
            rechnet[] = false
            if state.winner === nothing && !isempty(valid_moves(state)) && ist_bot()
                e = state.current_player == :short ? short_strategy(state) :
                                                     cut_strategy(state)
                make_move!(state, e)
            end
            refresh!()
            plane_bot_zug!()
            return false          # einmalig, nicht wiederholen
        end
        return nothing
    end

    function neu_starten!(g::GameGraph)
        empty!(pos)
        merge!(pos, _circular_layout(g))
        state = new_game(deepcopy(g))
        refresh!()
        plane_bot_zug!()
    end

    draw(canvas) do widget
        _draw_graph(getgc(widget), state, pos, state.winner === nothing)
    end

    signal_connect(btn_short, "clicked") do _ctrl
        short_bot[] = !short_bot[]
        Gtk4.G_.set_label(btn_short, short_bot[] ? "Short: Bot" : "Short: Mensch")
        refresh!()
        plane_bot_zug!()
    end

    signal_connect(btn_cut, "clicked") do _ctrl
        cut_bot[] = !cut_bot[]
        Gtk4.G_.set_label(btn_cut, cut_bot[] ? "Cut: Bot" : "Cut: Mensch")
        refresh!()
        plane_bot_zug!()
    end

    signal_connect(btn_new, "clicked")  do _ctrl; neu_starten!(state.graph); end
    signal_connect(btn_rand, "clicked") do _ctrl; neu_starten!(spielgraph()); end

    click = GtkGestureClick()
    push!(canvas, click)
    signal_connect(click, "pressed") do _ctrl, _n, x, y
        state.winner === nothing || return    # Spiel vorbei
        rechnet[] && return                   # ein Bot ist gerade dran
        ist_bot() && return                   # dieser Spieler wird vom Bot gezogen
        i = _edge_at(state.graph, pos, x, y)
        i == 0 && return
        e = state.graph.edges[i]
        e.state == :neutral || return
        make_move!(state, e)
        refresh!()
        plane_bot_zug!()                      # ist der Gegner ein Bot, zieht er jetzt
    end

    show(win)
    plane_bot_zug!()                          # falls ein Bot beginnt
    Gtk4.start_main_loop()
end
