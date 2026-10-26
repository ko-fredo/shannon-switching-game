# Shannon Switching Game

Julia-Implementierung der optimalen Strategie für den Short-Spieler.

## Hintergrund

Im Shannon Switching Game wählen zwei Spieler abwechselnd Kanten eines 
Graphen mit zwei markierten Knoten s und t. Der Short-Spieler versucht, eine 
Verbindung zwischen den markierten Knoten herzustellen indem er Kanten sichert, und der Cut-Spieler versucht, jede 
Verbindung zu unterbinden, indem er Kanten verbietet.  

Das Spiel ist vollständig gelöst: Nach dem Satz von Lehman gewinnt der
Short-Spieler als Nachziehender genau dann, wenn der Graph einen
Teilgraphen enthält, der beide markierten Knoten umfasst und selbst zwei
kantendisjunkte Spannbäume besitzt. Die Strategie hält diese Struktur
über das gesamte Spiel mit den unbelegten Kanten aufrecht. Auf jeden Zug des Cut-Spielers
antwortet der Short-Spieler so, dass die Eigenschaft erhalten bleibt.
Umgesetzt ist das mit dem Kishi-Kajitani-Algorithmus über eine
Union-Find-Struktur.

Neben der Standardvariante enthält das Projekt eine gewichtete Version 
des Spiels.

## Ausführen

```julia
julia --project=.
julia> using Pkg; Pkg.instantiate()
julia> using Shannon_Group_Project
julia> demo_short()       # Beispiellauf, Standardvariante
julia> demo_weighted()    # gewichtete Variante
julia> run_game()         # eigenes Spiel
```

## Struktur

- `strategy.jl` – optimale Strategie für den Short-Spieler
- `union_find.jl` – Union-Find-Datenstruktur
- `game.jl` – Spiellogik, Graph- und Spielzustand
- `gui.jl` – grafische Oberfläche
- `demo.jl` – Beispielläufe

## Mitwirkende

Gemeinschaftsprojekt mit Ben und Ferdi. Meine Hauptaufgabe war die Implementierung der Short-Strategie.
