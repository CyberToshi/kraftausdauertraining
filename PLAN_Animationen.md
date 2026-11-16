# Plan: Die fünf Übungen korrekt darstellen

Stand: November 2026 · Basis: `scripts/gen_animationen.gd`, `scripts/main.gd`, `scenes/main.tscn`

---

## 1. Befund — was auf den Screenshots wirklich zu sehen ist

Die Rückmeldung der KI beschreibt die Bilder richtig, deutet die **Ursache** aber falsch.
Es ist **keine Langhantel** im Nacken. Im Code steht:

```gdscript
# _daten_goblet()
var haende := [Vector3(0.0, -0.16, 0.13), Vector3(0.0, -0.16, 0.13)]  # beide Hände auf x = 0
var griff := Basis()                                                    # Stange waagerecht
```

Beide Hände haben **dasselbe Ziel** (x = 0, also vor dem Brustbein), und beide Hanteln
stehen waagerecht mit ihrer Längsachse in Welt-X. Zwei 35,5-cm-Hanteln auf demselben Punkt
überlagern sich zu **einem 35,5-cm-Balken quer vor der Brust** — genau das, was wie eine
Front-Rack-Stange aussieht. Zusätzlich liegen beide Hände ineinander, die Handflächen zeigen
nach oben: das erzeugt den „Ablege"-Eindruck statt eines Goblet-Griffs.

Damit ist die Korrektur klar umrissen:

| Beobachtung | Ursache im Code | Konsequenz |
|---|---|---|
| „Langhantel vor der Brust" | zwei überlagerte, waagerechte Hanteln | **eine** senkrechte Hantel am Brustbein |
| Hände überlappen | beide `haende_rel` = `(0, −0.16, 0.13)` | Hände links/rechts der Hantel, je 7,5 cm vom Lot |
| Handflächen zeigen nach oben | `hand_welt = Basis()` für beide Seiten | **Handbasen pro Seite** (`hand_welt` als Paar) |
| „Rücken gerundet" (RDL, Rudern) | Kopf folgt dem Rumpf (`Neck = neck + spine`), Rumpf 72–74° | Kopf/Hals gegensteuern, Rumpf 62–68° |
| „Hanteln schwimmen nach vorn" (RDL) | Handziele absolut mit z = +0,20 | Hände **senkrecht unter der Schulter** rechnen |
| „Knie beugen mit" (RDL) | Hüfte 10 cm abgesenkt → Kniebeugung 14° → 49° | Hüfte nur ~2 cm absenken, 22 cm nach hinten |
| „Bankdrücken nicht beurteilbar" | Kamera (0; 1,2; 3,3) rahmt eine liegende Figur nicht | **Kamera je Übung** in `BUEHNE` |
| Rudern: „Hüfte dreht auf, freies Bein zu nah" | beide Füße am Boden, nur eine Hand gestützt | Knie **auf** der Bank, Standbein weiter hinten |

