extends Node3D
## =============================================================================
##  Interaktive Präsentation "Kraftausdauertraining"
##  Godot 4.7 – vollständiges Steuerskript (UI + Animation)
## =============================================================================
##  Szenen-Aufbau (res://scenes/main.tscn):
##
##  Kraftausdauertraining (Node3D)              <- dieses Skript
##  ├── Welt (Node3D)
##  │   ├── WorldEnvironment
##  │   ├── Sonnenlicht (DirectionalLight3D)
##  │   ├── Kamera (Camera3D)
##  │   ├── Boden (MeshInstance3D)
##  │   ├── Charakter (Instanz Ch42_nonPBR.fbx -> Skeleton3D + AnimationPlayer)
##  │   └── Hantel (Instanz Dumbbell ... .glb)
##  └── HUD (CanvasLayer)                       <- Overlay über der 3D-Szene
##      └── Overlay (Control)
##          └── Rand (MarginContainer)
##              └── Spalte (VBoxContainer)
##                  ├── Leiste (PanelContainer)
##                  │   └── Innen (MarginContainer)
##                  │       └── ButtonLeiste (HBoxContainer)   %ButtonLeiste
##                  │           ├── BtnGobletSquat
##                  │           ├── BtnBankdruecken
##                  │           ├── BtnRudern
##                  │           ├── BtnSchulterdruecken
##                  │           └── BtnKreuzheben
##                  ├── Abstand (Control)     (schiebt das Hinweisfenster nach unten)
##                  └── Unten (HBoxContainer)
##                      ├── HinweisPanel (PanelContainer)      %HinweisPanel
##                      │   └── Innen (MarginContainer)
##                      │       └── Inhalt (VBoxContainer)
##                      │           ├── HinweisTitel (Label)          %HinweisTitel
##                      │           ├── HinweisUntertitel (Label)      %HinweisUntertitel
##                      │           ├── Trennlinie (HSeparator)
##                      │           ├── HinweisText (RichTextLabel)     %HinweisText
##                      │           └── Status (Label)                 %Status
##                      └── Rechts (Control)      (Füllraum, damit das Fenster links bleibt)
## =============================================================================


# =============================================================================
#  1) INHALTSDATEN
#  Jeder Eintrag = ein Button + ein Hinweisfenster-Inhalt.
#  "animation" muss dem Namen der Animation im AnimationPlayer entsprechen.
#  Die Schlüssel ("goblet_squat" ...) stehen in der Szene als
#  metadata/uebung an den Buttons – Reihenfolge ist daher egal.
# =============================================================================
const UEBUNGEN: Dictionary = {
	"goblet_squat": {
		"titel": "Goblet Squats",
		"untertitel": "Kniebeugen mit einer Kurzhantel",
		"muskeln": "Beine (Oberschenkel, Gesäß) und Rumpf (Core)",
		"ausfuehrung": "Halte eine Kurzhantel mit beiden Händen senkrecht direkt vor deiner Brust. Stelle dich etwas breiter als schulterbreit hin. Geh in die Kniebeuge, als würdest du dich auf einen Stuhl setzen – der Rücken bleibt dabei gerade und die Knie zeigen in Richtung der Fußspitzen. Drücke dich über die Fersen wieder nach oben.",
		"animation": "GobletSquat",
	},
	"bankdruecken": {
		"titel": "Kurzhantel-Bankdrücken",
		"untertitel": "auf der Hantelbank oder als Boden-Drücken",
		"muskeln": "Brust, vordere Schultern und Trizeps",
		"ausfuehrung": "Lege dich mit dem Rücken auf eine Hantelbank (oder alternativ flach auf den Boden). Halte in jeder Hand eine Hantel auf Brusthöhe, die Ellbogen zeigen im ca. 45-Grad-Winkel leicht nach unten. Drücke die Hanteln kontrolliert nach oben, bis die Arme fast gestreckt sind, und senke sie langsam wieder ab.",
		"animation": "Bankdruecken",
	},
	"rudern": {
		"titel": "Einarmiges Kurzhantel-Rudern",
		"untertitel": "gestützt auf Bank oder Stuhl",
		"muskeln": "Oberer Rücken, hintere Schultern und Bizeps",
		"ausfuehrung": "Stütze dich mit einer Hand und einem Knie auf einer Bank (oder mit einer Hand an einem stabilen Stuhl) ab. Der Rücken ist parallel zum Boden und gerade. Ziehe die Hantel mit der anderen Hand nah am Körper entlang in Richtung Hüfte hoch und lasse sie kontrolliert wieder herab.",
		"animation": "EinarmigesRudern",
	},
	"schulterdruecken": {
		"titel": "Schulterdrücken",
		"untertitel": "Overhead Press",
		"muskeln": "Schultern, Trizeps und Rumpfspannung",
		"ausfuehrung": "Stehe hüftbreit mit angespanntem Bauch und Gesäß. Halte die Hanteln auf Schulterhöhe (Handflächen zeigen nach vorn). Drücke die Gewichte gerade über den Kopf nach oben, ohne ins Hohlkreuz zu fallen, und senke sie langsam wieder auf Schulterhöhe ab.",
		"animation": "Schulterdruecken",
	},
	"kreuzheben": {
		"titel": "Rumänisches Kreuzheben",
		"untertitel": "Romanian Deadlifts",
		"muskeln": "Hintere Oberschenkel, Gesäß und unterer Rücken",
		"ausfuehrung": "Stehe hüftbreit und halte die Hanteln vor deinen Oberschenkeln. Beuge die Knie nur ganz leicht und schiebe deine Hüfte kontrolliert nach hinten, während du den Oberkörper mit geradem Rücken nach vorn neigst. Die Hanteln gleiten dabei nah an den Beinen entlang bis knapp unter die Knie. Richte dich durch Anspannen des Gesäßes wieder auf.",
		"animation": "Kreuzheben",
	},
}


