# GIF → 3D-Animation → Godot 4

Kompletter Workflow für die fünf Hantelübungen deiner Präsentation **„Kraftausdauertraining"**
plus die bereits gebaute Godot-Szene (`scenes/main.tscn`, `scripts/main.gd`).

---

## 0. Was im Projekt schon liegt

| Datei | Inhalt | Hinweis |
|---|---|---|
| `Ch42_nonPBR.fbx` | Charakter, Mixamo-Rig, **65 Bones** (`mixamorig_Hips` …), T-Pose, Größe ≈ 1,80 m | `AnimationPlayer` bekommt beim Start die fünf Übungsanimationen aus `anim/uebungen.tres` (Bibliothek `uebungen`); die Import-Clips `Take 001`/`mixamo_com` bleiben unberührt |
| `Dumbbell by CreativeTrio - PW9q10xh5g.glb` | Kurzhantel | Modell ist winzig (4,7 mm) – in der Szene auf **75×** skaliert |
| `scenes/main.tscn` | 3D-Bühne + HUD-Overlay | startet über F5 (`run/main_scene` gesetzt) |
| `scripts/main.gd` | Steuerskript mit allen Texten | Übungsdaten als `const UEBUNGEN` |
| `anim/uebungen.tres` | Die fünf Übungsanimationen als `AnimationLibrary` | erzeugt von `scripts/gen_animationen.gd`, wird beim Start automatisch geladen |
| `scenes/hantelbank.tscn` | Hantelbank (Polster 44 cm, Lehne 0–80° verstellbar) | wird je Übung ein-/ausgeblendet und ausgerichtet |
| `scripts/gen_animationen.gd` | Generator für die fünf Clips | headless ausführbar, siehe Abschnitt 5 |

**Namenskonvention der fünf Animationen** (genau so im AnimationPlayer anlegen):

| Übung | Animationsname | Button-Text |
|---|---|---|
| Goblet Squats | `GobletSquat` | Goblet Squats |
| Kurzhantel-Bankdrücken | `Bankdruecken` | Bankdrücken |
| Einarmiges Kurzhantel-Rudern | `EinarmigesRudern` | Einarmiges Rudern |
| Schulterdrücken | `Schulterdruecken` | Schulterdrücken |
| Rumänisches Kreuzheben | `Kreuzheben` | Rumän. Kreuzheben |

Das Skript sucht Namen tolerant (Groß-/Kleinschreibung, `:`/`_`, Bibliotheks-Präfixe wie
`uebungen/GobletSquat` sind egal). Fehlt eine Animation, bleibt die Präsentation bedienbar und
die Statuszeile im Hinweisfenster sagt dir, was fehlt.

---

## 1. Von GIF zu Motion Capture

### 1.1 Tool-Auswahl (kostenlos / browserbasiert, Stand November 2026)