Wichtig: Der Übungstext in `scripts/main.gd` beschreibt den Goblet Squat bereits korrekt
(„Halte eine Kurzhantel mit beiden Händen senkrecht direkt vor deiner Brust"). Nicht der Text
ist falsch, sondern die Animation. Die Texte bleiben unverändert.

---

## 2. Grundregeln (gelten für alle fünf Clips)

Diese Invarianten werden nach jedem Generatorlauf automatisch geprüft (Abschnitt 6):

1. **Füße fest.** Sprunggelenk bleibt bei `y = 0,128` (Bodenkontakt), Ferse hebt nie ab.
2. **Neutraler Rumpf.** Der Knick wird gleichmäßig auf `Spine`/`Spine1`/`Spine2` verteilt
   (Faktoren 0,35 / 0,68 / 1,0). Der Kopf wird zu 60 % gegengeneigt, damit er nicht in den
   Rumpf knickt (das ist die „Rundung im oberen Rücken" auf den Bildern).
3. **Last am Körper.** Hantelmitte höchstens 0,12 m von der Körperlinie (Brustbein bzw.
   Schienbein) entfernt.
4. **Symmetrie.** Becken bei `x = 0`, alle linken/rechten Ziele spiegelbildlich
   (`pol_knie` wird bereits gespiegelt, `pol_arm` und Handziele müssen es auch).
5. **Richtiges Gerät.** Eine Hantel = ein `BoneAttachment3D`. Welche der drei Hanteln sichtbar
   ist, entscheidet die Übung (Abschnitt 3).
6. **Lesbarkeit.** Jede Übung hat eine eigene Kameraposition, damit Knie-, Hüft- und
   Ellbogenwinkel im Präsentationsbild erkennbar sind.

---

## 3. Technische Umbauten

### T1 — Dritte Hantel am Brustbein, Hanteln pro Übung schaltbar
*Dateien: `scenes/main.tscn`, `scripts/main.gd`*

- Neuer `BoneAttachment3D` **`BrustAnker`** an `mixamorig_Spine2`, darunter eine dritte
  Hantel-Instanz `HantelBrust` (Skalierung 0,76, Rotation 90° um Z → Stange senkrecht,
  Position `(0, 0.02, 0.13)` = 13 cm vor dem Brustbein).
- Die drei Hantel-Knoten bekommen `unique_name_in_owner` (`%HantelRechts`, `%HantelLinks`,
  `%HantelBrust`).
- `const BUEHNE` erhält je Übung einen Eintrag `"hanteln"` (siehe Matrix unten);
  `_buehne_setzen()` blendet die drei Hanteln entsprechend ein/aus.

| Übung | `HantelRechts` | `HantelLinks` | `HantelBrust` | Bank |
|---|---|---|---|---|
| Goblet Squats | – | – | **an** | – |
| Bankdrücken | an | an | – | an |
| Einarmiges Rudern | an | – | – | an |
| Schulterdrücken | an | an | – | an |
| Rumän. Kreuzheben | an | an | – | – |

(Nebeneffekt: Beim Rudern verschwindet die sinnlose Hantel in der Stützhand.)

### T2 — Griff-Ausrichtung pro Seite
*Datei: `scripts/gen_animationen.gd`*

`hand_welt` wird vom Einzelwert zum Paar `[links, rechts]`; der Einzelwert bleibt als
Abkürzung gültig (beide Seiten gleich). Nötig, weil beim Goblet Squat die Handflächen
zueinander zeigen: rechts 90° um Z, links 90° um Z **plus** 180° um Y (Daumen oben).

### T3 — Neutraler Rumpf und Kopf
*Datei: `scripts/gen_animationen.gd`, `_pose_anwenden()`*

- Verteilung als Parameter `"spine_teile": [0.35, 0.68, 1.0]` (Standard), damit einzelne
  Übungen den Knick anders verteilen können.
- `Neck` bekommt `neck + spine * 0.4` statt `neck + spine`; `Head` bleibt relativ zur Welt
  neutral. Ergebnis: Der Blick geht bei vorgebeugtem Rumpf nach vorn-unten statt senkrecht
  in den Boden, die obere Rückenlinie wirkt gerade.

### T4 — Handziel „hängen"
*Datei: `scripts/gen_animationen.gd`, `_pose_anwenden()`*

Neuer Modus `"haende_modus": "hang"`: Handziel = Schultergelenk + `(x, −(l1+l2)·0,99, 0)`.
Damit hängen die Hanteln immer senkrecht unter der Schulter und wandern beim Vorbeugen nicht
nach vorn weg (RDL, untere Ruderposition). Der `x`-Anteil kommt weiter aus `haende_rel`.

### T5 — Messwerte im Generator
*Datei: `scripts/gen_animationen.gd`, `_diagnose()`*

Zusätzlich ausgeben: Kniebeugung (Winkel Ober-/Unterschenkel), Rumpfneigung, Kopfneigung
gegen das Lot, Abstand Hantel↔Körperlinie, Ellbogenwinkel je Seite. Das ist die Grundlage
für die Abnahmekriterien — ohne diese Zahlen ist keine der Korrekturen überprüfbar.

### T6 — Kamera je Übung
*Dateien: `scripts/main.gd`, `scenes/main.tscn`*

`BUEHNE` erhält `"kamera_pos"`, `"kamera_rot"`, `"fov"`; die Kamera wird `%Kamera`.
Startwerte:

| Übung | Position | Neigung | Begründung |
|---|---|---|---|
| Goblet Squats | (1,3; 1,15; 2,9) | −6° | 25° seitlich: Knie und Hüfte lesbar |
| Bankdrücken | (1,5; 1,9; 2,4) | −22° | von oben schräg, Bank verdeckt die Ellbogen nicht |
| Rudern | (1,6; 1,35; 2,5) | −10° | Zugseite sichtbar, Stützarm frei |
| Schulterdrücken | (0,6; 1,55; 3,0) | −6° | leicht erhöht, Hände über dem Kopf frei |
| Kreuzheben | (1,5; 1,1; 2,8) | −4° | strenge Seitenansicht für den Hüftknick |

---

## 4. Übungsspezifikationen

Reihenfolge = Priorität. Nach jeder Übung: regenerieren, messen, zwei Bilder prüfen, dann
erst die nächste. Die Zahlen sind Startwerte; die Messausgabe aus T5 entscheidet über
Feinjustage, nicht das Auge allein.

### 4.1 Goblet Squats — Priorität sehr hoch

**Gerät:** eine Kurzhantel, **senkrecht**, eng am Brustbein (`HantelBrust`).

| Element | Ziel |
|---|---|
| Hände (rel. Schulter) | links `(−0.075, −0.14, 0.155)`, rechts `(+0.075, −0.14, 0.155)` |
| Handflächen | zeigen zueinander, Daumen oben (`hand_welt` Paar, T2) |
| Ellbogen | steil nach unten, leicht nach vorn: `pol_arm` = `(∓0.15, −1, 0.30)` |
| Finger | geschlossen um den Griff (`griff_grad` 55°, bereits vorhanden) |
| Füße | `(±0.20, 0.128, −0.03)`, Fersen bleiben am Boden |
| Knie | folgen der Fußlinie: `pol_knie` = `(±0.35, 0, 1)` |
| Hüfte | 0,96 → 0,54 m, `x = 0` in jeder Phase |
| Rumpf | 4° → 26°, gleichmäßig verteilt; Kopf nur 6–10° geneigt |
| Tempo | 3,0 s ab · 0,6 s halten · 1,6 s auf (5,2 s gesamt, bleibt) |

**Abnahme:** Fersen `y = 0,128 ± 0,002` · Knie `x = ±0,24 ± 0,005`, seitliche Auslenkung über
die Bewegung ≤ 0,01 m · Knie `z` bei tiefster Position 0,12–0,17 und nicht mehr als 0,06 m
hinter der Zehenlinie · Hantelmitte ≤ 0,06 m vom Brustbeinpunkt, in **allen** Keys ·
Abstand Hand↔Hantel ≤ 0,05 m · Ellbogenwinkel 100–130° · Becken `x = 0`.

### 4.2 Rumänisches Kreuzheben — Priorität hoch

**Gerät:** zwei Hanteln, neutral hängend (Stange waagerecht in Front-Rück-Richtung).

| Element | Ziel |
|---|---|
| Rumpf | 62–68° statt 72–74°, gleichmäßig verteilt, Kopf 60 % gegengeneigt |
| Hüfte | Startwert `(0, −0.02, −0.22)`: nur 2 cm ab, 22 cm zurück |
| Knie | 12–18° gebeugt und über die Bewegung **konstant** (Differenz ≤ 6°) |
| Hände | `haende_modus = "hang"`, `x = ±0.16` (außen an den Oberschenkeln) |
| Arme | fast gestreckt, Ellbogen 168–175° |
| Hanteln | beide an, Stange quer zur Sagittalebene (`hand_welt` ≈ 90° um Y) |
| Tempo | 2,4 s wie jetzt |

**Warum die Hüfthöhe der kritische Wert ist:** Die Beinlänge (0,403 + 0,375 m) reicht bei
Standhöhe gerade eben aus. Schon 10 cm Absenkung ergeben 49° Kniebeugung statt 14° — das ist
das „Mitbeugen wie bei einer normalen Kreuzhebe". Bei 2 cm Absenkung bleibt die Beugung bei
ca. 16°.

**Abnahme:** Kniebeugung 12–18° in allen Keys · Rumpf 60–70° · Kopfneigung ≤ 25° gegen das
Lot · Abstand Hantelmitte zur Schienbeinlinie ≤ 0,12 m · Fersen `y = 0,128` ·
`hips_rot.y = 0` (keine Beckenverdrehung) · Hantel tiefste Position 0,50–0,55 m.

### 4.3 Einarmiges Rudern — Priorität mittel

**Gerät:** eine Hantel (rechts), linke Hand gestützt.

| Element | Ziel |
|---|---|
| Stützpose | rechtes Knie auf dem Polster (`y = 0,47`), linker Fuß am Boden |
| Standbein | linker Fuß weiter hinten `z = −0.12` (Hüfte dreht nicht auf) |
| Rumpf | 78–82° (fast waagerecht), gleichmäßig verteilt, Kopf neutral |
| Becken | `x = 0`, Yaw und Roll ≤ 2° |
| Ziehen | unten Arm gestreckt (Ellbogen ≥ 160°), oben zur Hüfte: `(±0.16, −0.10, −0.02)` rel. Schulter |
| oben | Unterarm senkrecht unter dem Ellbogen |
| Tempo | 1,6 s ziehen · 0,4 s halten · 1,2 s ablassen (3,2 s) |

**Abnahme:** Ellbogenwinkel unten ≥ 160°, oben ≤ 70° · Rumpf 76–84° · Becken-Yaw ≤ 2° ·
Stützhand bleibt auf dem Polster (`|y − 0,47| ≤ 0,02`) · Hantel unten senkrecht unter der
Schulter (±0,04 m).

### 4.4 Schulterdrücken — Priorität niedrig

**Gerät:** zwei Hanteln, sitzend auf der Bank (Lehne −80°).

| Element | Ziel |
|---|---|
| unten | Hände auf Schulterhöhe: `(±0.19, 0.00, 0.06)` rel. Schulter, Ellbogen 45° nach vorn (`pol_arm` = `(±0.6, −0.6, 0.6)`) |
| oben | `(±0.12, 0.40, 0.06)`, Arme fast gestreckt (Ellbogen 165–175°) |
| Rumpf | 0–4°, Becken −6°, keine Lordose über 10° |
| Tempo | 1,4 s drücken · 0,3 s halten · 1,3 s ablassen (3,0 s, heute 2,2 s) |

**Abnahme:** Ellbogen unten nicht hinter der Schulterlinie (`z ≥ −0.02`) · Ellbogen oben
165–175° · Hanteln oben mindestens 0,10 m Abstand zum Kopf · Becken `x = 0`.

### 4.5 Bankdrücken — Priorität offen (Bild war beschnitten)

**Gerät:** zwei Hanteln, liegend auf der Bank.

| Element | Ziel |
|---|---|
| Lage | Becken 88° gekippt, Rücken auf dem Polster (`y = 0,44 ± 0,02`), Füße am Boden |
| unten | Hanteln 3–5 cm über der Brust: `(±0.14, −0.30, 0.14)` rel. Schulter, Ellbogen 45° |
| oben | Arme fast gestreckt: `(±0.10, 0.16, 0.06)`, Hanteln über den Schultern |
| Kamera | T6 — von oben schräg, sonst ist nichts zu beurteilen |
| Tempo | 1,2 s drücken · 0,3 s halten · 1,5 s ablassen (3,0 s) |

**Abnahme:** Rumpf 86–90° · Rückenkontakt zum Polster ± 0,02 m in allen Keys · Ellbogen
nicht unter die Bankebene · Hanteln oben ± 0,10 m um die Schulterlinie.

---

## 5. Reihenfolge der Arbeit

| Etappe | Inhalt | Ergebnis |
|---|---|---|
| 0 | T5 (Messwerte) + `scripts/tools_check.gd` | Zahlen statt Augenmaß, alte Clips werden messbar |
| 1 | T1, T2, T6 (Geräte, Griffe pro Seite, Kamera) | Grundlage für alle Übungen |
| 2 | 4.1 Goblet Squats | **höchste Priorität**, sichtbarster Fehler |
| 3 | 4.2 RDL | zweitgrößter Fehler (Rücken, Knie) |
| 4 | 4.3 Rudern | Rumpf flacher, Knie auf der Bank, eine Hantel |
| 5 | 4.5 Bankdrücken | nach der neuen Kamera überhaupt erst beurteilbar |
| 6 | 4.4 Schulterdrücken | Feinschliff (untere Position, Tempo) |
| 7 | `README_MotionCapture.md` Abschnitt 5 + Tabelle in Abschnitt 0 aktualisieren | Doku passt zum Code |
| 8 | Projektstart headless, alle fünf Buttons | Abschlussprüfung |

Nach jeder Etappe: Generator laufen lassen, `tools_check` lesen, zwei Bilder (Start- und
Endpose) rendern und ansehen. Erst dann weiter — wie bisher: eine Übung nach der anderen.

---

## 6. Prüfwerkzeuge

**`scripts/tools_check.gd`** (headless) — lädt `anim/uebungen.tres`, tastet jeden Clip bei
0,1-s-Schritten ab und prüft die Abnahmekriterien aus Abschnitt 4. Ausgabe je Übung:
`OK` oder die verletzte Regel mit Ist- und Sollwert. Rückgabewert ≠ 0 bei Fehlern.

**`scripts/tools_shot.gd`** (ohne `--headless`, D3D12) — rendert je Übung drei Bilder
(Start, Mitte, Ende) aus der Kamera aus T6 nach `_shots/<uebung>_<t>.png`. Screenshots
brauchen `await RenderingServer.frame_post_draw`; das Fenster bleibt 1152×648.

**Befehle**

```bash
# Generator (nach jeder Datenänderung)
"…/Godot_v4.7-stable_win64_console.exe" --headless --path . res://scripts/gen_animationen.tscn --quit-after 9000

# Messung
"…/Godot_v4.7-stable_win64_console.exe" --headless --path . res://scripts/tools_check.tscn --quit-after 4000

# Bilder
"…/Godot_v4.7-stable_win64_console.exe" --path . res://scripts/tools_shot.tscn
```

---

## 7. Was bewusst nicht geändert wird

- **Übungstexte** in `const UEBUNGEN` (`scripts/main.gd`) — wörtlich unverändert.
- **Aufbau der Bibliothek** `anim/uebungen.tres`: weiter 51 Tracks je Clip (20 Körperknochen,
  30 Fingerglieder, Hüftposition).
- **Skalierung der Hanteln** (0,76 = 35,5 cm) und der `BoneAttachment3D`-Ansatz.
- **Bank-Geometrie** (`scenes/hantelbank.tscn`); nur Position/Winkel über `BUEHNE`.

## 8. Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| Hände liegen beim Goblet Squat nicht exakt am Griff | Handziel relativ zur Hantelmitte rechnen und in `_diagnose` den Abstand ausgeben |
| Knie-auf-Bank-Pose (Rudern) über IK nicht erreichbar | Rückfallebene: beide Füße am Boden, nur Hand gestützt (Rumpf dann 70–75°) |
| Kamerawechsel wirkt im Loop ruckartig | Kamera nur beim Übungswechsel setzen, nicht während der Animation |
| Zu viele Änderungen gleichzeitig | strikt eine Übung pro Etappe, Prüfwerte vor dem Weitergehen |


---

## 9. Erkenntnisse aus Etappe 0 (erster Messlauf)

Gemessen mit `scripts/tools_check.gd` an den bestehenden Clips:

1. **`rumpf` reagiert nur schwach auf `spine`.** Der Messwert ist die Linie Hüfte → `Spine2`,
   und der größte Teil dieser Strecke liegt im kurzen Abschnitt Hüfte → `Spine`. `spine: 26`
   ergibt deshalb gemessene 4,8° Neigung — der Oberkörper bleibt im Bild aufrecht.
   Für echte Rumpfneigung muss zusätzlich `hips_rot` gedreht werden (Etappe 2 und 3).
2. **Vier Keys pro Wiederholung sind zu wenig.** Zwischen den Keys sinkt der Fuß bis auf
   0,085 m (Soll 0,128) ab: Die IK-Lösung interpoliert nicht geradlinig, die Füße wandern
   also im Bild durch den Boden. Ab Etappe 2 Keys im 0,5-s-Raster setzen (0,25 s an den
   Wendepunkten), statt nur 5–6 Keys je Clip.
3. **Die Arme sind nicht spiegelsymmetrisch.** Goblet Squat: Ellbogen links 133°, rechts 47°,
   obwohl die Handziele gespiegelt sind — `pol_arm` je Seite in Etappe 2 prüfen.
4. **Hantelachsen (bestätigt):** Lange Achse = lokale X der Hantel (0,467 m unskaliert).
   Die Brusthantel steht mit `rotation_degrees = (5.6, -5.7, 89.4)` senkrecht; Kontrolle über
   die Weltachse ergab (0, 1, 0).
5. **Der Kopf folgt dem Rumpf zu stark** (`kopf` = 42° im tiefen Goblet-Squat): Bestätigt die
   „Rundung im oberen Rücken" aus dem Feedback und wird über T3 (Gegenneigung) behoben.

Der Messlauf endet mit 24 verletzten Regeln — das ist der Ausgangsstand vor Etappe 2.

---

## 10. Umsetzung aller fünf Übungen (Stand nach dieser Runde)

Alle fünf Clips sind neu erzeugt; `tools_check` endet mit **0 verletzten Regeln**.

### Gefundene Ursachen (das waren die eigentlichen Fehler)

1. **Die IK rechnete mit falschen Reichweiten.** `laengen` und `_setze_richtung` nahmen den
   *ersten* Kindknochen — bei Mixamo sind das Twist-Knochen. Dadurch erreichten Arme und Beine
   ihre Ziele nie ganz: Füße schwebten bis 5 cm, Hände blieben bis 4 cm neben dem Griff.
   Jetzt werden die Kettenknochen (Arm→ForeArm, ForeArm→Hand, UpLeg→Leg, Leg→Foot) explizit
   gesetzt, plus eine Nachiteration, die Knöchel und Handgelenk exakt auf das Ziel zieht.
2. **Ein Handziel war nur eine Position.** Erst mit Griffrichtung (Fingerrichtung + Handflächen-
   normale, im Handraum: Y = Finger, Z = Handfläche, X = Hantelachse) sitzt die Hantel richtig
   in der Hand. Das behebt die „verdrehten Handflächen" beim Schulterdrücken und die schiefen
   Hanteln beim Bankdrücken.
3. **Rumpfneigung über die Wirbel erzeugt einen Buckel.** Jetzt kommt die Neigung aus dem
   Hüftknick (`hips_rot`), die Wirbel verteilen nur den Rest; `kopf` hält den Kopf neutral zum
   Brustkorb. RDL: Rücken bleibt eine gerade Linie, Bewegung ausschließlich aus der Hüfte.
4. **Zu wenige Keys.** Keys im 0,2–0,4-s-Raster (`_raster()` interpoliert die Anker), sonst
   sinken Füße und Hände zwischen zwei Keys durch Boden und Gerät.

### Was je Übung jetzt gilt

| Übung | Griff | Kern der Bewegung |
|---|---|---|
| Goblet Squats | eine senkrechte Hantel am Brustbein (7,5 cm tiefer als zuvor): rechte Hand **oben** auf dem oberen Kopf, linke Hand **von unten** am unteren Kopf | Rumpf 24°, Hüfte auf 0,54 m, Knie folgen der Fußlinie |
| Bankdrücken | Hanteln quer in der Hand, Handflächen zu den Füßen | Ellbogen seitlich/zu den Füßen (nicht über den Kopf), 23° oben / 127° unten |
| Einarmiges Rudern | Stützhand flach auf dem Polster, Zughand neutral | Knie auf dem Polster (0,48 m), Standbein hinten, Rumpf 79° |
| Schulterdrücken | Handflächen nach vorn, Hände schulterbreit | oben 22° Ellbogen, kein Hohlkreuz |
| Rumänisches Kreuzheben | hängender Neutralgriff, Stange quer | reiner Hüftknick (72°), Knie 6–30° **konstant**, Hanteln an der Schienbeinlinie |

Ablauf: `gen_animationen` erzeugen, `tools_check` prüfen, `tools_shot` rendert je Übung vier
Bilder nach `_shots/`. Die Regeltabelle in `tools_check.gd` ist die Abnahme.

---

## 11. Nachbesserungen nach der Sichtprüfung

| Beobachtung | Ursache | Änderung |
|---|---|---|
| Rudern: Unterschenkel steckt in der Bank | Knie lag mitten auf dem Polster, der Unterschenkel ging senkrecht durch das Brett | Bank 11 cm nach vorn (`bank_pos` z 0,375); das Knie kniet jetzt am hinteren Ende, der Unterschenkel hängt dahinter, der Fuß steht flach auf dem Boden (`fuesse[0]` y 0,13) |
| Rudern: Bein wirkte fast gestreckt | Hüfte→Knöchel war 0,77 m bei 0,78 m Beinlänge, die IK klemmte | Knöchelziel näher an die Hüfte (0,64 m) → Kniebeugung ≈ 30–40° |
| Goblet: Unterarm ging in den Rumpf | Ellbogen-Pol zeigte fast senkrecht nach unten | Pol nach außen/oben gedreht (0,9 / −0,9 in x), Ellbogen steht jetzt neben dem Körper |
| Goblet + Kreuzheben: Fersenstand, Zehen in der Luft | Fußrichtung war fest auf (0,−0,3,1) verdrahtet – flacher als die Ruhelage | Ohne eigene Angabe übernimmt der Fuß die **Ruherichtung** (Sprunggelenk → Zeh); neue Prüfregel „Sohle liegt flach" (Zehenhöhe ≤ 5,5 cm) |

### Bühne

- Boden: 5,6 × 5,6 m Bühne (BoxMesh) plus dunkle Trainingsfläche. Wände, Leuchtstreifen
  und Podest wurden wieder entfernt: die linke Wand stand quer im Raum (Box um 90° gedreht,
  dadurch lag ihre Fläche mitten in der Figur), und die Kulisse verdeckte die Übung mehr,
  als sie half. Offene Bühne vor Himmelsverlauf.
- Licht: Sonne (Schatten, weich), Kantenlicht von hinten, Spotscheinwerfer senkrecht
  über der Figur, Fülllicht von links vorn; Himmel/Umgebungslicht angehoben.
- Die Tafel lässt sich über den Schalter **„Tafel ausblenden"** in der oberen Leiste
  einklappen, damit die Figur unverdeckt zu sehen ist.

Damit: `tools_check` 41 Regeln, 0 verletzt.
