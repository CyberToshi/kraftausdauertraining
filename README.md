# Kraftausdauertraining – interaktive 3D-Präsentation

Fünf Kraftausdauer-Übungen als Godot-4.7-Projekt: eine 3D-Figur führt die Übung
vor, daneben stehen Muskelgruppen und Ausführungshinweise.

**Live-Demo:** https://cybertoshi.github.io/kraftausdauertraining/

## Übungen

| Button | Übung |
| --- | --- |
| Goblet Squats | Kniebeuge mit Kurzhantel vor der Brust |
| Bankdrücken | Kurzhantel-Bankdrücken |
| Einarmiges Rudern | gestützt auf der Hantelbank |
| Schulterdrücken | Overhead Press |
| Rumänisches Kreuzheben | Hüftbeuge mit geradem Rücken |

## Bedienung

- Übung über die Buttons in der oberen Leiste wählen; sie laufen in einer Schleife.
- **„Tafel ausblenden"** klappt das Infofenster weg, wenn es die Figur verdeckt.
- Funktioniert mit Maus, Tastatur und Touch – die Oberfläche passt sich an Handy,
  Tablet und Desktop an (die Buttonleiste bricht bei wenig Platz um).

## Web-Version

`docs/` enthält den fertigen Web-Export (GitHub Pages). Der Build läuft
**einfädig** (`variant/thread_support=false`) und braucht daher weder
`SharedArrayBuffer` noch spezielle COOP/COEP-Header – wichtig, weil GitHub Pages
solche Header nicht setzen kann.

Neu bauen (Godot 4.7 mit installierten Export-Vorlagen):

```bash
godot --headless --path . --export-release "Web" docs/index.html
```

## Aufbau des Projekts

| Pfad | Inhalt |
| --- | --- |
| `scenes/main.tscn` | Bühne, Licht, Charakter, HUD |
| `scripts/main.gd` | Übungsdaten, Kamera, Hantel-Sichtbarkeit, Tafel-Schalter |
| `scripts/gen_animationen.gd` | erzeugt die fünf Animationen per IK (Sollwerte, Zwischenbilder) |
| `anim/uebungen.tres` | fertige Animationsbibliothek |
| `scripts/tools_check.gd` | Messprüfung der Bewegungsregeln (41 Regeln) |
| `PLAN_Animationen.md` | Bewegungsplan, Sollwinkel und behobene Fehler |

## Lizenzen und Credits

- **Charakter:** „Ch42" von Mixamo (Adobe). Nutzung nach den
  [Mixamo-/Adobe-Bedingungen](https://www.mixamo.com/) – Hobbyprojekt ohne
  kommerzielle Absicht.
- **Kurzhantel:** „Dumbbell" von **polypizza** (bzw. CreativeTrio), laut Autor
  frei nutzbar, auch kommerziell.
- **Quellcode und Szenen** dieses Projekts: MIT-Lizenz, siehe `LICENSE`.

Die 3D-Modelle und Texturen unterliegen den Bedingungen ihrer jeweiligen
Urheber; die MIT-Lizenz gilt nur für den eigenen Code.