| Tool | Free-Kontingent | Export | Bewertung für dieses Projekt |
|---|---|---|---|
| **Rokoko Vision 3.0** (läuft in „Rokoko Create" im Browser) | 30 s Video pro Monat | FBX, Skeleton-Presets für **Mixamo**, HumanIK, Unreal Manny | **Erste Wahl**: Das Mixamo-Preset erzeugt exakt die Knochennamen deines Ch42-Rigs → Übertragung ohne Umbenennen |
| **Plask** (plask.ai) | 15 s pro Tag | FBX, GLB, BVH | Zweitmeinung mit Tageskontingent, gut für kurze Einzelwiederholungen |
| **DeepMotion Animate 3D** | 25–60 s pro Monat, **nur nicht-kommerziell** | FBX, GLB, BVH | Kann dein eigenes GLB/FBX direkt im Browser retargeten; Lizenz beachten |
| **Move One** (ex Move.ai) | ca. 30 s einmalig | FBX | Sehr saubere Qualität, Kontingent reicht für einen Test |
| **QuickMagic** | 50 s monatlich | FBX | Günstiger Fallback |
| **FreeMoCap** (Open Source, lokal) | unbegrenzt | `.blend`, CSV | Mehrkamera + Markerboard, viel Setup, aber gratis und offline |
| **Blender** (kostenlos) | – | FBX/GLB | Retarget- und Aufräum-Zentrale (siehe Abschnitt 2) |

**Kurzfassung:** Rokoko Vision mit **Mixamo-Skeleton-Preset** exportieren, in Blender oder direkt
in Godot auf das Ch42-Skelett übertragen, als GLB exportieren, importieren, Namen anpassen – fertig.

> **Wichtig:** Kein Tool trackt die Hantel als Objekt. Filme die Bewegung **mit leeren Händen** –
> sonst versucht das Tracking, Hantel und Hand als ein Gelenk zu verstehen, und die Arme zittern.
> Die Hantel ist in Godot ein reines Prop (Szene: `Welt/Hantel`) bzw. später per `BoneAttachment3D`
> an die Hand gehängt.

### 1.2 Worauf du bei den GIFs achten musst

- **Kamerawinkel:** möglichst 90° zur Bewegungsebene, Kamera auf Hüfthöhe.
  - Goblet Squats, Rumänisches Kreuzheben: **strenge Seitenansicht** (Knie-/Hüftwinkel sind sonst nicht lesbar).
  - Schulterdrücken: **schräg von vorn, leicht erhöht (10–20°)**, damit die Hände den Kopf nicht verdecken.
  - Bankdrücken: **45° von oben** – bei einer Bank verdecken Bank und Körper die Ellbogen, deshalb ist Boden-Drücken deutlich besser trackbar (steht so auch in der Übungsbeschreibung).
  - Einarmiges Rudern: **45° von vorn/seitlich**, damit beide Arme getrennt bleiben.
- **Ganzkörper im Bild:** Kopf, Hände und **beide Füße** komplett, 1–2 Handbreit Rand.
- **Eine vollständige Wiederholung** (2–4 s), ruhige Kamera, kein Zoom, kein Schnitt, kein Texteinblender.
- **Bildrate und Auflösung:** GIFs laufen oft mit 10–15 fps. Vor dem Upload auf **25–30 fps**
  und mindestens **720 px Breite** konvertieren (z. B. mit ezgif.com: GIF → MP4, H.264) –
  sonst ruckelt die Pose-Schätzung.
- **Sichtbarkeit der Gelenke:** engere Kleidung, keine weiten Shirts, kontrastreicher Hintergrund,
  gleichmäßiges Licht, keine Schlagschatten auf Knie/Ellbogen, keine Spiegelungen.
- **Nur eine Person** im Bild, keine weiteren Personen/Hanteln im Hintergrund.
- **Loop-fähig:** Start- und Endpose identisch (erste Wiederholung aus einem ruhigen Stand heraus beginnen).

### 1.3 Anatomische Fallstricke pro Übung (Tracking-Qualität)

| Übung | Typisches Problem | Gegenmaßnahme |
|---|---|---|
| Goblet Squats | Arme vor der Brust verdecken den Rumpf; tiefe Hocke verdeckt Knie | Kamera 30–45° seitlich, Arme nicht über die Knie hinaus; Kontrolle: Knie bleiben über den Füßen |
| Bankdrücken | Bank verdeckt Schultern/Hüfte | Auf dem Boden drücken oder Kamera erhöht; Ellbogen sichtbar im 45°-Winkel halten |
| Einarmiges Rudern | abstützender Arm verschwindet hinter dem Körper | Kamera 45° von der Zugseite, Arme nicht kreuzen |
| Schulterdrücken | Hände über dem Kopf überlappen | Kamera leicht erhöht, Arme schulterbreit führen, nicht ins Hohlkreuz gehen |
| Rumänisches Kreuzheben | Hanteln/Unterarme überlappen die Oberschenkel | strenge Seitenansicht, Hanteln (leere Hände) knapp vor den Beinen führen |

### 1.4 Ablauf Schritt für Schritt

1. **GIF auswählen** (Kriterien aus 1.2) oder – besser – die Übung selbst mit dem Handy filmen
   (30 fps, 1080p, gleiche Kamera-Regeln). Ein eigenes Video ist fast immer sauberer als ein fremdes GIF.
2. **Konvertieren** (nur bei GIF nötig): ezgif.com → „GIF to MP4" → 30 fps, Breite 720–1080.
3. **Tracking:** Datei bei Rokoko Create hochladen (oder Plask / DeepMotion) → **ein Clip pro Übung**,
   jeweils genau eine Wiederholung → Verarbeitung starten.
4. **Export:** FBX (Rokoko) bzw. FBX/GLB (Plask, DeepMotion), **Skeleton-Preset = Mixamo**,
   30 fps, „bake animation" aktiv. Clip-Namen aus der Tabelle in Abschnitt 0 vergeben.
5. **Prüfen** im Godot-Import oder in Blender: Füße nicht durch den Boden, Hände nicht verdreht,
   keine Sprünge am Loop-Übergang.
6. **Retargeten** (Abschnitt 2) und als **eine** GLB-Datei mit Charakter + 5 Clips exportieren –
   dann landen alle Animationen direkt im `AnimationPlayer` der Szene.

---

## 2. Retargeting auf das Ch42-Skelett

### 2.1 Warum das hier einfach ist

Ch42 ist ein Mixamo-Charakter: die Knochen heißen `mixamorig:Hips`, `mixamorig:Spine`, `mixamorig:LeftArm` …
(Godot zeigt sie als `mixamorig_Hips` an, weil `:` beim Import ersetzt wird – das passiert bei
Animationen genauso, die Pfade bleiben also konsistent).

**Weg A – ohne Blender (empfohlen, wenn der Mocap-Export Mixamo-Knochennamen hat):**

1. Mocap-GLB/FBX in Godot importieren (Doppelklick im FileSystem → Szene als Tab öffnen).
2. Im importierten Szenenbaum den `AnimationPlayer` auswählen, im Animations-Editor die gewünschte
   Animation öffnen, alle Tracks markieren und **Animation → Copy Tracks**.
3. In `Ch42_nonPBR` (bzw. in `scenes/main.tscn` → `Welt/Charakter/AnimationPlayer`) eine neue
   Animation anlegen, **Animation → Paste Tracks**, Namen aus der Tabelle setzen.
4. **Animation → Manage Animations** → Bibliothek `uebungen` anlegen und die fünf Animationen
   hineinziehen (optional, das Skript findet beide Varianten).
5. Loop Mode der Animation auf **Linear** stellen (macht das Skript zur Laufzeit zusätzlich selbst).

Das funktioniert, weil die Track-Pfade beider Rigs identisch sind (`Skeleton3D:mixamorig_Hips` usw.)
und beide in Mixamo-T-Pose stehen. **Voraussetzung:** Der Mocap-Export nutzt wirklich die
Mixamo-Knochennamen und dieselbe Ruhepose (T-Pose, Arme waagerecht).

**Weg B – mit Blender (wenn Knochennamen oder Ruhepose abweichen):**

1. Blender (kostenlos) öffnen, beide FBX/GLB importieren:
   `Ch42_nonPBR.fbx` und den Mocap-Clip. Beide Armaturen bleiben in **T-Pose** (Rest-Pose nicht verändern!).
2. Bone-Namen des Mocap-Rigs prüfen (Outliner aufklappen). Fehlt das `mixamorig`-Präfix,
   per Batch Rename ergänzen: `Hips` → `mixamorig:Hips` usw.
3. Auf der Ch42-Armatur pro Knochen einen **Copy Rotation**-Constraint zum passenden Mocap-Knochen
   legen (Space: World Space, Influence 1.0). Minimal-Mapping für alle fünf Übungen:

   | Körperteil | Ch42-Knochen | typischer Mocap-Name |
   |---|---|---|
   | Becken | `mixamorig:Hips` | Hips / Pelvis |
   | Rumpf | `mixamorig:Spine`, `Spine1`, `Spine2` | Spine / Chest / UpperChest |
   | Hals/Kopf | `mixamorig:Neck`, `Head` | Neck / Head |
   | Schultern | `mixamorig:LeftShoulder`, `RightShoulder` | LeftShoulder / Clavicle |
   | Oberarm | `mixamorig:LeftArm`, `RightArm` | LeftArm / UpperArm |
   | Unterarm/Hand | `mixamorig:LeftForeArm`, `RightForeArm`, `LeftHand`, `RightHand` | LowerArm / Hand |
   | Beine | `mixamorig:LeftUpLeg`, `LeftLeg`, `LeftFoot`, `LeftToeBase` (rechts analog) | UpperLeg / LowerLeg / Foot / Toe |

4. Constraint-Ziel prüfen: Beine nach vorn, Arme seitlich – nichts verdreht.
5. Pose-Modus → alle Knochen markieren → **Pose → Animation → Bake Action** („Visual Keying",
   „Clear Constraints", Frames = Clip-Länge, 30 fps).
6. Mocap-Armatur löschen, Aktion exakt benennen (`GobletSquat` usw.).
7. Export: **File → Export → glTF 2.0 (.glb)**, Animation-Modus **„Actions"**,
   nur Mesh + Armatur auswählen, „+Y up", Frames 0…N-1.

### 2.2 Aufräumen (5 Minuten, spart viel Ärger)

- **In-Place:** Hüft-Translation in X/Z auf 0 ziehen (sonst wandert der Charakter aus dem Bild).
  Höhe (Y) behalten, sonst schwebt er bei Squats/RDL.
- **Loop:** ersten und letzten Keyframe angleichen; Länge = exakt eine Wiederholung (kein Standbild am Ende).
- **Foot sliding:** prüfen, ob die Füße bei Squats/RDL am Boden bleiben; sonst Clip kürzen.
- **Hände:** Rokoko-Free liefert kein Fingertracking – Hände bleiben in Ruhepose. Für einen
  Griff um die Hantel reicht eine statische Handpose im Clip.
- **Bodenkontakt:** Füße bei y ≈ 0, Modell bleibt 1,80 m hoch (nicht skalieren).

---

## 3. Import in Godot 4 und Einbau in die Szene

1. GLB/FBX in den Projektordner legen (z. B. `res://anim/`), Godot importiert automatisch.
2. Datei im FileSystem anklicken → **Import**-Dock:
   - `animation/import` = **an**, `animation/fps` = **30**, `animation/trimming` = **aus**
     (sonst schneidet Godot die erste/letzte Pose weg), `remove_immutable_tracks` = an.
3. **Animationen in den Charakter-Player bringen:** entweder Weg A aus 2.1 (Copy/Paste Tracks)
   oder – wenn die Clips in derselben Datei wie der Charakter liegen – den Charakter direkt
   als Szene instanziieren; der `AnimationPlayer` enthält dann alle Clips.
4. Namen exakt wie in der Tabelle in Abschnitt 0 (Groß-/Kleinschreibung ist tolerant, Tippfehler nicht).
5. Pro Animation: **Loop Mode = Linear**, sinnvolle Länge, **Reset-Track** (Godot: „Add Reset Animation")
   damit beim Wechsel keine Pose hängen bleibt.
6. Szene starten (F5). Klick auf einen Button → Animation läuft im Loop + Hinweisfenster zeigt
   Name, Muskelgruppen und Ausführung. Die Statuszeile unten im Fenster nennt die laufende Animation.

**Wenn eine Animation fehlt**, zeigt die Statuszeile z. B.:
`Hinweis: Animation „GobletSquat“ fehlt noch – importiere sie wie im README beschrieben (Abschnitt 3).`
und im Ausgabefenster steht, welche Animationen tatsächlich vorhanden sind.

---

## 4. Die gebaute Szene

```
Kraftausdauertraining (Node3D)            <- scripts/main.gd
├── Welt (Node3D)
│   ├── WorldEnvironment                  <- Himmel + Ambient
│   ├── Sonnenlicht (DirectionalLight3D)
│   ├── Kamera (Camera3D)                 <- (0, 1.2, 3.3), -8° Blickneigung
│   ├── Boden (MeshInstance3D, PlaneMesh)
│   ├── Charakter                         <- Instanz Ch42_nonPBR.fbx
│   │   ├── Skeleton3D (65 Bones)         <- Mixamo-Rig
│   │   │   ├── HandAnker                 <- BoneAttachment3D, Bone mixamorig_RightHand
│   │   │   │   └── Hantel                <- Instanz Dumbbell.glb, 0,76× (35,5 cm)
│   │   │   └── HandAnkerLinks            <- BoneAttachment3D, Bone mixamorig_LeftHand
│   │   │       └── Hantel                <- zweite Hantel für die linke Hand
│   │   └── AnimationPlayer               <- 5 Übungsanimationen (Bibliothek "uebungen")
│   └── Hantelbank                        <- Instanz scenes/hantelbank.tscn
└── HUD (CanvasLayer)                     <- Overlay über der 3D-Szene
    └── Overlay (Control, bildschirmfüllend, klickdurchlässig)
        └── Rand (MarginContainer, 28/24 px)
            └── Spalte (VBoxContainer)
                ├── Leiste (PanelContainer)  ->  Innen (MarginContainer)
                │                               └── ButtonLeiste (HBoxContainer)  %ButtonLeiste
                │                                   ├── BtnGobletSquat        metadata/uebung="goblet_squat"
                │                                   ├── BtnBankdruecken       metadata/uebung="bankdruecken"
                │                                   ├── BtnRudern             metadata/uebung="rudern"
                │                                   ├── BtnSchulterdruecken   metadata/uebung="schulterdruecken"
                │                                   └── BtnKreuzheben         metadata/uebung="kreuzheben"
                ├── Abstand (Control)              <- schiebt das Hinweisfenster nach unten
                └── Unten (HBoxContainer)
                    ├── HinweisPanel (PanelContainer)       %HinweisPanel
                    │   └── Innen (MarginContainer)
                    │       └── Inhalt (VBoxContainer)
                    │           ├── HinweisTitel (Label)         %HinweisTitel
                    │           ├── HinweisUntertitel (Label)     %HinweisUntertitel
                    │           ├── Trennlinie (HSeparator)
                    │           ├── HinweisText (RichTextLabel, BBCode)  %HinweisText
                    │           └── Status (Label)                %Status
                    └── Rechts (Control)               <- Füllraum
```

**Wichtige Details**

- Die Buttons sind **Toggle-Buttons in einer `ButtonGroup`** – der aktive Button bleibt sichtbar gedrückt.
- Der Übungs-Schlüssel liegt als **`metadata/uebung`** am Button. Das Skript verbindet die Buttons
  in `_ready()` per Schleife – Reihenfolge im HBox ist also beliebig, neue Buttons brauchen nur
  ein Meta-Feld und einen Eintrag in `UEBUNGEN`.
- `%ButtonLeiste`, `%HinweisTitel` … sind „Unique Names" (`unique_name_in_owner`), damit das Skript
  keine langen NodePaths braucht.
- Der `AnimationPlayer` wird **automatisch** gesucht (auch innerhalb der Charakter-Instanz). Im
  Inspector kann er zusätzlich fest verdrahtet werden (`Animation` → `Animation Player`).
- `animation_loop = true` erzwingt den Loop zur Laufzeit; `blend_zeit = 0.25` blendet beim Umschalten.

**Texte ändern:** alle Inhalte stehen oben in `scripts/main.gd` im `const UEBUNGEN`
(`titel`, `untertitel`, `muskeln`, `ausfuehrung`, `animation`).

---

## 5. Die fünf Animationen (bereits im Projekt)

Die Clips sind **nicht** von Hand gekeyframed, sondern aus Gelenkzielen berechnet:
`scripts/gen_animationen.gd` baut je Übung Keyframes, löst Beine und Arme per
2-Knochen-IK auf feste Zielpunkte (Füße am Boden, Hände am Griff) und schreibt
Rotations-Tracks (plus Hüftposition) in `anim/uebungen.tres`.

| Clip | Dauer | Besonderheit |
|---|---|---|
| `GobletSquat` | 5,20 s | eine Hantel je Hand; 3 s absenken, 0,6 s halten, 1,6 s aufrichten; Hüfte 0,96 → 0,54 m, Fersen bleiben am Boden |
| `Bankdruecken` | 2,40 s | Becken 88° gekippt, Körper liegt auf der Bank, Füße auf dem Boden |
| `EinarmigesRudern` | 2,20 s | Rumpf 80° vorgeneigt, linke Hand auf der Bank, rechte zieht zur Hüfte |
| `Schulterdruecken` | 2,20 s | sitzend, Hände von Schulterhöhe bis 0,44 m darüber |
| `Kreuzheben` | 2,40 s | Hüfte schiebt zurück, Rumpf 72–74°, Hantel gleitet am Bein |

Neu erzeugen (nach Änderungen an den Zielpunkten in `_daten_*`):

```bash
Godot --headless --path <Projektordner> res://scripts/gen_animationen.tscn
```

Der Generator gibt je Keyframe Hüft-, Knie-, Fuß- und Handpositionen aus – die
Füße müssen immer bei y ≈ 0,13 liegen, dann stimmt die Pose.

**Bank und Hantel**

- **Zwei Hanteln**, je eine an einem `BoneAttachment3D`:
  `HandAnker` (Bone `mixamorig_RightHand`) und `HandAnkerLinks`
  (Bone `mixamorig_LeftHand`). Beide folgen der jeweiligen Hand in jeder Übung.
- Das Modell ist nativ 46,7 cm lang – Skalierung **0,76** ergibt reale 35,5 cm.
  Position `(0, -0.015, 0.03)` legt den Schwerpunkt in die Handmitte.
- Die Griff-Achse ist die X-Achse des Handknochens. Über `hand_welt` in den
  Übungsdaten (`scripts/gen_animationen.gd`) lässt sich das Handgelenk vorgeben,
  z. B. `Basis()` = Stange waagerecht, Finger nach oben.
- `griff_grad` schließt die Finger um den Griff (55° Grundgelenk, nach außen
  abnehmend, Daumen schwächer). Die Krummachse wird in `_finger_vorbereiten()`
  einmal aus der Ruhepose berechnet (Fingerrichtung × Handflächennormale) und
  auf alle 30 Fingerglieder angewendet.
- Die Bank wird über `const BUEHNE` in `scripts/main.gd` je Übung ein-/ausgeblendet
  und ausgerichtet (`bank_pos`, `bank_rot_y`, `lehne`). Die Lehne steht beim
  Schulterdrücken auf −80° (10° zurückgelehnt), beim Bankdrücken und Rudern flach.

---

## 6. Fehlersuche

| Symptom | Ursache / Lösung |
|---|---|
| „Animation … fehlt noch" in der Statuszeile | Clip nicht im `AnimationPlayer` oder anderer Name → Namen aus Abschnitt 0 verwenden; im Ausgabefenster steht die Liste der vorhandenen Clips |
| Charakter riesig/winzig | Import-Skalierung des FBX prüfen (`nodes/root_scale`), Modell muss ≈ 1,8 m hoch sein |
| Arme/Hände verdreht | Ruhepose ≠ T-Pose oder A-Pose-Rig ohne Umrechnung → Weg B (Blender, Copy Rotation + Bake) |
| Füße schweben / sinken ein | Hüft-Höhe (Y) im Clip verstellt oder Bodenkontakt fehlt → Clip nachbearbeiten |
| Ruckeln im Loop | GIF mit 10–15 fps oder Start-/Endpose verschieden → 30 fps neu tracken, Keyframes angleichen |
| Animation läuft einmal und stoppt | `animation_loop` im Inspector aus, oder Loop Mode der Animation überschrieben → Skript setzt ihn bei `animation_loop = true` selbst |
| Alles bleibt in Ruhepose | Mocap-Clip enthält keine Tracks (leerer Export) → Clip in Blender prüfen: Aktion vorhanden, `tracks > 0` |
| UI-Text abgeschnitten | Hinweisfenster ist 486 px breit; im Inspector `HinweisPanel → Custom Minimum Size` erhöhen |

---

## 7. Sinnvolle nächste Schritte

- Hantel per `BoneAttachment3D` an `mixamorig:RightHand` hängen (statt als Bodenprop).
- Kamera-Orbit (Maus) für Präsentationen.
- Tastatur-Shortcuts 1–5 für die Buttons (Vortrag ohne Maus).
- `AnimationPlayer.queue()` für flüssige Übergänge zwischen zwei Übungen.
