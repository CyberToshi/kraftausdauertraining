extends Node
## Generator für die fünf Übungsanimationen.
##
##  1. Skelett laden, T-Pose des Imports als Basispose merken.
##  2. Keys je Übung als Ankerpunkte beschreiben. _raster() füllt dazwischen
##     Zwischen-Keys ein, damit die IK-Lösung keine langen Geraden zieht
##     (sonst wandern Füße und Hände zwischen zwei Keys durch Boden und Gerät).
##  3. Beine per 2-Knochen-IK auf feste Knöchelpunkte, Arme auf Griffziele.
##     Ein Handziel ist Position *und* Griffrichtung (Finger + Handfläche) in
##     einem Rahmen ("welt", "schulter" oder "brust" = folgt dem Brustbein).
##  4. Dreh-Tracks (plus Hüftposition) in eine AnimationLibrary schreiben.

const FBX := "res://Ch42_nonPBR.fbx"
const ZIEL_PFAD := "res://anim/uebungen.tres"

const KNOCHEN := [
    "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
    "mixamorig_Neck", "mixamorig_Head",
    "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
    "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
    "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot",
    "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot",
]

## Fingerglieder je Hand (Mixamo-Namen: <Seite>Hand<Finger><Glied>).
const FINGER := ["Thumb", "Index", "Middle", "Ring", "Pinky"]

## Hantel in der Hand (muss zu scenes/main.tscn passen) - für Messwerte.
const HANTEL_IN_HAND := Vector3(0, -0.015, 0.03)

## Brusthantel (muss zu scenes/main.tscn passen): Mitte im Raum von Spine2,
## Stange senkrecht, halbe Länge 0.177 m (Skalierung 0,76).
const BRUST_MITTE := Vector3(0.0, -0.055, 0.13)
const BRUST_HALB := 0.177

var skel: Skeleton3D
var base: Array = []
var idx: Dictionary = {}
var W: Dictionary = {}
var laengen: Dictionary = {}
var fidx: Dictionary = {}
var fachse: Dictionary = {}
var kinder: Dictionary = {}
var kopf_ruhe: float = 0.0


func _ready() -> void:
    var ps: PackedScene = load(FBX)
    if ps == null:
        print("FAIL: FBX nicht ladbar")
        get_tree().quit(1)
        return
    var charakter: Node3D = ps.instantiate()
    add_child(charakter)
    await get_tree().process_frame
    skel = charakter.get_node("Skeleton3D")

    for i in skel.get_bone_count():
        base.append(skel.get_bone_pose(i))
    for name in KNOCHEN:
        idx[name] = skel.find_bone(name)
        if int(idx[name]) < 0:
            print("FAIL: Knochen fehlt: ", name)
            get_tree().quit(1)
            return
    _laengen_und_kinder()
    _finger_vorbereiten()
    kopf_ruhe = _winkel_zwischen((skel.get_bone_global_rest(idx["mixamorig_Head"]).origin - skel.get_bone_global_rest(idx["mixamorig_Neck"]).origin).normalized(), skel.get_bone_global_rest(idx["mixamorig_Spine2"]).basis.y.normalized())
    print("FINGERKNOCHEN=", fidx.size())

    var lib := AnimationLibrary.new()
    lib.add_animation("GobletSquat", await _baue("GobletSquat", _daten_goblet()))
    lib.add_animation("Bankdruecken", await _baue("Bankdruecken", _daten_bankdruecken()))
    lib.add_animation("EinarmigesRudern", await _baue("EinarmigesRudern", _daten_rudern()))
    lib.add_animation("Schulterdruecken", await _baue("Schulterdruecken", _daten_schulterdruecken()))
    lib.add_animation("Kreuzheben", await _baue("Kreuzheben", _daten_kreuzheben()))

    DirAccess.make_dir_recursive_absolute("res://anim")
    print("GESPEICHERT ", ZIEL_PFAD, " fehler=", ResourceSaver.save(lib, ZIEL_PFAD))
    for n in lib.get_animation_list():
        var a: Animation = lib.get_animation(n)
        print("  %-18s laenge=%.2f s tracks=%d" % [n, a.length, a.get_track_count()])
    get_tree().quit(0)


