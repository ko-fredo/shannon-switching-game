# Shannon Switching Game

Julia-Implementierung der optimalen Strategien für beide Spieler, mit
grafischer Oberfläche.

## Hintergrund

Im Shannon Switching Game wählen zwei Spieler abwechselnd Kanten eines Graphen
mit zwei markierten Knoten s und t. Der Short-Spieler sichert Kanten und will
s und t verbinden, der Cut-Spieler verbietet Kanten und will jede Verbindung
unterbinden.

Das Spiel ist vollständig gelöst. Nach dem Satz von Lehman gewinnt der
Short-Spieler als Zweiter genau dann, wenn der Graph einen Teilgraphen
enthält, der beide markierten Knoten umfasst und selbst zwei kantendisjunkte
Spannbäume besitzt. Welche Kante Cut auch zerstört, Short repariert mit einer
jeweils anderen aus dem anderen Spannbaum. Die Strategie hält diese Struktur über das gesamte Spiel
hinweg auf den unbelegten Kanten aufrecht. Geprüft wird sie mit dem
Kishi-Kajitani-Algorithmus über eine Union-Find-Struktur.

Die Cut-Strategie basiert auf der Short-Strategie. Da die Lehman-Bedingung exakt entscheidet, ob Short gewinnt, wenn Cut
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

## Struktur

- `strategy.jl` – optimale Strategien für Short und Cut
- `union_find.jl` – Union-Find-Datenstruktur
- `game.jl` – Spiellogik, Graph- und Spielzustand, Zufallsgraphen
- `submission.jl` – Heuristiken für die gewichtete Variante
- `demo.jl` – Beispielpartien
- `gui.jl` – grafische Oberfläche

## Anmerkungen zur Implementierung

**Korrektheit in der Lehman-Prüfung.** Frühere Fassungen haben
nach dem Entfernen der Knoten mit Grad < 2 den Knoten mit dem kleinsten Grad
entfernt und es erneut versucht. Das ist eine Vermutung. Wurde aber auf über
10000 zufälligen Graphen mit unterschiedlichen Knotenanzahlen ohne Fehler getestet.
Zerfällt der Graph dadurch in mehrere dichte Blöcke, trifft die Regel bei gleichem
Mindestgrad einen Knoten des gesuchten Teilgraphen, zerstört die Lösung und
meldet fälschlich, Short habe keine Gewinnstellung.

An ihrer Stelle stehen jetzt drei Reduktionsregeln, die einzeln begründbar
sind — Knoten mit Grad < 2 haben zu wenig Kanten für zwei Bäume, außerhalb der
Komponente von s und t liegt nichts Relevantes, und eine Brücke liegt in jedem
Spannbaum und kann daher nie in zweien liegen, die disjunkt sind. Was danach
übrig bleibt, wird komplett durchsucht.  

**Laufzeit.** `short_strategy` liegt bei O(m²n⁵), `cut_strategy` wegen der
Vorausschau etwa um den Faktor m darüber.

## Mitwirkende

Gemeinschaftsprojekt mit Ben und Ferdi. Meine Hauptaufgabe war die
Implementierung der Short-Strategie.
