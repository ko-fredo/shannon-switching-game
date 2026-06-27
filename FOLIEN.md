# Stichpunkte für die Vorstellung

Foliengerechte Stichpunkte zu den beiden Strategien des Shannon-Switching-Projekts.

---

## Folie 1 — Spiel & Begriffe (Auffrischung)
- Graph mit Quelle **s** und Ziel **t**, Kanten: `neutral` / `short` / `cut`
- **Short** (beginnt) sichert Kanten → will s–t verbinden
- **Cut** entfernt Kanten → will jede Verbindung zerstören
- Short gewinnt: seine Kanten bilden einen s–t-Weg
- Cut gewinnt: kein s–t-Weg mehr möglich (auch nicht über neutrale Kanten)

---

## Folie 2 — Optimale Short-Strategie: die Idee
- **Satz von Lehman:** Short kann sicher gewinnen ⟺ es gibt zwei **kantendisjunkte Spannbäume** (auf einer Knotenmenge mit s und t)
- Anschaulich: **zwei voneinander unabhängige Reserve-Verbindungen**
- Egal welche Kante Cut zerstört → Short repariert mit der jeweils anderen
- Solange Short diese „doppelte Absicherung" halten kann, ist der Sieg garantiert

---

## Folie 3 — Optimale Short-Strategie: der Algorithmus
Pro Zug, in dieser Reihenfolge:
1. **Sofortgewinn?** Vollendet eine Kante direkt einen s–t-Weg aus Short-Kanten → nimm sie
2. **Gewinnstellung halten:** probiere jede freie Kante durch — bleibt Short danach noch in einer Lehman-Gewinnstellung? → nimm die erste solche Kante
3. **Notnagel** (nur falls schon verloren): irgendeine neutrale Kante auf einem s–t-Weg

> Kern: Prüfung „zwei kantendisjunkte Spannbäume?" via **Matroid-Union** (Bäume schrittweise aufbauen, bei Konflikt eine Tausch-Kette suchen)

---

## Folie 4 — Short-Strategie: Korrektheit & Laufzeit
- **Optimal**, weil Schritt 2 immer eine Gewinnstellung erhält, solange eine existiert
- Polynomielle Laufzeit (kein Durchprobieren aller Spielverläufe!)
- Grobe Abschätzung pro Zug: O(E · V · E) durch den Spannbaum-Pack-Test je Kandidatenkante
- Demo: `demo_short()` — Short gewinnt auch gegen zufälliges Cut **immer**

---

## Folie 5 — Gewichtetes Spiel: die Heuristik (eine Idee für beide!)
- Neu: Short will sein s–t-**Weggewicht minimieren**, Cut **maximieren**
- Beide Spieler betrachten **dieselbe Zahl:** Kosten des aktuell **günstigsten s–t-Wegs**
  (gesicherte Short-Kanten kosten 0, entfernte Kanten sind unbenutzbar → Dijkstra)
- **Short** sichert die **Engpass-Kante** dieses Wegs: die, deren Verlust ihn am stärksten verteuern würde → billigen Weg „einfrieren"
- **Cut** entfernt genau diese Engpass-Kante → Short auf teuren Umweg zwingen
- Symmetrisch, intuitiv, leicht zu erklären (bewusst *nicht* maximal optimiert)

---

## Folie 6 — Gewichtete Heuristik: so wird gewählt
- Berechne günstigsten Weg → Basiskosten
- Für jede neutrale Kante auf dem Weg: „Was passiert, wenn sie wegfällt?" → neue Kosten
- **Schaden = neue Kosten − Basiskosten**, wähle die Kante mit größtem Schaden
- Short: sichert diese Kante · Cut: entfernt diese Kante
- (Short zusätzlich: kann ein Zug die Verbindung direkt fertigstellen → tun, sichert Punkte)
- Demo: `demo_weighted()` — zeigt Züge + Endgewicht (= Shorts Punktzahl, kleiner = besser)
