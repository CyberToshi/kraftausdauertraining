extends Node
## Prüfwerkzeug zu PLAN_Animationen.md (Abschnitt 4 und 6).
##
##   Tastet die fünf Clips aus anim/uebungen.tres in 0,1-s-Schritten ab und
##   vergleicht die Messwerte mit den Abnahmekriterien je Übung.
##
##   Godot --headless --path <Projekt> res://scripts/tools_check.tscn
##   Rückgabewert 1, sobald eine Regel verletzt ist.

const FBX := "res://Ch42_nonPBR.fbx"
const BIBLIOTHEK := "res://anim/uebungen.tres"
const SCHRITT := 0.1
const BODEN := 0.128

## Müssen zu scenes/main.tscn passen (Ablage der Hanteln am Knochen).
const HANTEL_IN_HAND := Vector3(0, -0.015, 0.03)
const HANTEL_AM_BRUSTBEIN := Vector3(0, -0.055, 0.13)

const KNOCHEN := [
	"mixamorig_Hips", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
	"mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
	"mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
	"mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot",
	"mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot",
	"mixamorig_LeftToeBase", "mixamorig_RightToeBase",
]

## Abnahmekriterien je Clip: [Text, Messwert, Auswahl, Soll min, Soll max, Einheit]
##   Auswahl: "min"/"max"    = Extremwert über alle Stützstellen
##            "tief"         = Stützstelle mit der tiefsten Hüfte
##            "hoch"         = Stützstelle mit der höchsten Hüfte
##            "tief_hand"    = Stützstelle mit der tiefsten rechten Hand
const REGELN := {
	"GobletSquat": [
		["Fersen links bleiben am Boden (Interpolation ±8 mm)", "fuss_y_l", "min", 0.120, 0.136, "m"],
		["Fersen rechts bleiben am Boden", "fuss_y_r", "max", 0.124, 0.132, "m"],
		["Knie links auf der Fußlinie", "knie_x_l", "tief", 0.19, 0.26, "m"],
		["Knie rechts spiegelbildlich", "knie_x_r", "tief", -0.26, -0.19, "m"],
		["Becken mittig", "hips_x", "min", -0.005, 0.005, "m"],
		["Hüfte sinkt auf Sitzhöhe", "hips_y", "min", 0.52, 0.58, "m"],
		["Rumpf bleibt aufrecht genug", "rumpf", "max", 18.0, 32.0, "°"],
		["Kopf nicht in den Rumpf geknickt", "kopf", "max", -15.0, 22.0, "°"],
		["Ellbogen links im Griffbereich", "ellb_l", "min", 70.0, 148.0, "°"],
		["Ellbogen rechts im Griffbereich", "ellb_r", "min", 70.0, 148.0, "°"],
		["Untere Hand am unteren Hantelende", "griff_l", "max", 0.0, 0.07, "m"],
		["Obere Hand am oberen Hantelende", "griff_r", "max", 0.0, 0.07, "m"],
		["Sohle liegt flach (links)", "zehe_y_l", "max", 0.0, 0.055, "m"],
		["Sohle liegt flach (rechts)", "zehe_y_r", "max", 0.0, 0.055, "m"],
	],
	"Kreuzheben": [
		["Fersen bleiben am Boden (Interpolation ±10 mm)", "fuss_y_l", "min", 0.118, 0.138, "m"],
		["Kniebeugung links bleibt klein", "kniebeug_l", "min", 4.0, 30.0, "°"],
		["Kniebeugung links bleibt konstant", "kniebeug_l", "max", 4.0, 30.0, "°"],
		["Rumpfneigung in der tiefen Position", "rumpf", "max", 65.0, 82.0, "°"],
		["Kopf bleibt neutral", "kopf", "max", -15.0, 30.0, "°"],
		["Hanteln vor/hinter der Schienbeinlinie", "hantel_abstand_bein", "max", 0.0, 0.20, "m"],
		["Hantel tiefste Position", "hand_y_l", "min", 0.50, 0.62, "m"],
		["Hände unter den Schultern", "hand_ueber_schulter", "max", 0.0, 0.13, "m"],
		["Sohle liegt flach (links)", "zehe_y_l", "max", 0.0, 0.055, "m"],
		["Sohle liegt flach (rechts)", "zehe_y_r", "max", 0.0, 0.055, "m"],
	],
	"EinarmigesRudern": [
		["Rumpf fast waagerecht", "rumpf", "min", 76.0, 88.0, "°"],
		["Rumpf nicht überstreckt", "rumpf", "max", 76.0, 88.0, "°"],
		["Stützhand auf dem Polster", "hand_y_l", "min", 0.44, 0.52, "m"],
		["Stützknie auf dem Polster", "knie_y_l", "min", 0.42, 0.52, "m"],
		["Arm unten gestreckt", "ellb_r", "min", 0.0, 25.0, "°"],
		["Arm oben gebeugt", "ellb_r", "max", 100.0, 180.0, "°"],
		["Hantel unten unter der Schulter", "hand_ueber_schulter", "tief_hand", 0.0, 0.10, "m"],
	],
	"Schulterdruecken": [
		["Arme oben fast gestreckt (links)", "ellb_l", "min", 0.0, 25.0, "°"],
		["Arme oben fast gestreckt (rechts)", "ellb_r", "min", 0.0, 25.0, "°"],
		["Arme unten gebeugt, nicht überstreckt", "ellb_l", "max", 80.0, 165.0, "°"],
		["Kein Hohlkreuz", "rumpf", "max", 0.0, 14.0, "°"],
		["Becken mittig", "hips_x", "min", -0.005, 0.005, "m"],
	],
	"Bankdruecken": [
		["Rumpf liegt waagerecht", "rumpf", "min", 84.0, 97.0, "°"],
		["Hüfte auf dem Polster", "hips_y", "min", 0.46, 0.58, "m"],
		["Arme oben fast gestreckt", "ellb_r", "min", 0.0, 28.0, "°"],
		["Hanteln über den Schultern", "hand_ueber_schulter", "hoch", 0.0, 0.16, "m"],
		["Ellbogen unten nicht überfaltet", "ellb_r", "max", 60.0, 150.0, "°"],
	],
}