# =============================================================================
#  2) EINSTELLUNGEN (im Inspector sichtbar)
# =============================================================================
@export_group("Animation")
## AnimationPlayer des Charaktermodells.
## Leer lassen -> das Skript sucht ihn automatisch in der Szene
## (Ch42_nonPBR -> AnimationPlayer).
@export var animation_player: AnimationPlayer
## true = Übung läuft endlos (Loop), false = einmal abspielen und stoppen.
@export var animation_loop: bool = true
## Überblendzeit beim Wechsel zwischen zwei Übungen (Sekunden).
@export_range(0.0, 1.0, 0.05) var blend_zeit: float = 0.25


# =============================================================================
#  3) NODE-REFERENZEN
#  "%Name" = Node mit aktivierter Option "Access as Unique Name" (%).
# =============================================================================
@onready var _button_leiste: Container = %ButtonLeiste
@onready var _hinweis_titel: Label = %HinweisTitel
@onready var _hinweis_untertitel: Label = %HinweisUntertitel
@onready var _hinweis_text: RichTextLabel = %HinweisText
@onready var _status: Label = %Status
@onready var _charakter: Node3D = %Charakter
@onready var _hantelbank: Node3D = %Hantelbank
@onready var _kamera: Camera3D = %Kamera
@onready var _hantel_rechts: Node3D = %HantelRechts
@onready var _hantel_links: Node3D = %HantelLinks
@onready var _hantel_brust: Node3D = %HantelBrust
@onready var _hinweis_panel: PanelContainer = %HinweisPanel
@onready var _btn_details: Button = %BtnDetails
## Rand des HUD – Abstand wird je Bildschirmgroesse gesetzt.
@onready var _rand: MarginContainer = $HUD/Overlay/Rand

## Zuletzt gewählte Übung (Schlüssel aus UEBUNGEN).
var _aktuelle_uebung: String = ""


# =============================================================================
#  4) INITIALISIERUNG
# =============================================================================
func _ready() -> void:
	# AnimationPlayer automatisch finden, falls nicht im Inspector gesetzt.
	if animation_player == null:
		animation_player = _finde_animation_player(self)
	if animation_player == null:
		push_warning("Kein AnimationPlayer in der Szene gefunden. Liegt der Charakter unter 'Welt/Charakter'?")

	# Alle Buttons verbinden: der Übungs-Schlüssel steckt in metadata/uebung.
	for kind in _button_leiste.get_children():
		if kind is Button and kind.has_meta("uebung"):
			var schluessel: String = String(kind.get_meta("uebung"))
			kind.pressed.connect(_on_uebung_gewaehlt.bind(schluessel))

	# Tafel ein-/ausklappen, damit die Figur unverdeckt zu sehen ist.
	if _btn_details != null:
		_btn_details.pressed.connect(_details_umschalten)

	_bibliothek_laden()
	_buehne_setzen("")
	_zeige_startansicht()


