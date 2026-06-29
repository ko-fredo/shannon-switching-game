using Gtk4
using Cairo

const CANVAS_W = 720      # breite Zeichenfläche
const CANVAS_H = 560      # höhe Zeichenfläche
const VRADIUS  = 20       # Radius eines Knotenkreises
const HIT_EDGE = 9        # Klick-Toleranz: so nah muss der Klick an einer Kante sein


# text: wer am zug ist bzw. wer gewonnen hat
function status_string(state::GameState)::String
    if state.winner === nothing
        return state.current_player == :short ? "Am Zug: Short" : "Am Zug: Cut"
    end
    return state.winner == :short ? "Short hat gewonnen!" : "Cut hat gewonnen!"
end

#kürzester abstand von p zur gerade \overline{ab} -> erkennen welche kante angeklickt wird
function _point_segment_dist(px, py, ax, ay, bx, by)
    dx, dy = bx - ax, by - ay
    len2 = dx * dx + dy * dy
    if len2 == 0
        # falls a=b euklidischer abstand d(a,b)
        return hypot(px - ax, py - ay)
    end
    # projektion von p auf \overline{ab} mit skalarprodukt -> wenn nicht zwischen a und b suche nächsten punkt der dazwischen ist
    s = clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0.0, 1.0)
    cx, cy = ax + s * dx, ay + s * dy
    return hypot(px - cx, py - cy)
end

# sucht nächste kante an klickpunkt -> 0 wenn keine kante in toleranzgrenze ist
function _edge_at(g::GameGraph, pos, x, y)
    best = 0          # bisher bester kantenindex
    bestd = HIT_EDGE  # bisher kleinster abstand (start bei toleranzgrenze)
    for (i, e) in enumerate(g.edges)
        # Beide Endknoten müssen eine bekannte Position haben.
        (haskey(pos, e.u.id) && haskey(pos, e.v.id)) || continue    #wenn gilt machen sonst diese kante überspringen
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

# anordnug kanten auf einem Kreis -> knoten-id mit koordinaten in dict
function _circular_layout(g::GameGraph)
    pos = Dict{Int, Tuple{Float64,Float64}}()
    cx, cy = CANVAS_W / 2, CANVAS_H / 2                 # mittelpunkt
    R = CANVAS_H * 0.36                                 # radius knotenkreis, so dass noch abstand zu rand ist
    ids = [v.id for v in g.vertices]
    n = max(length(ids), 1)                             # teilen durch 0 vermeiden (redundant weil random_graph immer mind 2 knoten)
    for (i, id) in enumerate(ids)
        θ = -(1/8)*π + 2π * (i - 1) / n                            # winkel i-ter knoten
        pos[id] = (cx + R * cos(θ), cy + R * sin(θ))    # position knoten mit polarkoordinaten kreis
    end
    return pos
end

function _draw_graph(ctx, state::GameState, pos, show_hints::Bool)
    g = state.graph

    #hintergrund zeichnen
    set_source_rgb(ctx,1,1,1)
    paint(ctx)

    # kanten zeichnen
    for e in g.edges
        (haskey(pos, e.u.id) && haskey(pos, e.v.id)) || continue
        (ax2, ay2) = pos[e.u.id]
        (bx2, by2) = pos[e.v.id]

        # freie kanten mit blau unterlegen
        if e.state == :neutral && show_hints
            set_source_rgba(ctx, 0, 0.367, 0.719, 0.20)
            set_line_width(ctx, 11.0)
            move_to(ctx, ax2, ay2); line_to(ctx, bx2, by2); stroke(ctx)
        end

        # Kante je nach Zustand einfärben.
        if e.state == :neutral
            set_source_rgb(ctx, 0, 0.367, 0.719)         # neutral = blau, dünn
            set_line_width(ctx, 3.0)
        elseif e.state == :short
            set_source_rgb(ctx, 0.10, 0.367, 0.719)         # Short = blau, dick
            set_line_width(ctx, 6.0)
        else # :cut
            set_source_rgba(ctx, 0.80, 0.12, 0.12, 0.65)  # Cut = rot, gestrichelt
            set_line_width(ctx, 2.0)
            set_dash(ctx, [6.0, 5.0])
        end
        move_to(ctx, ax2, ay2)                            # kante von a nach b malen
        line_to(ctx, bx2, by2)
        stroke(ctx)
        set_dash(ctx, Float64[])                          # gestrichelte linie zurücksetzen
    end

    # knoten zeichnen
    for v in g.vertices
        haskey(pos, v.id) || continue
        (vx, vy) = pos[v.id]
        is_s = v.id == g.s.id      # startknoten s
        is_t = v.id == g.t.id      # zielknoten t

        # farbe von s und t hervorheben
        if is_s
            set_source_rgb(ctx, 1, 0, 0)
        elseif is_t
            set_source_rgb(ctx, 1, 0, 0)
        else
            set_source_rgb(ctx, 0, 0.367, 0.719)
        end
        arc(ctx, vx, vy, VRADIUS, 0.0, 2π)      # kreis an kotenposition malen und dann ausfüllen
        fill(ctx)
    end
