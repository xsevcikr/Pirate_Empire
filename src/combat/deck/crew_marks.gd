class_name CrewMarks
extends RefCounted
## What life at sea has done to a pirate, and what he carries: an eye patch, a head bandage, a bound arm, a wooden
## leg, a hook, an earring, a scar, a powder horn, a bandolier and a pistol in the belt. The set is chosen from the
## fighter's id, so the same man always looks the same. The player's captain keeps a clean face.

const WOOD_C: Color = Color(0.42, 0.27, 0.14)
const CLOTH_C: Color = Color(0.86, 0.82, 0.7)
const BLOOD_C: Color = Color(0.55, 0.1, 0.08)
const BRASS_C: Color = Color(0.8, 0.62, 0.2)
const IRON_C: Color = Color(0.18, 0.18, 0.2)

## chance of each mark, by kind; marines and officers are kept tidy
const CHANCE: Dictionary = {
	"patch": {"crew": 0.16, "sailor": 0.14, "brute": 0.3, "captain": 0.4, "marine": 0.02, "officer": 0.04, "captain_player": 0.0},
	"head_bandage": {"crew": 0.14, "sailor": 0.12, "brute": 0.25, "captain": 0.1, "marine": 0.06, "officer": 0.02, "captain_player": 0.0},
	"arm_bandage": {"crew": 0.18, "sailor": 0.16, "brute": 0.3, "captain": 0.08, "marine": 0.08, "officer": 0.02, "captain_player": 0.0},
	"peg": {"crew": 0.08, "sailor": 0.07, "brute": 0.12, "captain": 0.15, "marine": 0.0, "officer": 0.0, "captain_player": 0.0},
	"hook": {"crew": 0.04, "sailor": 0.03, "brute": 0.08, "captain": 0.12, "marine": 0.0, "officer": 0.0, "captain_player": 0.0},
	"scar": {"crew": 0.3, "sailor": 0.25, "brute": 0.6, "captain": 0.4, "marine": 0.1, "officer": 0.05, "captain_player": 0.0},
	"earring": {"crew": 0.25, "sailor": 0.25, "brute": 0.15, "captain": 0.35, "marine": 0.0, "officer": 0.0, "captain_player": 0.0},
}