# =============================================================================
#  5) EREIGNISSE
# =============================================================================
## Wird bei jedem Klick auf einen Übungs-Button ausgelöst.
func _on_uebung_gewaehlt(schluessel: String) -> void:
	var daten: Dictionary = UEBUNGEN.get(schluessel, {})
	if daten.is_empty():
		push_warning("Unbekannte Übung '%s' (metadata/uebung am Button prüfen)." % schluessel)
		return

	_aktuelle_uebung = schluessel
	_buehne_setzen(schluessel)
	_aktualisiere_hinweis(daten)
	_spiele_animation(String(daten["animation"]))


# =============================================================================
#  6) HINWEISFENSTER
# =============================================================================
## Startzustand: kurze Bedienhinweise, solange keine Übung gewählt wurde.
func _zeige_startansicht() -> void:
	_hinweis_titel.text = "Kraftausdauertraining"
	_hinweis_untertitel.text = "Wähle oben eine Übung"
	_hinweis_text.text = (
		"[b]So funktioniert's[/b]\n"
		+ "Klicke auf einen der fünf Buttons – der Charakter führt die Übung im Loop vor "
		+ "und hier erscheinen Muskelgruppen und die genaue Ausführungsbeschreibung.\n\n"
		+ "[b]Übungen[/b]\n"
		+ "1. Goblet Squats   2. Kurzhantel-Bankdrücken   3. Einarmiges Kurzhantel-Rudern\n"
		+ "4. Schulterdrücken (Overhead Press)   5. Rumänisches Kreuzheben"
	)
	_status.text = "Bereit – noch keine Animation aktiv."
	if animation_player == null:
		_status.text = "Hinweis: Kein AnimationPlayer gefunden – siehe README, Abschnitt 3."


## Schreibt Name, Muskelgruppen und Ausführung der gewählten Übung ins Fenster.
func _aktualisiere_hinweis(daten: Dictionary) -> void:
	_hinweis_titel.text = String(daten.get("titel", ""))
	_hinweis_untertitel.text = String(daten.get("untertitel", ""))
	_hinweis_text.text = (
		"[b]Trainierte Muskelgruppen[/b]\n"
		+ String(daten.get("muskeln", ""))
		+ "\n\n[b]Ausführung[/b]\n"
		+ String(daten.get("ausfuehrung", ""))
	)


# =============================================================================
#  7) ANIMATIONSTEUERUNG
# =============================================================================
## Spielt die Übungsanimation im Loop. Sucht den Namen tolerant, damit
## z. B. "uebungen/GobletSquat", "Ch42|GobletSquat_v2" oder "mixamo_com_GobletSquat"
## ebenfalls gefunden werden.
func _spiele_animation(animations_name: String) -> void:
	if animation_player == null:
		_status.text = "Hinweis: Kein AnimationPlayer gefunden – siehe README, Abschnitt 3."
		return

	var gefunden: String = _finde_animationsnamen(animations_name)
	if gefunden == "":
		_status.text = (
			"Hinweis: Animation „%s“ fehlt noch – importiere sie wie im README beschrieben "
			% animations_name
			+ "(Abschnitt 3)."
		)
		push_warning(
			"Animation '%s' nicht gefunden. Vorhanden: %s"
			% [animations_name, animation_player.get_animation_list()]
		)
		return

	# Loop-Verhalten direkt am Animation-Ressourcenobjekt setzen.
	var animation: Animation = animation_player.get_animation(gefunden)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if animation_loop else Animation.LOOP_NONE

	animation_player.play(gefunden, blend_zeit)
	_status.text = "Läuft: %s · %.2f s · Loop %s" % [
		gefunden,
		animation.length if animation != null else 0.0,
		"an" if animation_loop else "aus",
	]


## Sucht in allen Bibliotheken des Players nach einem passenden Namen.
## Reihenfolge: identisch -> endet mit dem Namen -> enthält den Namen.
func _finde_animationsnamen(wunsch: String) -> String:
	if animation_player == null:
		return ""
	var ziel: String = _normalisiere(wunsch)
	var alle: PackedStringArray = animation_player.get_animation_list()

	for name in alle:
		if _normalisiere(name) == ziel:
			return name
	for name in alle:
		if _normalisiere(name).ends_with(ziel):
			return name
	for name in alle:
		if _normalisiere(name).contains(ziel):
			return name
	return ""


