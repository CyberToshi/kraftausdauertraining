extends Node
## Werkzeug: rendert je Uebung Bilder aus der Praesentationskamera.
##
##   Godot --path . res://scripts/tools_shot.tscn -- <uebung> <t1,t2,...>
##   ohne Argumente: alle fuenf Uebungen bei 0/33/66/100 % der Clipdauer.
##   Ablage: res://_shots/<uebung>_t<zeit>.png

const MAIN := "res://scenes/main.tscn"

const UEBUNGEN := [
	["goblet_squat", "GobletSquat"],
	["bankdruecken", "Bankdruecken"],
	["rudern", "EinarmigesRudern"],
	["schulterdruecken", "Schulterdruecken"],
	["kreuzheben", "Kreuzheben"],
]

var main: Node3D


func _ready() -> void:
	main = (load(MAIN) as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var args: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://_shots")

	var nur: String = args[0] if args.size() > 0 else ""
	for eintrag in UEBUNGEN:
		var schluessel: String = String(eintrag[0])
		if nur != "" and nur != schluessel:
			continue
		main.call("_on_uebung_gewaehlt", schluessel)
		await get_tree().process_frame
		var ap: AnimationPlayer = main.get("animation_player") as AnimationPlayer
		var clip: String = ""
		for n in ap.get_animation_list():
			if String(n).contains(String(eintrag[1])):
				clip = String(n)
				break
		if clip == "":
			print("FAIL: Clip fehlt fuer ", schluessel)
			continue
		var laenge: float = ap.get_animation(clip).length
		var zeiten: Array = []
		if args.size() > 1:
			for z in String(args[1]).split(","):
				zeiten.append(float(z))
		else:
			zeiten = [0.0, laenge * 0.33, laenge * 0.66, laenge * 0.98]
		for t in zeiten:
			await _bild(schluessel, clip, float(t))
	print("BILDER FERTIG")
	get_tree().quit(0)


func _bild(schluessel: String, clip: String, t: float) -> void:
	var ap: AnimationPlayer = main.get("animation_player") as AnimationPlayer
	ap.play(clip, 0.0)
	ap.seek(t, true)
	# Zwei Frames: erst Skeleton neu rechnen, dann zeichnen lassen.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var pfad := "res://_shots/%s_t%04.1f.png" % [schluessel, t]
	var err: int = img.save_png(pfad)
	print("  %s -> %d" % [pfad, err])