func _laengen_und_kinder() -> void:
    for i in skel.get_bone_count():
        kinder[i] = -1
    for i in skel.get_bone_count():
        var p: int = skel.get_bone_parent(i)
        if p >= 0 and int(kinder[p]) < 0:
            kinder[p] = i
    for name in KNOCHEN:
        var i: int = idx[name]
        var k: int = int(kinder[i])
        laengen[name] = skel.get_bone_global_rest(k).origin.distance_to(skel.get_bone_global_rest(i).origin) if k >= 0 else 0.1
    # Für die IK zählen nur die Kettenknochen (Mixamo hat zusätzliche Twist-Knochen).
    for paar in [
            ["mixamorig_LeftArm", "mixamorig_LeftForeArm"], ["mixamorig_LeftForeArm", "mixamorig_LeftHand"],
            ["mixamorig_RightArm", "mixamorig_RightForeArm"], ["mixamorig_RightForeArm", "mixamorig_RightHand"],
            ["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], ["mixamorig_LeftLeg", "mixamorig_LeftFoot"],
            ["mixamorig_RightUpLeg", "mixamorig_RightLeg"], ["mixamorig_RightLeg", "mixamorig_RightFoot"]]:
        laengen[paar[0]] = skel.get_bone_global_rest(idx[paar[1]]).origin.distance_to(skel.get_bone_global_rest(idx[paar[0]]).origin)


# -----------------------------------------------------------------------------
#  Pose-Werkzeuge
# -----------------------------------------------------------------------------
## Setzt die Weltorientierung des Knochens auf R_abs * Ruheorientierung.
func _setze_welt(name: String, R_abs: Basis) -> void:
    var i: int = idx[name]
    var jetzt: Transform3D = skel.get_bone_global_pose(i)
    var ruhe: Transform3D = skel.get_bone_global_rest(i)
    var ziel := Transform3D((R_abs * ruhe.basis).orthonormalized(), jetzt.origin)
    var parent: int = skel.get_bone_parent(i)
    if parent < 0:
        skel.set_bone_pose(i, ziel)
    else:
        var kette: Transform3D = skel.get_bone_global_pose(parent)
        skel.set_bone_pose(i, kette.affine_inverse() * ziel)
    await get_tree().process_frame


## Richtet ein Segment in Weltrichtung aus (kürzester Bogen von der Ruherichtung).
func _setze_richtung(name: String, richtung: Vector3, kind: String = "") -> void:
    var i: int = idx[name]
    var k: int = int(kinder[i])
    if kind != "":
        k = skel.find_bone(kind)
    if k < 0:
        return
    var rest_dir: Vector3 = (skel.get_bone_global_rest(k).origin - skel.get_bone_global_rest(i).origin).normalized()
    var ziel: Vector3 = richtung.normalized()
    if ziel.length() < 0.001:
        return
    await _setze_welt(name, Basis(Quaternion(rest_dir, ziel)))


## 2-Knochen-IK: [Gelenkposition, Richtung 1, Richtung 2]
func _ik2(wurzel: Vector3, ziel: Vector3, l1: float, l2: float, pol: Vector3) -> Array:
    var d: Vector3 = ziel - wurzel
    var dist: float = clampf(d.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
    var n: Vector3 = d.normalized()
    var a: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
    var p: Vector3 = pol - n * pol.dot(n)
    if p.length() < 0.001:
        p = Vector3(0, 1, 0) - n * n.y
    var gelenk: Vector3 = wurzel + n * a + p.normalized() * h
    return [gelenk, (gelenk - wurzel).normalized(), (wurzel + n * dist - gelenk).normalized()]


## Setzt die Weltorientierung der Hand direkt (Griff unabhängig von der Armhaltung).
func _setze_hand_welt(seite: String, ziel: Basis) -> void:
    var name := "mixamorig_%sHand" % seite
    var ruhe: Basis = skel.get_bone_global_rest(idx[name]).basis
    await _setze_welt(name, ziel * ruhe.inverse())


## Handbasis aus Fingerrichtung und Handflächennormale (beide in Welt).
## Gemessene Achsen der Hand: Y = Finger, Z = Handfläche, X = Hantelachse.
func _hand_basis(finger: Vector3, palme: Vector3) -> Basis:
    var z: Vector3 = palme.normalized()
    var y: Vector3 = finger - z * finger.dot(z)
    if y.length() < 0.001:
        y = Vector3(0, 0, 1)
    y = y.normalized()
    var x: Vector3 = y.cross(z)
    return Basis(x, y, z)


## Rechnet ein Handziel in die Welt um.
##   rahmen "welt"     : p absolut, Richtungen in Welt
##   rahmen "schulter" : p relativ zum Schultergelenk, Richtungen in Welt
##   rahmen "brust"    : p und Richtungen im Raum von Spine2 (folgt dem Oberkörper)
func _ziel_welt(ziel: Dictionary, schulter: Vector3) -> Dictionary:
    var p: Vector3 = ziel["p"]
    var finger: Vector3 = ziel["finger"]
    var palme: Vector3 = ziel["palme"]
    var rahmen_origin := Vector3.ZERO
    var rahmen_basis := Basis()
    var rahmen := String(ziel.get("rahmen", "welt"))
    if rahmen == "brust":
        var t: Transform3D = skel.get_bone_global_pose(idx["mixamorig_Spine2"])
        rahmen_origin = t.origin
        rahmen_basis = t.basis.orthonormalized()
    elif rahmen == "schulter":
        rahmen_origin = schulter
    return {
        "pos": rahmen_origin + rahmen_basis * p,
        "basis": _hand_basis((rahmen_basis * finger).normalized(), (rahmen_basis * palme).normalized()),
    }


## Bestimmt je Fingerglied die Krummachse (Fingerrichtung x Handflächennormale).
func _finger_vorbereiten() -> void:
    for seite in ["Left", "Right"]:
        var hand_i: int = idx["mixamorig_%sHand" % seite]
        var hb: Basis = skel.get_bone_global_rest(hand_i).basis.orthonormalized()
        for f in FINGER:
            for glied in [1, 2, 3]:
                var name := "mixamorig_%sHand%s%d" % [seite, f, glied]
                var i: int = skel.find_bone(name)
                if i < 0:
                    continue
                fidx[name] = i
                var k: int = int(kinder[i])
                var dir := Vector3(0, 1, 0)
                if k >= 0:
                    dir = (skel.get_bone_global_rest(k).origin - skel.get_bone_global_rest(i).origin).normalized()
                var achse_welt: Vector3 = dir.cross(hb.z.normalized()).normalized()
                fachse[name] = skel.get_bone_global_rest(i).basis.orthonormalized().inverse() * achse_welt


## Krümmt alle Finger einer Hand um den Griff.
func _finger_greifen(seite: String, grad: float) -> void:
    var faktor := [1.0, 1.1, 0.8]
    for f in FINGER:
        for glied in [1, 2, 3]:
            var name := "mixamorig_%sHand%s%d" % [seite, f, glied]
            if not fidx.has(name):
                continue
            var w: float = grad * float(faktor[glied - 1])
            if f.begins_with("Thumb"):
                w *= 0.7
            var bi: int = int(fidx[name])
            var ruhe: Transform3D = base[bi]
            skel.set_bone_pose(bi, Transform3D(ruhe.basis * Basis(fachse[name], deg_to_rad(w)), ruhe.origin))


func _euler(grad: Vector3) -> Basis:
    return Basis(Vector3(1, 0, 0), deg_to_rad(grad.x)) \
        * Basis(Vector3(0, 1, 0), deg_to_rad(grad.y)) \
        * Basis(Vector3(0, 0, 1), deg_to_rad(grad.z))


func _reset() -> void:
    W.clear()
    for i in skel.get_bone_count():
        skel.set_bone_pose(i, base[i])

# -----------------------------------------------------------------------------
#  Keyframe anwenden
# -----------------------------------------------------------------------------
func _pose_anwenden(k: Dictionary) -> void:
    _reset()
    await get_tree().process_frame

    # Hüfte: Drehung (Hüftknick) + Versatz
    await _setze_welt("mixamorig_Hips", _euler(k.get("hips_rot", Vector3.ZERO)))
    var hips_i: int = idx["mixamorig_Hips"]
    var hp: Transform3D = skel.get_bone_pose(hips_i)
    hp.origin = base[hips_i].origin + (k.get("hips", Vector3.ZERO) as Vector3)
    skel.set_bone_pose(hips_i, hp)
    await get_tree().process_frame

    # Rumpf: Die Neigung kommt aus dem Hüftknick. Die Wirbel verteilen nur
    # einen kleinen Rest, damit die Rückenlinie gerade bleibt (kein Buckel).
    var spine: Vector3 = k.get("spine", Vector3.ZERO)
    var w_h: Basis = (skel.get_bone_global_pose(hips_i).basis * skel.get_bone_global_rest(hips_i).basis.inverse()).orthonormalized()
    await _setze_welt("mixamorig_Spine", w_h * _euler(spine * 0.4))
    await _setze_welt("mixamorig_Spine1", w_h * _euler(spine * 0.7))
    await _setze_welt("mixamorig_Spine2", w_h * _euler(spine))
    # Hals: "kopf" dreht gegen den Rumpf (negativ = Blick heben), damit der
    # Kopf nicht mitkippt und die obere Rückenlinie gerade bleibt.
    var kopf: Vector3 = k.get("kopf", Vector3.ZERO)
    await _setze_welt("mixamorig_Neck", w_h * _euler(spine * 0.25 + kopf))

    # Beine: Sprunggelenk-Zielpunkte, Knie nach vorn
    var fuesse: Array = k["fuesse"]
    var pol_knie: Vector3 = k.get("pol_knie", Vector3(0, 0, 1))
    var fuss_richtungen: Variant = k.get("fuss_richtung", Vector3.ZERO)
    for seite in ["Left", "Right"]:
        var nr: int = 0 if seite == "Left" else 1
        var upleg := "mixamorig_%sUpLeg" % seite
        var leg := "mixamorig_%sLeg" % seite
        var foot := "mixamorig_%sFoot" % seite
        var huefte_pos: Vector3 = skel.get_bone_global_pose(idx[upleg]).origin
        var pol_seite: Vector3 = pol_knie if seite == "Left" else Vector3(-pol_knie.x, pol_knie.y, pol_knie.z)
        var erg: Array = _ik2(huefte_pos, fuesse[nr], float(laengen[upleg]), float(laengen[leg]), pol_seite)
        await _setze_richtung(upleg, erg[1], leg)
        await _setze_richtung(leg, erg[2], foot)
        # Nachziehen: Segmentlängen sind Ruheabstände, nicht exakte Reichweiten.
        var fehler: Vector3 = (fuesse[nr] as Vector3) - skel.get_bone_global_pose(idx[foot]).origin
        if fehler.length() > 0.002:
            erg = _ik2(huefte_pos, (fuesse[nr] as Vector3) + fehler, float(laengen[upleg]), float(laengen[leg]), pol_seite)
            await _setze_richtung(upleg, erg[1], leg)
            await _setze_richtung(leg, erg[2], foot)
        var fuss_richtung: Vector3 = fuss_richtungen if not (fuss_richtungen is Array) else (fuss_richtungen as Array)[nr]
        # Keine Fußrichtung angegeben -> Ruhelage übernehmen. Damit steht die
        # Sohle parallel zum Boden; eine feste Winkelangabe kippte die Fußspitze
        # nach oben (Fersenstand).
        if fuss_richtung.length() < 0.001:
            var zeh_i: int = skel.find_bone("mixamorig_%sToeBase" % seite)
            if zeh_i >= 0:
                fuss_richtung = (skel.get_bone_global_rest(zeh_i).origin
                        - skel.get_bone_global_rest(idx[foot]).origin).normalized()
        await _setze_richtung(foot, fuss_richtung, "mixamorig_%sToeBase" % seite)

    # Arme: Handziel = Position + Griffrichtung
    var haende: Array = k["haende"]
    var pol_arm: Array = k["pol_arm"]
    for seite in ["Left", "Right"]:
        var nr: int = 0 if seite == "Left" else 1
        var arm := "mixamorig_%sArm" % seite
        var unterarm := "mixamorig_%sForeArm" % seite
        var schulter: Vector3 = skel.get_bone_global_pose(idx[arm]).origin
        var ziel: Dictionary = _ziel_welt(haende[nr], schulter)
        var erg: Array = _ik2(schulter, ziel["pos"], float(laengen[arm]), float(laengen[unterarm]), pol_arm[nr])
        await _setze_richtung(arm, erg[1], unterarm)
        await _setze_richtung(unterarm, erg[2], "mixamorig_%sHand" % seite)
        var hfehler: Vector3 = (ziel["pos"] as Vector3) - skel.get_bone_global_pose(idx["mixamorig_%sHand" % seite]).origin
        if hfehler.length() > 0.002:
            erg = _ik2(schulter, (ziel["pos"] as Vector3) + hfehler, float(laengen[arm]), float(laengen[unterarm]), pol_arm[nr])
            await _setze_richtung(arm, erg[1], unterarm)
            await _setze_richtung(unterarm, erg[2], "mixamorig_%sHand" % seite)
        await _setze_hand_welt(seite, ziel["basis"])

    # Finger schließen sich um den Griff
    if k.has("griff_grad"):
        _finger_greifen("Left", float(k["griff_grad"]))
        _finger_greifen("Right", float(k["griff_grad"]))


# -----------------------------------------------------------------------------
#  Zwischen-Keys
# -----------------------------------------------------------------------------
## Füllt zwischen den Ankerpunkten Keys im Abstand "schritt". Nötig, weil die
## IK-Lösung zwischen zwei weit auseinanderliegenden Posen geradlinig
## interpoliert und dabei Füße in den Boden und Hände vom Gerät wandern.
func _raster(anker: Array, schritt: float) -> Array:
    var out: Array = []
    for i in anker.size():
        var a: Dictionary = anker[i]
        a["anker"] = true
        if i == anker.size() - 1:
            out.append(a)
            break
        var b: Dictionary = anker[i + 1]
        var t0: float = float(a["t"])
        var t1: float = float(b["t"])
        var n: int = maxi(int(ceil((t1 - t0) / schritt)), 1)
        for j in n:
            var k: Dictionary = _misch(a, b, float(j) / float(n))
            k["anker"] = (j == 0)
            out.append(k)
    return out


## Lineares Mischen zweier Keys (Vektoren, Zahlen, Listen und Handziel-Dicts).
func _misch(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
    var out: Dictionary = {}
    for key in a:
        out[key] = _wert_mischen(a[key], b.get(key, a[key]), f)
    out["t"] = lerpf(float(a["t"]), float(b["t"]), f)
    return out


func _wert_mischen(va: Variant, vb: Variant, f: float) -> Variant:
    if va is Vector3:
        return (va as Vector3).lerp(vb as Vector3, f)
    if va is float or va is int:
        return lerpf(float(va), float(vb), f)
    if va is Array:
        var liste: Array = []
        for i in (va as Array).size():
            liste.append(_wert_mischen(va[i], (vb as Array)[i], f))
        return liste
    if va is Dictionary:
        var d: Dictionary = {}
        for key in va:
            d[key] = _wert_mischen(va[key], (vb as Dictionary).get(key, va[key]), f)
        return d
    return va


# -----------------------------------------------------------------------------
#  Animation schreiben
# -----------------------------------------------------------------------------
func _baue(name: String, daten: Dictionary) -> Animation:
    var anim := Animation.new()
    anim.loop_mode = Animation.LOOP_LINEAR
    anim.step = 0.01
    anim.length = float(daten["dauer"])
    print("--- ", name)
    for k in _raster(daten["keys"], float(daten.get("schritt", 0.4))):
        await _pose_anwenden(k)
        _schreibe_key(anim, float(k["t"]))
        if bool(k.get("anker", false)):
            _diagnose(float(k["t"]), k)
    return anim


func _schreibe_key(anim: Animation, t: float) -> void:
    for n in KNOCHEN + fachse.keys():
        var i: int = int(idx[n]) if idx.has(n) else int(fidx[n])
        var pfad := NodePath("Skeleton3D:%s" % n)
        var track: int = anim.find_track(pfad, Animation.TYPE_ROTATION_3D)
        if track < 0:
            track = anim.add_track(Animation.TYPE_ROTATION_3D)
            anim.track_set_path(track, pfad)
        anim.rotation_track_insert_key(track, t, skel.get_bone_pose(i).basis.get_rotation_quaternion())

    var hips_pfad := NodePath("Skeleton3D:mixamorig_Hips")
    var ptrack: int = anim.find_track(hips_pfad, Animation.TYPE_POSITION_3D)
    if ptrack < 0:
        ptrack = anim.add_track(Animation.TYPE_POSITION_3D)
        anim.track_set_path(ptrack, hips_pfad)
    anim.position_track_insert_key(ptrack, t, skel.get_bone_pose(idx["mixamorig_Hips"]).origin)


# -----------------------------------------------------------------------------
#  Messwerte je Key (Grundlage der Abnahmekriterien)
# -----------------------------------------------------------------------------
func _diagnose(t: float, k: Dictionary) -> void:
    var hips: Vector3 = _p("mixamorig_Hips")
    var hals: Vector3 = _p("mixamorig_Neck")
    var kopf: Vector3 = _p("mixamorig_Head")
    var fuss_l: Vector3 = _p("mixamorig_LeftFoot")
    var fuss_r: Vector3 = _p("mixamorig_RightFoot")
    var kn_l: Vector3 = _p("mixamorig_LeftLeg")
    var kn_r: Vector3 = _p("mixamorig_RightLeg")
    var hf_l: Vector3 = _p("mixamorig_LeftUpLeg")
    var hf_r: Vector3 = _p("mixamorig_RightUpLeg")
    var sch_l: Vector3 = _p("mixamorig_LeftArm")
    var sch_r: Vector3 = _p("mixamorig_RightArm")
    var ellb_l: Vector3 = _p("mixamorig_LeftForeArm")
    var ellb_r: Vector3 = _p("mixamorig_RightForeArm")
    var hand_l: Transform3D = skel.get_bone_global_pose(idx["mixamorig_LeftHand"])
    var hand_r: Transform3D = skel.get_bone_global_pose(idx["mixamorig_RightHand"])

    # Soll/Ist des Griffs: Positionsabweichung und Verdrehung der Handfläche
    var haende: Array = k["haende"]
    var abw := [0.0, 0.0]
    var verdreht := [0.0, 0.0]
    var griff := [0.0, 0.0]
    var kanten := [_brust_ende(false), _brust_ende(true)]
    for nr in 2:
        var seite: String = "Left" if nr == 0 else "Right"
        var t_hand: Transform3D = skel.get_bone_global_pose(idx["mixamorig_%sHand" % seite])
        var schulter: Vector3 = skel.get_bone_global_pose(idx["mixamorig_%sArm" % seite]).origin
        var ziel: Dictionary = _ziel_welt(haende[nr], schulter)
        abw[nr] = t_hand.origin.distance_to(ziel["pos"])
        var soll: Basis = ziel["basis"]
        verdreht[nr] = rad_to_deg(acos(clampf(t_hand.basis.z.normalized().dot(soll.z.normalized()), -1.0, 1.0)))
        # Handfläche liegt im Handgelenk + halbe Fingerlänge (0,05 m) vorn
        var flaeche: Vector3 = t_hand.origin + t_hand.basis.y.normalized() * 0.05
        griff[nr] = minf(flaeche.distance_to(kanten[0]), flaeche.distance_to(kanten[1]))

    print("  t=%4.2f rumpf=%5.1f kopf=%5.1f knie=%3.0f/%3.0f fuss_y=%.3f/%.3f ellb=%3.0f/%3.0f abw=%.3f/%.3f palme=%3.0f/%3.0f griff=%.3f/%.3f knz=%.2f hz=%.2f hj=%.3f d=%.3f" % [
        t, _winkel_zur_senkrechten(_p("mixamorig_Spine2") - hips),
        _winkel_zwischen((kopf - hals).normalized(), skel.get_bone_global_pose(idx["mixamorig_Spine2"]).basis.y.normalized()) - kopf_ruhe,
        _beugung(hf_l, kn_l, fuss_l), _beugung(hf_r, kn_r, fuss_r),
        fuss_l.y, fuss_r.y,
        _beugung(sch_l, ellb_l, hand_l.origin), _beugung(sch_r, ellb_r, hand_r.origin),
        abw[0], abw[1], verdreht[0], verdreht[1], griff[0], griff[1], kn_l.z, hand_l.origin.z, hf_l.y, hf_l.distance_to(k["fuesse"][0] as Vector3),
    ])


func _p(name: String) -> Vector3:
    return skel.get_bone_global_pose(idx[name]).origin


## Oberes bzw. unteres Ende der senkrechten Brusthantel in Weltkoordinaten.
func _brust_ende(oben: bool) -> Vector3:
    var t: Transform3D = skel.get_bone_global_pose(idx["mixamorig_Spine2"])
    var b: Basis = t.basis.orthonormalized()
    return t.origin + b * (BRUST_MITTE + Vector3(0, BRUST_HALB if oben else -BRUST_HALB, 0))


## Beugewinkel in Grad: 0 = gestreckt, 180 = voll gefaltet.
func _beugung(a: Vector3, b: Vector3, c: Vector3) -> float:
    var v1: Vector3 = a - b
    var v2: Vector3 = c - b
    if v1.length() < 0.0001 or v2.length() < 0.0001:
        return 0.0
    return 180.0 - rad_to_deg(acos(clampf(v1.normalized().dot(v2.normalized()), -1.0, 1.0)))


## Winkel zwischen zwei Richtungen in Grad.
func _winkel_zwischen(a: Vector3, b: Vector3) -> float:
    return rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))


## Winkel einer Richtung gegen die Welt-Senkrechte in Grad (0 = aufrecht).
func _winkel_zur_senkrechten(v: Vector3) -> float:
    if v.length() < 0.0001:
        return 0.0
    return rad_to_deg(acos(clampf(v.normalized().dot(Vector3.UP), -1.0, 1.0)))

# -----------------------------------------------------------------------------
#  Übungsdaten
# -----------------------------------------------------------------------------
## Baut einen Keyframe: gemeinsame Felder + Bewegungsanteile des Ankerpunkts.
func _key(t: float, grund: Dictionary, hips: Vector3, hips_rot: Vector3, spine: Vector3, kopf: float) -> Dictionary:
    var k: Dictionary = grund.duplicate()
    k["t"] = t
    k["hips"] = hips
    k["hips_rot"] = hips_rot
    k["spine"] = spine
    k["kopf"] = Vector3(kopf, 0, 0)
    return k


## Goblet Squats – eine senkrechte Kurzhantel am Brustbein.
## Rechte Hand liegt oben auf dem oberen Hantelkopf, linke Hand stützt von
## unten gegen den unteren Kopf. Beide Griffe im Raum von Spine2, damit sie
## beim Absenken am Gerät bleiben.
func _daten_goblet() -> Dictionary:
    var oben := {"p": Vector3(-0.02, 0.132, 0.08), "rahmen": "brust", "finger": Vector3(0, 0, 1), "palme": Vector3(0, -1, 0)}
    var unten := {"p": Vector3(0.02, -0.237, 0.08), "rahmen": "brust", "finger": Vector3(0, 0, 1), "palme": Vector3(0, 1, 0)}
    var grund := {
        # Füße hüftbreit, Fersen bleiben am Boden; Knie folgen der Fußlinie.
        "fuesse": [Vector3(0.20, 0.128, -0.03), Vector3(-0.20, 0.128, -0.03)],
        "pol_knie": Vector3(0.45, 0, 1.0),
        # Ellbogen hängen nach unten und leicht nach außen.
        "pol_arm": [Vector3(0.9, -0.9, 0.35), Vector3(-0.9, -0.9, 0.35)],
        "haende": [unten, oben],
        "griff_grad": 72.0,
    }
    return {
        "dauer": 5.2,
        "schritt": 0.2,
        "keys": [
            _key(0.0, grund, Vector3(0, -0.015, 0), Vector3(8, 0, 0), Vector3(0, 0, 0), 0.0),
            _key(1.0, grund, Vector3(0, -0.13, -0.05), Vector3(14, 0, 0), Vector3(3, 0, 0), -2.0),
            _key(2.0, grund, Vector3(0, -0.30, -0.14), Vector3(20, 0, 0), Vector3(5, 0, 0), -3.0),
            _key(3.0, grund, Vector3(0, -0.42, -0.20), Vector3(26, 0, 0), Vector3(8, 0, 0), -5.0),
            _key(3.7, grund, Vector3(0, -0.42, -0.20), Vector3(26, 0, 0), Vector3(8, 0, 0), -5.0),
            _key(4.5, grund, Vector3(0, -0.20, -0.09), Vector3(15, 0, 0), Vector3(3, 0, 0), -2.0),
            _key(5.2, grund, Vector3(0, -0.015, 0), Vector3(8, 0, 0), Vector3(0, 0, 0), 0.0),
        ],
    }


## Rumänisches Kreuzheben – Hüftknick, Rücken bleibt als Linie gerade.
## Die Knie bleiben über die ganze Bewegung gleich leicht gebeugt; die Hanteln
## hängen senkrecht unter den Schultern und gleiten an den Beinen entlang.
func _daten_kreuzheben() -> Dictionary:
    var hand_l := {"p": Vector3(0.05, -0.492, -0.12), "rahmen": "schulter", "finger": Vector3(0, -1, 0), "palme": Vector3(-1, 0, 0)}
    var hand_r := {"p": Vector3(-0.05, -0.492, -0.12), "rahmen": "schulter", "finger": Vector3(0, -1, 0), "palme": Vector3(1, 0, 0)}
    var grund := {
        "fuesse": [Vector3(0.155, 0.128, -0.02), Vector3(-0.155, 0.128, -0.02)],
        "pol_knie": Vector3(0.12, 0, 1.0),
        "pol_arm": [Vector3(0.7, -1.0, -0.3), Vector3(-0.7, -1.0, -0.3)],
        "haende": [hand_l, hand_r],
        "griff_grad": 62.0,
    }
    return {
        "dauer": 2.4,
        "schritt": 0.25,
        "keys": [
            _key(0.0, grund, Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 0), -2.0),
            _key(0.8, grund, Vector3(0, -0.03, -0.13), Vector3(40, 0, 0), Vector3(2, 0, 0), -18.0),
            _key(1.5, grund, Vector3(0, -0.10, -0.22), Vector3(72, 0, 0), Vector3(3, 0, 0), -34.0),
            _key(1.9, grund, Vector3(0, -0.10, -0.22), Vector3(73, 0, 0), Vector3(3, 0, 0), -34.0),
            _key(2.4, grund, Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 0), -2.0),
        ],
    }