## Kleinschreibung + nur a-z/0-9, damit "mixamorig:Name" == "mixamorig_Name"
## und Bibliotheks-Präfixe wie "uebungen/GobletSquat" nicht stören.
func _normalisiere(wert: String) -> String:
	var klein: String = wert.to_lower()
	var ergebnis: String = ""
	for i in klein.length():
		var code: int = klein.unicode_at(i)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			ergebnis += klein[i]
	return ergebnis


## Rekursive Suche nach dem ersten AnimationPlayer (bevorzugt den mit den
## meisten Animationen – so gewinnt der Charakter gegen leere Hilfsplayer).
func _finde_animation_player(wurzel: Node) -> AnimationPlayer:
	var treffer: AnimationPlayer = null
	for kind in wurzel.get_children():
		if kind is AnimationPlayer:
			if treffer == null or kind.get_animation_list().size() > treffer.get_animation_list().size():
				treffer = kind
		else:
			var tiefer: AnimationPlayer = _finde_animation_player(kind)
			if tiefer != null:
				if treffer == null or tiefer.get_animation_list().size() > treffer.get_animation_list().size():
					treffer = tiefer
	return treffer


# =============================================================================
#  8) BÜHNE – Animationen laden, Charakter und Hantelbank ausrichten
#  Die fünf Übungsanimationen liegen als eigene Bibliothek im Projekt
#  (anim/uebungen.tres, erzeugt von scripts/gen_animationen.gd).
# =============================================================================
const ANIM_BIBLIOTHEK: String = "res://anim/uebungen.tres"

## Kamera im Startzustand (noch keine Übung gewählt).
const START_KAMERA: Dictionary = {
	"pos": Vector3(0.0, 1.2, 3.3),
	"ziel": Vector3(0.0, 1.0, 0.0),
	"fov": 45.0,
}

## Aufbau je Übung:
##   char_rot_y : Drehung des Charakters um die Hochachse (Grad)
##   bank       : Hantelbank einblenden
##   bank_pos   : Position der Bank in der Welt
##   bank_rot_y : Drehung der Bank
##   lehne      : Winkel der Rückenlehne (0 = flach, -80 = aufrecht, s. Hantelbank.tscn)
##   hanteln    : welche Hantel sichtbar ist – "beide", "rechts" oder "brust"
##   kamera     : Position, Blickziel und Brennweite für diese Übung
const BUEHNE: Dictionary = {
	"goblet_squat": {
		"char_rot_y": 0.0,
		"bank": false,
		"hanteln": "brust",
		"kamera": {"pos": Vector3(1.30, 1.15, 2.75), "ziel": Vector3(0.0, 1.05, 0.0), "fov": 45.0},
	},
	"bankdruecken": {
		"char_rot_y": 90.0,
		"bank": true,
		"bank_pos": Vector3(-0.12, 0.0, 0.0),
		"bank_rot_y": -90.0,
		"lehne": 0.0,
		"hanteln": "beide",
		"kamera": {"pos": Vector3(2.50, 1.70, 2.05), "ziel": Vector3(-0.40, 0.72, 0.0), "fov": 50.0},
	},
	"rudern": {
		"char_rot_y": 0.0,
		"bank": true,
		"bank_pos": Vector3(0.16, 0.0, 0.375),
		"bank_rot_y": 0.0,
		"lehne": 0.0,
		"hanteln": "rechts",
		"kamera": {"pos": Vector3(2.25, 1.50, 2.20), "ziel": Vector3(-0.25, 0.80, 0.25), "fov": 45.0},
	},
	"schulterdruecken": {
		"char_rot_y": 0.0,
		"bank": true,
		"bank_pos": Vector3(0.0, 0.0, -0.04),
		"bank_rot_y": 180.0,
		"lehne": -80.0,
		"hanteln": "beide",
		"kamera": {"pos": Vector3(0.65, 1.55, 2.90), "ziel": Vector3(0.0, 1.35, 0.0), "fov": 45.0},
	},
	"kreuzheben": {
		"char_rot_y": 0.0,
		"bank": false,
		"hanteln": "beide",
		"kamera": {"pos": Vector3(1.45, 1.10, 2.65), "ziel": Vector3(0.0, 0.95, 0.10), "fov": 45.0},
	},
}