var skel: Skeleton3D
var idx: Dictionary = {}
var player: AnimationPlayer
var verletzt: int = 0
var kopf_ruhe: float = 0.0


func _ready() -> void:
	var ps: PackedScene = load(FBX)
	if ps == null:
		print("FAIL: ", FBX, " nicht ladbar")
		get_tree().quit(1)
		return
	var charakter: Node3D = ps.instantiate()
	add_child(charakter)
	await get_tree().process_frame
	skel = charakter.get_node_or_null("Skeleton3D")
	if skel == null:
		print("FAIL: kein Skeleton3D im Charakter")
		get_tree().quit(1)
		return
	for name in KNOCHEN:
		idx[name] = skel.find_bone(name)
		if int(idx[name]) < 0:
			print("FAIL: Knochen fehlt: ", name)
			get_tree().quit(1)
			return

	kopf_ruhe = _winkel_zwischen((skel.get_bone_global_rest(idx["mixamorig_Head"]).origin - skel.get_bone_global_rest(idx["mixamorig_Neck"]).origin).normalized(), skel.get_bone_global_rest(idx["mixamorig_Spine2"]).basis.y.normalized())

	# Eigenen Player anlegen, damit der Clip allein die Pose bestimmt.
	var alt: AnimationPlayer = charakter.get_node_or_null("AnimationPlayer")
	if alt != null:
		alt.stop()
	player = AnimationPlayer.new()
	charakter.add_child(player)
	player.root_node = NodePath("..")

	var lib = load(BIBLIOTHEK)
	if lib == null:
		print("FAIL: ", BIBLIOTHEK, " fehlt – zuerst gen_animationen ausführen")
		get_tree().quit(1)
		return
	player.add_animation_library("uebungen", lib)

	for clip in lib.get_animation_list():
		await _pruefe("uebungen/" + clip)

	print("ERGEBNIS: %d Regel(n) verletzt" % verletzt)
	get_tree().quit(1 if verletzt > 0 else 0)


