# Shannon Switching Game

Julia-Implementierung der optimalen Strategie für den Short-Spieler.

## Hintergrund

Im Shannon Switching Game wählen zwei Spieler abwechselnd Kanten eines Graphen
mit zwei markierten Knoten s und t. Der Short-Spieler sichert Kanten und will
s und t verbinden, der Cut-Spieler verbietet Kanten und will jede Verbindung
unterbinden.

Das Spiel ist vollständig gelöst: Nach dem Satz von Lehman gewinnt der
Short-Spieler als Nachziehender genau dann, wenn der Graph einen Teilgraphen
enthält, der beide markierten Knoten umfasst und selbst zwei kantendisjunkte
Spannbäume besitzt. Anschaulich sind das zwei voneinander unabhängige
Reserve-Verbindungen: Welche Kante Cut auch zerstört, Short repariert mit der
jeweils anderen. Die Strategie hält diese Struktur über das gesamte Spiel
hinweg auf den unbelegten Kanten aufrecht. Geprüft wird sie mit dem
Kishi-Kajitani-Algorithmus über eine Union-Find-Struktur.

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
julia> demo_short()       # Beispielpartie, Standardvariante
julia> demo_weighted()    # gewichtete Variante
julia> run_game()         # selbst spielen (öffnet ein Gtk4-Fenster)
```

`run_game()` braucht eine grafische Oberfläche; die beiden Demos laufen auch
im Terminal.

## Tests

```
julia --project=. -e 'using Pkg; Pkg.test()'
```

Die Tests prüfen die Spiellogik, die Bausteine des Kishi-Kajitani-Algorithmus
einzeln (Spannbäume, Fundamentalkreise, Augmentierung, Kontraktion) und
spielen vollständige Partien gegen einen zufällig ziehenden Cut-Spieler.

## Struktur

- `strategy.jl` – optimale Strategie für den Short-Spieler
- `union_find.jl` – Union-Find-Datenstruktur
- `game.jl` – Spiellogik, Graph- und Spielzustand
- `submission.jl` – Heuristiken für die gewichtete Variante
- `demo.jl` – Beispielpartien
- `gui.jl` – grafische Oberfläche

## Anmerkungen zur Implementierung

Die Augmentierung muss über iteratives BFS erfolgen, um kürzeste alternierende
Ketten zu garantieren – eine naive rekursive DFS-Variante liefert in einem
erheblichen Teil der Fälle falsche Ergebnisse. Die aktuelle Implementierung
von `short_strategy` liegt bei O(m²n⁵); eine Deque anstelle von `popfirst!`
würde einen Faktor n einsparen.

## Mitwirkende

Gemeinschaftsprojekt mit Ben und Ferdi. Meine Hauptaufgabe war die
Implementierung der Short-Strategie.