## Einarmiges Kurzhantel-Rudern – linkes Knie und linke Hand auf der Bank,
## rechtes Bein steht hinten am Boden, Rumpf fast waagerecht.
func _daten_rudern() -> Dictionary:
    var stuetze := {"p": Vector3(0.17, 0.49, 0.36), "rahmen": "welt", "finger": Vector3(0, 0, 1), "palme": Vector3(0, -1, 0)}
    var hand_unten := {"p": Vector3(-0.19, 0.405, 0.40), "rahmen": "welt", "finger": Vector3(0, -1, 0), "palme": Vector3(1, 0, 0)}
    var hand_oben := {"p": Vector3(-0.17, 0.78, 0.26), "rahmen": "welt", "finger": Vector3(-0.2, -1, 0), "palme": Vector3(1, 0, 0)}
    var basis := {
        # Linkes Knie auf dem Polster (Knöchel hängt dahinter), rechtes Bein hinten.
        "fuesse": [Vector3(0.19, 0.13, -0.23), Vector3(-0.16, 0.128, -0.15)],
        "pol_knie": Vector3(0.2, 0, 1.0),
        "fuss_richtung": [Vector3.ZERO, Vector3.ZERO],
        "pol_arm": [Vector3(0.8, -1.0, 0.2), Vector3(-0.8, -0.4, -0.6)],
        "griff_grad": 62.0,
    }
    var unten: Dictionary = basis.duplicate()
    unten["haende"] = [stuetze, hand_unten]
    var oben: Dictionary = basis.duplicate()
    oben["haende"] = [stuetze, hand_oben]
    var ruhig := Vector3(0, -0.10, 0.0)
    var dreh := Vector3(85, 0, 0)
    return {
        "dauer": 2.2,
        "keys": [
            _key(0.0, unten, ruhig, dreh, Vector3(0, 0, 0), -38.0),
            _key(0.6, oben, ruhig, dreh, Vector3(0, 0, 0), -38.0),
            _key(0.95, oben, ruhig, dreh, Vector3(0, 0, 0), -38.0),
            _key(1.7, unten, ruhig, dreh, Vector3(0, 0, 0), -38.0),
            _key(2.2, unten, ruhig, dreh, Vector3(0, 0, 0), -38.0),
        ],
    }