func _pruefe(clip: String) -> void:
	var anim: Animation = player.get_animation(clip)
	var kurz: String = clip.get_slice("/", 1)
	if anim == null:
		print("FAIL: Clip nicht ladbar: ", clip)
		verletzt += 1
		return
	print("--- %-18s %.2f s" % [kurz, anim.length])
	player.play(clip)

	var stat: Dictionary = {}      # Messwert -> {min, max}
	var tief: Dictionary = {}      # Stützstelle mit tiefster Hüfte
	var hoch: Dictionary = {}      # Stützstelle mit höchster Hüfte
	var hand_tief: Dictionary = {} # Stützstelle mit tiefster rechter Hand
	var t: float = 0.0
	var h_min: float = 1e9
	var h_max: float = -1e9
	var hand_min: float = 1e9
	while t <= anim.length + 0.0001:
		var m: Dictionary = await _messen(t)
		for k in m:
			var v: float = float(m[k])
			if stat.has(k):
				stat[k]["min"] = minf(float(stat[k]["min"]), v)
				stat[k]["max"] = maxf(float(stat[k]["max"]), v)
			else:
				stat[k] = {"min": v, "max": v}
		if float(m["hips_y"]) < h_min:
			h_min = float(m["hips_y"])
			tief = m.duplicate()
		if float(m["hips_y"]) > h_max:
			h_max = float(m["hips_y"])
			hoch = m.duplicate()
		if float(m["hand_y_r"]) < hand_min:
			hand_min = float(m["hand_y_r"])
			hand_tief = m.duplicate()
		t += SCHRITT

	var regeln: Array = REGELN.get(kurz, [])
	var gut: int = 0
	for r in regeln:
		var wert: float = _wert(String(r[1]), String(r[2]), stat, tief, hoch, hand_tief)
		var einheit: String = String(r[5])
		var passt: bool = wert >= float(r[3]) and wert <= float(r[4])
		if passt:
			gut += 1
		else:
			verletzt += 1
		print("  %s %-44s ist %6.3f %-2s soll %.3f…%.3f" % [
			"OK  " if passt else "FEHL",
			String(r[0]), wert, einheit, float(r[3]), float(r[4]),
		])
	print("       %d von %d Regeln erfüllt" % [gut, regeln.size()])


func _wert(name: String, auswahl: String, stat: Dictionary, tief: Dictionary,
		hoch: Dictionary, hand_tief: Dictionary) -> float:
	match auswahl:
		"min":
			return float(stat[name]["min"])
		"max":
			return float(stat[name]["max"])
		"tief":
			return float(tief[name])
		"hoch":
			return float(hoch[name])
		"tief_hand":
			return float(hand_tief[name])
	return 0.0


