# Shannon Switching Game

Julia-Implementierung der optimalen Strategien für beide Spieler, mit
grafischer Oberfläche.

## Hintergrund

Im Shannon Switching Game wählen zwei Spieler abwechselnd Kanten eines Graphen
mit zwei markierten Knoten s und t. Der Short-Spieler sichert Kanten und will
s und t verbinden, der Cut-Spieler verbietet Kanten und will jede Verbindung
unterbinden.

Das Spiel ist vollständig gelöst. Nach dem Satz von Lehman gewinnt der
Short-Spieler als Nachziehender genau dann, wenn der Graph einen Teilgraphen
enthält, der beide markierten Knoten umfasst und selbst zwei kantendisjunkte
Spannbäume besitzt. Anschaulich sind das zwei voneinander unabhängige
Reserve-Verbindungen: Welche Kante Cut auch zerstört, Short repariert mit der
jeweils anderen. Die Strategie hält diese Struktur über das gesamte Spiel
hinweg auf den unbelegten Kanten aufrecht. Geprüft wird sie mit dem
Kishi-Kajitani-Algorithmus über eine Union-Find-Struktur.

Für Cut gibt es kein eigenes Gegenstück zu diesem Satz — das wäre die duale
Bedingung über zwei kantendisjunkte s-t-Schnitte und bräuchte Matroid-Union
auf dem kographischen Matroid. `cut_strategy` schaut stattdessen eine Stufe
voraus: Da die Lehman-Bedingung exakt entscheidet, ob Short gewinnt, wenn Cut
am Zug ist, lässt sich daraus auch entscheiden, ob Short gewinnt, wenn Short
am Zug ist. Cut wählt dann einen Zug, nach dem Short am Zug verliert. Das ist
ebenfalls optimal und kommt ohne neuen Algorithmus aus.

Neben der Standardvariante enthält das Projekt eine gewichtete Version des
Spiels, in der Short das Gewicht seines s-t-Wegs minimieren und Cut es
maximieren will.

## Ausführen

```
git clone https://github.com/ko-fredo/shannon-switching-game
cd shannon-switching-game
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Dann im REPL:

```julia
julia --project=.

julia> using Shannon_Group_Project
julia> run_game()         # selbst spielen, mit Oberfläche
julia> demo_bots()        # beide optimalen Strategien gegeneinander
julia> demo_short()       # optimale Short-Strategie gegen zufälliges Cut
julia> demo_weighted()    # gewichtete Variante
```

Im Fenster ist der grüne Knoten s und der rote t. Short sichert Kanten (dick
blau), Cut entfernt sie (rot gestrichelt). Für jede Seite lässt sich per Knopf
umschalten, ob ein Mensch oder der Bot zieht — auch mitten im Spiel. Spielen
beide Seiten als Bot, liegt zwischen den Zügen eine kurze Pause, sodass man
die Partie verfolgen kann. `run_game()` braucht eine grafische Oberfläche; die
Demos laufen auch im Terminal.

Gegen `short_strategy` zu gewinnen ist auf einem Graphen, der die
Lehman-Bedingung erfüllt, unmöglich — das ist der Sinn der Sache. Interessant
wird es auf dünneren Graphen, wo Short keine Gewinnstellung hat.

## Tests

```
julia --project=. -e 'using Pkg; Pkg.test()'
```

Geprüft werden die Spiellogik, die Bausteine des Kishi-Kajitani-Algorithmus
einzeln (Spannbäume, Fundamentalkreise, Augmentierung, Kontraktion) und
vollständige Partien: Short gegen zufälliges Cut, optimales Cut gegen
zufälliges Short, und beide Strategien gegeneinander.

## Struktur

- `strategy.jl` – optimale Strategien für Short und Cut
- `union_find.jl` – Union-Find-Datenstruktur
- `game.jl` – Spiellogik, Graph- und Spielzustand, Zufallsgraphen
- `submission.jl` – Heuristiken für die gewichtete Variante
- `demo.jl` – Beispielpartien
- `gui.jl` – grafische Oberfläche

## Anmerkungen zur Implementierung

**Die Augmentierung muss schichtweise laufen.** Eine naive rekursive
Tiefensuche liefert keine kürzesten alternierenden Ketten und damit in einem
erheblichen Teil der Fälle ein falsches Ergebnis; nur iteratives BFS
garantiert die Korrektheit.

**Ein Korrektheitsfehler in der Lehman-Prüfung.** Frühere Fassungen haben
nach dem Entfernen der Knoten mit Grad < 2 den Knoten mit dem kleinsten Grad
entfernt und es erneut versucht. Das ist eine Vermutung und kein Argument.
Zerfällt der Graph in mehrere dichte Blöcke, trifft die Regel bei gleichem
Mindestgrad einen Knoten des gesuchten Teilgraphen, zerstört die Lösung und
meldet fälschlich, Short habe keine Gewinnstellung — Short gibt dann eine
garantiert gewonnene Partie auf.

Gefunden wurde das mit einem unabhängigen exakten Orakel. Über Zufallsgraphen
ist der Fehler unsichtbar: 10 240 vollständig durchgeprüfte Stellungen auf
fünf Knoten und je 300 Zufallsstellungen auf sechs bis acht Knoten ergaben
keine einzige Abweichung. Auf gezielt konstruierten Blockstrukturen irrte die
alte Fassung dagegen in 44 von 150 Fällen.

An ihrer Stelle stehen jetzt drei Reduktionsregeln, die einzeln begründbar
sind — Knoten mit Grad < 2 haben zu wenig Kanten für zwei Bäume, außerhalb der
Komponente von s und t liegt nichts Relevantes, und eine Brücke liegt in jedem
Spannbaum und kann daher nie in zweien liegen, die disjunkt sind. Was danach
übrig bleibt, wird erschöpfend durchsucht; nach der Reduktion sind das sehr
wenige Knoten.

**Laufzeit.** `short_strategy` liegt bei O(m²n⁵), `cut_strategy` wegen der
Vorausschau etwa um den Faktor m darüber. Zwei Abkürzungen halten das klein:
Gewinnt Short ohnehin schon als Nachziehender, ist Cut verloren und es wird
gar nicht erst gesucht, und die Prüfung bricht ab, sobald ein Gewinnzug für
Short gefunden ist. Die Breitensuchen verwenden einen Lesezeiger statt
`popfirst!`, das wäre pro Zugriff O(n).

## Mitwirkende

Gemeinschaftsprojekt mit Ben und Ferdi. Meine Hauptaufgabe war die
Implementierung der Short-Strategie.