## Schulterdrücken – sitzend, Handflächen zeigen nach vorn (keine Torsion).
func _daten_schulterdruecken() -> Dictionary:
    var unten_l := {"p": Vector3(0.15, 0.0, 0.14), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var unten_r := {"p": Vector3(-0.15, 0.0, 0.14), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var oben_l := {"p": Vector3(0.15, 0.47, 0.05), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var oben_r := {"p": Vector3(-0.15, 0.47, 0.05), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var basis := {
        "fuesse": [Vector3(0.16, 0.128, 0.42), Vector3(-0.16, 0.128, 0.42)],
        "pol_knie": Vector3(0.3, 0, 1.0),
        # Ellbogen zeigen unten nach außen/vorn, oben leicht nach außen.
        "pol_arm": [Vector3(0.9, -0.5, 0.4), Vector3(-0.9, -0.5, 0.4)],
        "griff_grad": 62.0,
    }
    var unten: Dictionary = basis.duplicate()
    unten["haende"] = [unten_l, unten_r]
    var oben: Dictionary = basis.duplicate()
    oben["haende"] = [oben_l, oben_r]
    var sitz_hips := Vector3(0, -0.465, 0.02)
    var sitz_rot := Vector3(-6, 0, 0)
    return {
        "dauer": 3.0,
        "keys": [
            _key(0.0, unten, sitz_hips, sitz_rot, Vector3(0, 0, 0), -2.0),
            _key(1.4, oben, sitz_hips, sitz_rot, Vector3(0, 0, 0), -2.0),
            _key(1.7, oben, sitz_hips, sitz_rot, Vector3(0, 0, 0), -2.0),
            _key(3.0, unten, sitz_hips, sitz_rot, Vector3(0, 0, 0), -2.0),
        ],
    }


## Kurzhantel-Bankdrücken – liegend auf der Bank, Kopf zum Körper hin (Blick
## nach oben). Die Hanteln stehen quer zur Hand, Handflächen zeigen zu den Füßen.
func _daten_bankdruecken() -> Dictionary:
    var oben_l := {"p": Vector3(0.085, 0.487, 0.0), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var oben_r := {"p": Vector3(-0.085, 0.487, 0.0), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var unten_l := {"p": Vector3(0.16, 0.16, 0.02), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var unten_r := {"p": Vector3(-0.16, 0.16, 0.02), "rahmen": "schulter", "finger": Vector3(0, 1, 0), "palme": Vector3(0, 0, 1)}
    var basis := {
        "fuesse": [Vector3(0.15, 0.128, 0.52), Vector3(-0.15, 0.128, 0.52)],
        "pol_knie": Vector3(0.2, 0, 1.0),
        # Ellbogen gehen seitlich und Richtung Füße weg, nicht nach hinten über den Kopf.
        "pol_arm": [Vector3(1.0, -0.35, 0.55), Vector3(-1.0, -0.35, 0.55)],
        "griff_grad": 62.0,
    }
    var oben: Dictionary = basis.duplicate()
    oben["haende"] = [oben_l, oben_r]
    var unten: Dictionary = basis.duplicate()
    unten["haende"] = [unten_l, unten_r]
    var lage := Vector3(0, -0.46, -0.02)
    var kipp := Vector3(-88, 0, 0)
    return {
        "dauer": 3.0,
        "keys": [
            _key(0.0, oben, lage, kipp, Vector3(0, 0, 0), 0.0),
            _key(0.9, unten, lage, kipp, Vector3(0, 0, 0), 0.0),
            _key(1.25, unten, lage, kipp, Vector3(0, 0, 0), 0.0),
            _key(2.6, oben, lage, kipp, Vector3(0, 0, 0), 0.0),
            _key(3.0, oben, lage, kipp, Vector3(0, 0, 0), 0.0),
        ],
    }