## Misst einen Zeitpunkt und liefert alle Kennzahlen in Metern bzw. Grad.
func _messen(t: float) -> Dictionary:
	player.seek(t, true)
	# Ein Frame warten, damit Skeleton3D die Knochenposen aus dem Clip neu berechnet.
	await get_tree().process_frame
	var m: Dictionary = {}
	var hips: Vector3 = _p("mixamorig_Hips")
	var spine2: Vector3 = _p("mixamorig_Spine2")
	var hals: Vector3 = _p("mixamorig_Neck")
	var kopf: Vector3 = _p("mixamorig_Head")
	var hf_l: Vector3 = _p("mixamorig_LeftUpLeg")
	var hf_r: Vector3 = _p("mixamorig_RightUpLeg")
	var kn_l: Vector3 = _p("mixamorig_LeftLeg")
	var kn_r: Vector3 = _p("mixamorig_RightLeg")
	var fuss_l: Vector3 = _p("mixamorig_LeftFoot")
	var fuss_r: Vector3 = _p("mixamorig_RightFoot")
	var schulter_r: Vector3 = _p("mixamorig_RightArm")
	var ellb_l: Vector3 = _p("mixamorig_LeftForeArm")
	var ellb_r: Vector3 = _p("mixamorig_RightForeArm")
	var hand_l: Vector3 = _hantel_mitte("Left")
	var hand_r: Vector3 = _hantel_mitte("Right")
	var brust: Vector3 = _p("mixamorig_Spine2") + skel.get_bone_global_pose(idx["mixamorig_Spine2"]).basis * HANTEL_AM_BRUSTBEIN

	m["hips_x"] = hips.x
	m["hips_y"] = hips.y
	m["fuss_y_l"] = fuss_l.y
	m["fuss_y_r"] = fuss_r.y
	# Zehenspitze: steigt sie an, steht die Figur auf der Ferse (Sohle kippt).
	m["zehe_y_l"] = _p("mixamorig_LeftToeBase").y
	m["zehe_y_r"] = _p("mixamorig_RightToeBase").y
	m["knie_x_l"] = kn_l.x
	m["knie_x_r"] = kn_r.x
	m["knie_z_l"] = kn_l.z
	m["rumpf"] = _winkel_zur_senkrechten(spine2 - hips)
	m["kopf"] = _winkel_zwischen((kopf - hals).normalized(), skel.get_bone_global_pose(idx["mixamorig_Spine2"]).basis.y.normalized()) - kopf_ruhe
	m["kniebeug_l"] = _beugung(hf_l, kn_l, fuss_l)
	m["kniebeug_r"] = _beugung(hf_r, kn_r, fuss_r)
	m["ellb_l"] = _beugung(_p("mixamorig_LeftArm"), ellb_l, hand_l)
	m["ellb_r"] = _beugung(schulter_r, ellb_r, hand_r)
	m["hand_y_l"] = hand_l.y
	m["hand_y_r"] = hand_r.y
	m["hand_ueber_schulter"] = absf(hand_r.x - schulter_r.x)
	m["haende_abstand"] = hand_l.distance_to(hand_r)
	m["brust_abstand"] = brust.distance_to((hand_l + hand_r) * 0.5)
	m["kopf_abstand"] = minf(absf(hand_l.x - kopf.x), absf(hand_r.x - kopf.x))
	# Abstand der Hantel zur Schienbeinlinie (Knie bis Sprunggelenk)
	m["hantel_abstand_bein"] = absf(hand_l.z - kn_l.z)
	m["knie_y_l"] = kn_l.y
	m["symmetrie"] = absf(float(m["ellb_l"]) - float(m["ellb_r"]))
	# Abstand der Handflaechen zu den Enden der senkrechten Brusthantel
	var bb: Basis = skel.get_bone_global_pose(idx["mixamorig_Spine2"]).basis.orthonormalized()
	var bm: Vector3 = spine2 + bb * HANTEL_AM_BRUSTBEIN
	var b_oben: Vector3 = bm + bb * Vector3(0, 0.177, 0)
	var b_unten: Vector3 = bm - bb * Vector3(0, 0.177, 0)
	var fl_l: Vector3 = _flaeche("Left")
	var fl_r: Vector3 = _flaeche("Right")
	m["griff_l"] = minf(fl_l.distance_to(b_oben), fl_l.distance_to(b_unten))
	m["griff_r"] = minf(fl_r.distance_to(b_oben), fl_r.distance_to(b_unten))
	return m


func _p(name: String) -> Vector3:
	return skel.get_bone_global_pose(idx[name]).origin


## Mitte der Hantel, die in der angegebenen Hand steckt.
func _hantel_mitte(seite: String) -> Vector3:
	var t: Transform3D = skel.get_bone_global_pose(idx["mixamorig_%sHand" % seite])
	return t.origin + t.basis * HANTEL_IN_HAND


## Mitte der Handflaeche: Handgelenk + halbe Fingerlaenge nach vorn.
func _flaeche(seite: String) -> Vector3:
	var t: Transform3D = skel.get_bone_global_pose(idx["mixamorig_%sHand" % seite])
	return t.origin + t.basis.y.normalized() * 0.05


## Beugewinkel in Grad: 0 = gestreckt, 180 = voll gefaltet.
func _beugung(a: Vector3, b: Vector3, c: Vector3) -> float:
	var v1: Vector3 = a - b
	var v2: Vector3 = c - b
	if v1.length() < 0.0001 or v2.length() < 0.0001:
		return 0.0
	return 180.0 - rad_to_deg(acos(clampf(v1.normalized().dot(v2.normalized()), -1.0, 1.0)))


## Kuerzester Abstand eines Punktes zu einer Strecke.
func _abstand_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Winkel zwischen zwei Richtungen in Grad.
func _winkel_zwischen(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))


## Winkel einer Richtung gegen die Welt-Senkrechte in Grad (0 = aufrecht).
func _winkel_zur_senkrechten(v: Vector3) -> float:
	if v.length() < 0.0001:
		return 0.0
	return rad_to_deg(acos(clampf(v.normalized().dot(Vector3.UP), -1.0, 1.0)))