## Hängt die Animationsbibliothek an den AnimationPlayer (falls vorhanden).
func _bibliothek_laden() -> void:
	if animation_player == null or not ResourceLoader.exists(ANIM_BIBLIOTHEK):
		return
	var bibliothek = load(ANIM_BIBLIOTHEK)
	if bibliothek is AnimationLibrary and not animation_player.has_animation_library("uebungen"):
		animation_player.add_animation_library("uebungen", bibliothek)


## Richtet Kamera, Hanteln, Charakter und Hantelbank für die gewählte Übung aus.
## Leerer Schlüssel = Startzustand (Bank weg, beide Handhanteln, Kamera zurück).
func _buehne_setzen(schluessel: String) -> void:
	var daten: Dictionary = BUEHNE.get(schluessel, {})
	_kamera_setzen(daten.get("kamera", START_KAMERA))
	_hantel_setzen(String(daten.get("hanteln", "beide")))
	if _charakter == null or _hantelbank == null:
		return

	if daten.is_empty():
		_charakter.rotation_degrees.y = 0.0
		_hantelbank.visible = false
		return

	_charakter.rotation_degrees.y = float(daten.get("char_rot_y", 0.0))
	_hantelbank.visible = bool(daten.get("bank", false))
	if not _hantelbank.visible:
		return

	_hantelbank.position = daten.get("bank_pos", Vector3.ZERO)
	_hantelbank.rotation_degrees.y = float(daten.get("bank_rot_y", 0.0))
	var lehne: Node3D = _hantelbank.get_node_or_null("Lehne") as Node3D
	if lehne != null:
		lehne.rotation_degrees.x = float(daten.get("lehne", 0.0))


## Blendet die Hanteln ein, die die Übung braucht:
## "beide" = je eine in der Hand, "rechts" = nur rechte Hand (Rudern),
## "brust" = eine senkrechte Hantel am Brustbein (Goblet Squat).
func _hantel_setzen(modus: String) -> void:
	if _hantel_rechts == null or _hantel_links == null or _hantel_brust == null:
		return
	_hantel_rechts.visible = modus == "beide" or modus == "rechts"
	_hantel_links.visible = modus == "beide"
	_hantel_brust.visible = modus == "brust"


## Setzt Position, Blickziel und Brennweite der Kamera.
func _kamera_setzen(daten: Dictionary) -> void:
	if _kamera == null:
		return
	_kamera.position = daten.get("pos", Vector3(0.0, 1.2, 3.3))
	_kamera.fov = float(daten.get("fov", 45.0))
	var ziel: Vector3 = daten.get("ziel", Vector3(0.0, 1.0, 0.0))
	if _kamera.position.distance_to(ziel) > 0.01:
		_kamera.look_at(ziel)


# =============================================================================
#  9) TAFEL EIN-/AUSKLAPPEN
# =============================================================================
## Blendet das Hinweisfenster aus, damit die Figur frei sichtbar ist.
## Der Schalter bleibt in der oberen Leiste immer erreichbar.
func _details_umschalten() -> void:
	_hinweis_panel.visible = not _hinweis_panel.visible
	_btn_details.text = (
		"Tafel ausblenden" if _hinweis_panel.visible else "Tafel einblenden"
	)


# =============================================================================
#  10) ANPASSUNG AN DIE BILDSCHIRMGROESSE
#  Handy (hoch/quer), Tablet und Desktop: Aussenrand schmaler, Infotafel nie
#  breiter als ~40 % der Flaeche, Buttonleiste bricht bei Platzmangel um.
# =============================================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_layout_anpassen()
		get_viewport().size_changed.connect(_layout_anpassen)
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_anpassen()


func _layout_anpassen() -> void:
	var groesse: Vector2 = get_viewport().get_visible_rect().size
	var schmal: bool = groesse.x < 620.0
	var rand: int = 12 if schmal else 28
	for seite in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_rand.add_theme_constant_override(seite, rand)
	# Tafel: 210 bis 340 Einheiten breit, unabhaengig von der Bildschirmbreite.
	_hinweis_panel.custom_minimum_size = Vector2(clampf(groesse.x * 0.42, 210.0, 340.0), 0.0)