end

"""
    run_game(graph::GameGraph = example_graph())

Öffnet ein Gtk4-Fenster und macht das Shannon-Switching-Spiel spielbar.
Short klickt eine freie Kante an, um sie zu sichern (blau);
Cut klickt eine freie Kante an, um sie zu entfernen (rot).
"""
function run_game(graph::GameGraph = example_graph())
    state = new_game(deepcopy(graph))               # deepcopy um mutable struct edge nicht zu verändern
    pos   = _circular_layout(state.graph)           # positionen aller knoten berechnen

    win    = GtkWindow("Shannon-Switching-Spiel", CANVAS_W, CANVAS_H + 80)  # window
    vbox   = GtkBox(:v)                                                     # stapelt untereinander
    status = GtkLabel(status_string(state))                                 
    canvas = GtkCanvas(CANVAS_W, CANVAS_H)
    row    = GtkBox(:h)                                                     # stapelt nebeneinander
    btn_new  = GtkButton("Neues Spiel")
    btn_rand = GtkButton("Zufallsgraph")

    push!(win, vbox)                                                        # alles hintereinander einfügen
    push!(vbox, status)
    push!(vbox, canvas)
    push!(vbox, row)
    push!(row, btn_new)
    push!(row, btn_rand)

    # status und canvas aktualisieren
    function refresh!()
        Gtk4.G_.set_label(status, status_string(state))
        draw(canvas)                                    
    end

    draw(canvas) do widget  # callback für "draw" signal, widget ist von gtk automatisch übergebene zeichenfläche                                       
        _draw_graph(getgc(widget), state, pos, state.winner === nothing) # getgc holt daraus cairo zeichenkontext (ctx) und dann mit neuen infos neuen graphen zeichnen
    end

    signal_connect(btn_new, "clicked") do _ctrl # automatisch übergebenes objekt wird aber nicht gebraucht
        for e in state.graph.edges
            e.state = :neutral
        end
        state = new_game(state.graph)
        refresh!()
    end

    signal_connect(btn_rand, "clicked") do _ctrl
        n = rand(5:9)
        m = rand(n-1:n*(n-1)÷2)    # einfacher zusammenhängender graph hat mind n-1 kanten und max n*(n-1)/2 kanten
        g = random_graph(n, m)
        empty!(pos)
        merge!(pos, _circular_layout(g))    # merge damit wir pos verändern und nicht neue lokale variable erstellen
        state = new_game(deepcopy(g))
        refresh!()
    end

    click = GtkGestureClick()
    push!(canvas, click)        # click überwacht clicks auf canvas
    signal_connect(click, "pressed") do _ctrl, _n, x, y     #erste zwei übergebene: objekt und anzahl clicks irrelevant, (x,y) korrdinaten
        state.winner === nothing || return                  # wenn schon gewinner verlasse sofort 
        i = _edge_at(state.graph, pos, x, y)                # gucke nach nächster kante an click
        i == 0 && return                                    # falls keine kante in toleranzgrenze verlasse
        e = state.graph.edges[i]                            
        e.state == :neutral || return                       # falls geklickte kante belegt mache nichts
        make_move!(state, e)                                # mach den move und aktualisier 
        refresh!()
    end

    show(win)       # macht fenster sichtbar
    Gtk4.start_main_loop()  # fenster bleibt offen und wartet auf ereignisse, programm läuft bis fenster geschlossen wird
end