## Which marks this man has. Pure, so tests can check the odds.
static func roll(seed_i: int, kind: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 2654435761 + 17
	var out: Dictionary = {}
	for k: String in CHANCE.keys():
		out[k] = rng.randf() < float(CHANCE[k].get(kind, 0.1))
	out["side"] = 1.0 if rng.randf() < 0.5 else -1.0  # which side the patch and the scar are on
	out["horn"] = rng.randf() < 0.45
	out["bandolier"] = rng.randf() < 0.3 and kind in ["crew", "sailor", "brute", "captain"]
	out["pistol_belt"] = rng.randf() < 0.55
	return out


static func _m(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	return DeckArt.plain(c, rough, metal)


static func dress(head: Node3D, hips: Node3D, leg_r: Node3D, arm_l: Node3D, arm_r: Node3D, marks: Dictionary, skin: Material) -> void:
	var side: float = float(marks["side"])
	if marks["patch"]:
		var patch := DeckArt.add_mesh(head, _disc(0.045), _m(Color(0.04, 0.04, 0.05), 0.9), Vector3(side * 0.055, 0.025, 0.148), Vector3(0, 0, 0))
		patch.scale = Vector3(1, 1, 0.4)
		var strap := DeckArt.add_mesh(head, DeckArt.cyl(0.158, 0.158, 0.018, 16), _m(Color(0.04, 0.04, 0.05), 0.9), Vector3(0, 0.045, 0), Vector3(0, 0, side * 14.0))
		strap.scale = Vector3(1, 1, 1)
	if marks["head_bandage"]:
		var wrap := DeckArt.add_mesh(head, DeckArt.cyl(0.162, 0.162, 0.07, 14), _m(CLOTH_C, 0.95), Vector3(0, 0.09, 0))
		wrap.rotation_degrees.z = side * 8.0
		DeckArt.add_mesh(head, DeckArt.cyl(0.164, 0.164, 0.012, 14), _m(BLOOD_C, 0.9), Vector3(side * 0.01, 0.075, 0.0), Vector3(0, 0, side * 8.0))
		var knot := DeckArt.add_mesh(head, _blob(0.035), _m(CLOTH_C, 0.95), Vector3(-side * 0.14, 0.09, -0.06))
		knot.scale = Vector3(1.0, 0.7, 1.3)
	if marks["scar"]:
		var scar := DeckArt.add_mesh(head, DeckArt.box(Vector3(0.008, 0.11, 0.01)), _m(Color(0.62, 0.3, 0.26), 0.6), Vector3(-side * 0.065, -0.015, 0.148), Vector3(0, 0, 18.0))
		scar.name = "Scar"
	if marks["earring"]:
		var ring := DeckArt.add_mesh(head, _torus(0.022, 0.004), _m(BRASS_C, 0.3, 0.9), Vector3(side * 0.155, -0.04, 0.0), Vector3(0, 90, 0))
		ring.name = "Earring"
	if marks["arm_bandage"]:
		var wrap := DeckArt.add_mesh(arm_l, DeckArt.cyl(0.088, 0.082, 0.22, 12), _m(CLOTH_C, 0.95), Vector3(0, -0.3, 0.17), Vector3(-35, 0, 0))
		wrap.name = "ArmWrap"
		DeckArt.add_mesh(arm_l, DeckArt.cyl(0.09, 0.09, 0.015, 12), _m(BLOOD_C, 0.9), Vector3(0, -0.32, 0.18), Vector3(-35, 0, 0))
	if marks["hook"]:
		_hook(arm_l)
	if marks["peg"]:
		_peg(leg_r)
	if marks["bandolier"]:
		var band := DeckArt.add_mesh(hips, DeckArt.box(Vector3(0.07, 0.78, 0.02)), _m(Color(0.22, 0.14, 0.08), 0.7), Vector3(0.0, 0.42, 0.175), Vector3(0, 0, -34.0))
		band.name = "Bandolier"
		for i in 4:
			DeckArt.add_mesh(hips, DeckArt.cyl(0.018, 0.018, 0.07, 6), _m(BRASS_C, 0.4, 0.8), Vector3(-0.12 + 0.075 * i, 0.22 + 0.13 * i, 0.19), Vector3(0, 0, -34.0))
	# belt, buckle, pouch
	var belt := DeckArt.add_mesh(hips, DeckArt.cyl(0.255, 0.255, 0.045, 14), _m(Color(0.16, 0.1, 0.06), 0.7), Vector3(0, 0.07, 0))
	belt.scale = Vector3(1, 1, 0.78)
	DeckArt.add_mesh(hips, DeckArt.box(Vector3(0.06, 0.05, 0.015)), _m(BRASS_C, 0.3, 0.9), Vector3(0, 0.07, 0.205))
	DeckArt.add_mesh(hips, DeckArt.box(Vector3(0.09, 0.1, 0.05)), _m(Color(0.25, 0.16, 0.09), 0.8), Vector3(-0.2, 0.0, 0.1))
	if marks["horn"]:
		var horn := DeckArt.add_mesh(hips, _blob(0.05), _m(Color(0.88, 0.8, 0.62), 0.6), Vector3(0.22, 0.02, 0.08))
		horn.scale = Vector3(0.7, 1.7, 0.7)
		horn.rotation_degrees.z = 18.0
		horn.name = "PowderHorn"
	if marks["pistol_belt"]:
		_pistol(hips)


static func _pistol(hips: Node3D) -> void:
	var p := Node3D.new()
	p.name = "BeltPistol"
	p.position = Vector3(0.2, 0.05, 0.13)
	p.rotation_degrees = Vector3(0, 0, 70.0)
	hips.add_child(p)
	DeckArt.add_mesh(p, DeckArt.cyl(0.014, 0.018, 0.26, 8), _m(IRON_C, 0.35, 0.8), Vector3(0, 0.12, 0))
	DeckArt.add_mesh(p, DeckArt.box(Vector3(0.035, 0.1, 0.05)), _m(WOOD_C, 0.6), Vector3(0, -0.04, 0), Vector3(0, 0, 14.0))
	DeckArt.add_mesh(p, DeckArt.box(Vector3(0.03, 0.04, 0.03)), _m(BRASS_C, 0.3, 0.9), Vector3(0, 0.0, 0.02))


static func _hook(arm: Node3D) -> void:
	var steel: StandardMaterial3D = _m(Color(0.75, 0.78, 0.82), 0.25, 0.9)
	var h := Node3D.new()
	h.name = "Hook"
	h.position = Vector3(0, -0.52, 0.28)
	arm.add_child(h)
	DeckArt.add_mesh(h, DeckArt.cyl(0.05, 0.04, 0.08, 10), _m(Color(0.25, 0.15, 0.08), 0.7), Vector3(0, 0, 0))
	DeckArt.add_mesh(h, DeckArt.cyl(0.012, 0.012, 0.14, 6), steel, Vector3(0, -0.1, 0))
	DeckArt.add_mesh(h, DeckArt.cyl(0.01, 0.006, 0.08, 6), steel, Vector3(0, -0.2, 0.03), Vector3(-40, 0, 0))
	DeckArt.add_mesh(h, DeckArt.cyl(0.006, 0.002, 0.05, 6), steel, Vector3(0, -0.22, 0.07), Vector3(-100, 0, 0))


## A wooden leg below the knee: the thigh in trousers, a strap, a tapering peg of turned wood.
static func _peg(leg: Node3D) -> void:
	for c in leg.get_children():
		c.queue_free()
	var cloth: StandardMaterial3D = _m(Color(0.32, 0.26, 0.2), 0.9)
	var wood: StandardMaterial3D = _m(WOOD_C, 0.7)
	var thigh := DeckArt.add_mesh(leg, _caps(0.1, 0.5), cloth, Vector3(0, -0.2, 0.04), Vector3(-8, 0, 0))
	thigh.name = "Thigh"
	DeckArt.add_mesh(leg, DeckArt.cyl(0.105, 0.105, 0.05, 10), _m(Color(0.16, 0.1, 0.06), 0.7), Vector3(0, -0.4, 0.06))
	var peg := DeckArt.add_mesh(leg, DeckArt.cyl(0.055, 0.025, 0.55, 10), wood, Vector3(0, -0.66, 0.03))
	peg.name = "PegLeg"
	DeckArt.add_mesh(leg, DeckArt.cyl(0.07, 0.07, 0.04, 10), _m(BRASS_C, 0.35, 0.8), Vector3(0, -0.46, 0.05))
	DeckArt.add_mesh(leg, DeckArt.cyl(0.032, 0.032, 0.03, 10), _m(IRON_C, 0.4, 0.7), Vector3(0, -0.92, 0.03))


static func _disc(r: float) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _blob(r: float) -> Mesh:
	return _disc(r)


static func _caps(r: float, h: float) -> Mesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 3
	return c


static func _torus(outer: float, inner: float) -> Mesh:
	var t := TorusMesh.new()
	t.outer_radius = outer
	t.inner_radius = outer - inner * 2.0
	t.rings = 12
	t.ring_segments = 6
	return t


# ---- faces, boots and coats --------------------------------------------------------------------------

const HAIR: Array[Color] = [Color(0.1, 0.07, 0.05), Color(0.28, 0.17, 0.09), Color(0.5, 0.36, 0.17), Color(0.62, 0.6, 0.58), Color(0.04, 0.04, 0.05)]


## Eyes with whites and brows, a nose, a mouth, ears, hair and a ponytail, from the man's seed.
static func face(head: Node3D, skin: Material, seed_i: int, beard: bool, covered: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 40503 + 5
	var hair_c: Color = HAIR[rng.randi_range(0, HAIR.size() - 1)]
	var hair: StandardMaterial3D = _m(hair_c, 0.95)
	for ex in [-0.055, 0.055]:
		var white := DeckArt.add_mesh(head, _disc(0.028), _m(Color(0.95, 0.94, 0.9), 0.4), Vector3(ex, 0.03, 0.125))
		white.scale = Vector3(1.0, 0.8, 0.5)
		var pupil := DeckArt.add_mesh(head, _disc(0.014), _m(Color(0.07, 0.05, 0.04), 0.3), Vector3(ex, 0.03, 0.14))
		pupil.scale = Vector3(1, 1, 0.5)
		var brow := DeckArt.add_mesh(head, DeckArt.box(Vector3(0.06, 0.012, 0.015)), hair, Vector3(ex, 0.075, 0.138), Vector3(0, 0, -ex * 120.0))
		brow.name = "Brow"
	var nose := DeckArt.add_mesh(head, _disc(0.03), skin, Vector3(0, -0.015, 0.15))
	nose.scale = Vector3(0.8, 1.2, 1.0)
	nose.name = "Nose"
	DeckArt.add_mesh(head, DeckArt.box(Vector3(0.06, 0.008, 0.012)), _m(Color(0.45, 0.2, 0.18), 0.6), Vector3(0, -0.07, 0.135))
	for side in [-1.0, 1.0]:
		var ear := DeckArt.add_mesh(head, _disc(0.03), skin, Vector3(side * 0.152, 0.0, 0.0))
		ear.scale = Vector3(0.4, 1.0, 0.8)
	if not covered:
		var cap := DeckArt.add_mesh(head, _disc(0.162), hair, Vector3(0, 0.025, -0.012))
		cap.scale = Vector3(1.0, 0.95, 1.05)
		cap.name = "Hair"
	var tail := DeckArt.add_mesh(head, _caps(0.035, 0.2), hair, Vector3(0, -0.06, -0.17), Vector3(25, 0, 0))
	tail.name = "Ponytail"
	if not beard and rng.randf() < 0.4:  # stubble
		var jaw := DeckArt.add_mesh(head, _disc(0.14), _m(hair_c.lerp(Color(0.7, 0.55, 0.45), 0.6), 1.0), Vector3(0, -0.07, 0.04))
		jaw.scale = Vector3(1.0, 0.7, 0.85)


## A boot: foot, heel, shaft and a turned-over cuff.
static func boot(leg: Node3D, mat: Material) -> void:
	DeckArt.add_mesh(leg, DeckArt.box(Vector3(0.17, 0.11, 0.34)), mat, Vector3(0, -0.84, 0.07))
	DeckArt.add_mesh(leg, DeckArt.cyl(0.095, 0.085, 0.3, 10), mat, Vector3(0, -0.68, 0.0))
	DeckArt.add_mesh(leg, DeckArt.cyl(0.125, 0.105, 0.09, 10), mat, Vector3(0, -0.55, 0.0))
	DeckArt.add_mesh(leg, DeckArt.box(Vector3(0.17, 0.04, 0.09)), _m(Color(0.07, 0.05, 0.04), 0.9), Vector3(0, -0.89, -0.07))
	DeckArt.add_mesh(leg, DeckArt.box(Vector3(0.05, 0.04, 0.012)), _m(BRASS_C, 0.3, 0.9), Vector3(0, -0.55, 0.12))


## Collar, a row of buttons, cuffs and coat tails on the long coats.
static func coat(hips: Node3D, arm_l: Node3D, arm_r: Node3D, coat_mat: Material, long_coat: bool, trim: Color) -> void:
	var collar := DeckArt.add_mesh(hips, DeckArt.cyl(0.14, 0.17, 0.07, 12), coat_mat, Vector3(0, 0.78, 0.0))
	collar.scale = Vector3(1, 1, 0.9)
	DeckArt.add_mesh(hips, DeckArt.cyl(0.125, 0.125, 0.05, 12), _m(Color(0.9, 0.88, 0.8), 0.9), Vector3(0, 0.78, 0.01))
	for i in 5:
		DeckArt.add_mesh(hips, _disc(0.012), _m(BRASS_C, 0.3, 0.9), Vector3(0.0, 0.2 + 0.12 * i, 0.172))
	for arm in [arm_l, arm_r]:
		var cuff := DeckArt.add_mesh(arm, DeckArt.cyl(0.088, 0.082, 0.07, 10), _m(trim, 0.7), Vector3(0, -0.45, 0.2), Vector3(-35, 0, 0))
		cuff.name = "Cuff"
		DeckArt.add_mesh(arm, _disc(0.085), coat_mat, Vector3(0, 0.0, 0.0))
	if long_coat:
		for side in [-1.0, 1.0]:
			var tail := DeckArt.add_mesh(hips, DeckArt.box(Vector3(0.18, 0.5, 0.04)), coat_mat, Vector3(side * 0.1, -0.2, -0.17), Vector3(8, 0, side * 4.0))
			tail.name = "CoatTail"
