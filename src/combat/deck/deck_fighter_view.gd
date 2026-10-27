class_name DeckFighterView
extends Node3D
## A jointed pirate built from primitives: boots, legs, coat, sash, head, hat, a weapon arm and a guard arm.
## The look follows the fighter's kind; poses follow its state each frame.

const KIND_SCALE: Dictionary = {"brute": 1.22, "captain": 1.08, "captain_player": 1.05, "sailor": 0.97}
const SWING_ARC_DEG: float = 130.0
const SKIN: Array[Color] = [Color(0.86, 0.66, 0.5), Color(0.72, 0.52, 0.37), Color(0.5, 0.34, 0.24), Color(0.92, 0.74, 0.6)]
## coat, trousers, sash, hat style (0 none/bandana, 1 tricorn, 2 cap, 3 plumed, 4 bicorne), beard
const LOOKS: Dictionary = {
	"captain_player": {"coat": Color(0.1, 0.16, 0.2), "legs": Color(0.12, 0.1, 0.1), "sash": Color(0.95, 0.8, 0.25), "hat": 3, "beard": true},
	"crew": {"coat": Color(0.82, 0.78, 0.66), "legs": Color(0.32, 0.26, 0.2), "sash": Color(0.2, 0.35, 0.65), "hat": 0, "beard": false},
	"sailor": {"coat": Color(0.62, 0.5, 0.38), "legs": Color(0.45, 0.4, 0.34), "sash": Color(0.5, 0.15, 0.12), "hat": 2, "beard": false},
	"marine": {"coat": Color(0.72, 0.14, 0.12), "legs": Color(0.86, 0.84, 0.78), "sash": Color(0.9, 0.9, 0.86), "hat": 1, "beard": false},
	"officer": {"coat": Color(0.12, 0.2, 0.45), "legs": Color(0.88, 0.86, 0.8), "sash": Color(0.85, 0.7, 0.2), "hat": 4, "beard": false},
	"brute": {"coat": Color(0.45, 0.3, 0.22), "legs": Color(0.2, 0.17, 0.15), "sash": Color(0.15, 0.12, 0.1), "hat": 0, "beard": true},
	"captain": {"coat": Color(0.08, 0.08, 0.1), "legs": Color(0.1, 0.1, 0.12), "sash": Color(0.7, 0.1, 0.1), "hat": 3, "beard": true},
	"peasant": {"coat": Color(0.5, 0.4, 0.28), "legs": Color(0.3, 0.26, 0.2), "sash": Color(0.4, 0.3, 0.2), "hat": 5, "beard": false},
	"merchant": {"coat": Color(0.45, 0.12, 0.16), "legs": Color(0.15, 0.12, 0.1), "sash": Color(0.85, 0.7, 0.2), "hat": 4, "beard": true},
	"townswoman": {"coat": Color(0.3, 0.38, 0.5), "legs": Color(0.3, 0.38, 0.5), "sash": Color(0.8, 0.75, 0.6), "hat": 5, "beard": false, "dress": true},
	"guard": {"coat": Color(0.35, 0.37, 0.4), "legs": Color(0.25, 0.22, 0.2), "sash": Color(0.6, 0.12, 0.1), "hat": 6, "beard": false},
}
const CREW_VESTS: Dictionary = {
	"swordsman": Color(0.2, 0.28, 0.5), "seasoned": Color(0.55, 0.42, 0.3), "gunner": Color(0.4, 0.2, 0.18),
	"musketeer": Color(0.3, 0.36, 0.28), "bosun": Color(0.45, 0.3, 0.2),
}

var fighter: FighterState
var show_label: bool = true
var pose_idle_only: bool = false  ## ship-board crew: no fight, only breathing and a slow turn
var _body: Node3D
var _hips: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _shield: MeshInstance3D
var _label: Label3D
var _mats: Array[StandardMaterial3D] = []
var _skin_mat: StandardMaterial3D
var _flash_left: float = 0.0
var _flash_color: Color = Color.WHITE
var _last_pos: Vector2
var _stride: float = 0.0
var _speed: float = 0.0


func _ready() -> void:
	var look: Dictionary = LOOKS.get(fighter.kind, LOOKS["crew"])
	var coat: Color = look["coat"]
	if fighter.kind == "crew" and CREW_VESTS.has(fighter.crew_type):
		coat = CREW_VESTS[fighter.crew_type]
	var seed_i: int = fighter.id * 7919
	_skin_mat = _mat(SKIN[seed_i % SKIN.size()], 0.7)
	var coat_mat: StandardMaterial3D = _mat(coat, 0.85)
	var legs_mat: StandardMaterial3D = _mat(look["legs"], 0.9)
	var boots_mat: StandardMaterial3D = _mat(Color(0.12, 0.08, 0.06), 0.6)
	var sash_mat: StandardMaterial3D = _mat(look["sash"], 0.7)
	_body = Node3D.new()
	add_child(_body)
	_hips = Node3D.new()
	_hips.position.y = 0.92
	_body.add_child(_hips)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.13, 0.0, 0.0)
		_hips.add_child(leg)
		DeckArt.add_mesh(leg, _capsule(0.1, 0.9), legs_mat, Vector3(0, -0.4, 0))
		CrewMarks.boot(leg, boots_mat)
		if side < 0.0:
			_leg_l = leg
		else:
			_leg_r = leg
	var torso: MeshInstance3D = DeckArt.add_mesh(_hips, _capsule(0.23, 0.78), coat_mat, Vector3(0, 0.38, 0))
	torso.scale = Vector3(1.0, 1.0, 0.72)
	if bool(look.get("dress", false)):
		var gown: MeshInstance3D = DeckArt.add_mesh(_hips, DeckArt.cyl(0.24, 0.5, 1.05, 14), coat_mat, Vector3(0, -0.4, 0))
		gown.name = "Gown"
		gown.scale = Vector3(1.0, 1.0, 0.9)
		DeckArt.add_mesh(_hips, DeckArt.cyl(0.505, 0.505, 0.05, 14), _mat(look["sash"], 0.8), Vector3(0, -0.9, 0))
	if fighter.kind in ["marine", "officer", "captain", "captain_player"]:
		var skirt: MeshInstance3D = DeckArt.add_mesh(_hips, DeckArt.cyl(0.22, 0.3, 0.45, 12), coat_mat, Vector3(0, -0.02, 0))
		skirt.scale = Vector3(1.0, 1.0, 0.8)
	DeckArt.add_mesh(_hips, DeckArt.cyl(0.25, 0.25, 0.1, 12), sash_mat, Vector3(0, 0.12, 0)).scale = Vector3(1.0, 1.0, 0.78)
	if fighter.kind == "marine" or fighter.kind == "officer":
		var strap := DeckArt.add_mesh(_hips, DeckArt.box(Vector3(0.08, 0.7, 0.03)), _mat(Color(0.92, 0.92, 0.88), 0.8), Vector3(0.0, 0.42, 0.17), Vector3(0, 0, 28))
		strap.name = "Strap"
	# head
	var head: MeshInstance3D = DeckArt.add_mesh(_hips, _sphere(0.155), _skin_mat, Vector3(0, 0.95, 0.02))
	head.name = "Head"
	CrewMarks.face(head, _skin_mat, seed_i, bool(look["beard"]), int(look["hat"]) != 0 or fighter.kind == "marine")
	if look["beard"]:
		var beard: MeshInstance3D = DeckArt.add_mesh(head, _sphere(0.12), _mat(Color(0.12, 0.09, 0.07) if seed_i % 2 == 0 else Color(0.45, 0.42, 0.4), 0.95), Vector3(0, -0.1, 0.07))
		beard.scale = Vector3(1.0, 1.2, 0.8)
	_hat(head, int(look["hat"]), look["sash"])
	# arms
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.3, 0.72, 0.0)
	_hips.add_child(_arm_r)
	DeckArt.add_mesh(_arm_r, _capsule(0.075, 0.6), coat_mat, Vector3(0, -0.25, 0.1), Vector3(-40, 0, 0))
	_weapon(_arm_r)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.3, 0.72, 0.0)
	_hips.add_child(_arm_l)
	DeckArt.add_mesh(_arm_l, _capsule(0.075, 0.6), coat_mat, Vector3(0, -0.25, 0.1), Vector3(-30, 0, 0))
	DeckArt.add_mesh(_arm_l, _sphere(0.07), _skin_mat, Vector3(0, -0.52, 0.28))
	if fighter.ranged != "" and fighter.kind != "captain_player":
		_gun(_arm_l)
	CrewMarks.coat(_hips, _arm_l, _arm_r, coat_mat, fighter.kind in ["marine", "officer", "captain", "captain_player", "brute"], look["sash"])
	CrewMarks.dress(head, _hips, _leg_r, _arm_l, _arm_r, CrewMarks.roll(seed_i, fighter.kind), _skin_mat)
	_shield = DeckArt.add_mesh(_hips, DeckArt.cyl(0.0, 0.0, 0.0, 3), _mat(Color(0.55, 0.57, 0.6), 0.4, 0.8), Vector3.ZERO)
	_shield.mesh = _guard_mesh()
	_shield.position = Vector3(0.0, 0.6, 0.42)
	_shield.visible = false
	if fighter.is_player:
		var ring: MeshInstance3D = DeckArt.add_mesh(self, DeckArt.cyl(0.62, 0.62, 0.02, 24), _glow(Color(1.0, 0.8, 0.25)), Vector3(0, 0.03, 0))
		ring.name = "Ring"
	_label = Label3D.new()
	_label.visible = show_label
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 18
	_label.pixel_size = 0.01
	_label.no_depth_test = true
	_label.outline_size = 6
	_label.position.y = 2.45
	add_child(_label)
	var s: float = KIND_SCALE.get(fighter.kind, 1.0)
	scale = Vector3.ONE * s
	_last_pos = fighter.pos
	_sync(0.0)


func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = DeckArt.plain(c, rough, metal)
	_mats.append(m)
	return m


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


func _hat(head: Node3D, style: int, accent: Color) -> void:
	var felt: StandardMaterial3D = _mat(Color(0.1, 0.08, 0.08), 0.9)
	match style:
		0:  # bandana
			var band: MeshInstance3D = DeckArt.add_mesh(head, _sphere(0.165), _mat(accent, 0.8), Vector3(0, 0.05, -0.005))
			band.scale = Vector3(1.0, 0.55, 1.0)
		1, 3, 4:  # tricorn, plumed, bicorne
			var brim: MeshInstance3D = DeckArt.add_mesh(head, DeckArt.cyl(0.3, 0.3, 0.04, 3 if style != 4 else 6), felt, Vector3(0, 0.15, 0), Vector3(0, 30 if style != 4 else 0, 0))
			brim.scale = Vector3(1.0, 1.0, 1.15)
			DeckArt.add_mesh(head, DeckArt.cyl(0.14, 0.17, 0.17, 12), felt, Vector3(0, 0.25, 0))
			DeckArt.add_mesh(head, DeckArt.cyl(0.175, 0.175, 0.04, 12), _mat(accent, 0.6, 0.3), Vector3(0, 0.2, 0))
			if style == 3:
				var plume: MeshInstance3D = DeckArt.add_mesh(head, _sphere(0.1), _mat(Color(0.8, 0.12, 0.1), 0.9), Vector3(0.18, 0.32, -0.05))
				plume.scale = Vector3(0.5, 1.4, 1.0)
				plume.rotation_degrees.z = -30.0
		5:  # coif or headscarf
			var coif: MeshInstance3D = DeckArt.add_mesh(head, _sphere(0.168), _mat(Color(0.88, 0.84, 0.74) if fighter.id % 2 == 0 else accent.lightened(0.2), 0.95), Vector3(0, 0.04, -0.012))
			coif.scale = Vector3(1.0, 0.9, 1.08)
			DeckArt.add_mesh(head, _sphere(0.07), _mat(Color(0.88, 0.84, 0.74), 0.95), Vector3(0, -0.04, -0.17))
		6:  # steel morion
			var steel: StandardMaterial3D = _mat(Color(0.62, 0.64, 0.68), 0.35, 0.8)
			var helm: MeshInstance3D = DeckArt.add_mesh(head, _sphere(0.17), steel, Vector3(0, 0.07, -0.005))
			helm.scale = Vector3(1.0, 0.85, 1.1)
			DeckArt.add_mesh(head, DeckArt.cyl(0.27, 0.22, 0.03, 14), steel, Vector3(0, 0.1, 0.0))
			DeckArt.add_mesh(head, DeckArt.box(Vector3(0.02, 0.1, 0.32)), steel, Vector3(0, 0.25, 0.0))
		2:  # knit cap
			var cap: MeshInstance3D = DeckArt.add_mesh(head, _sphere(0.17), _mat(Color(0.2, 0.28, 0.4), 0.95), Vector3(0, 0.06, -0.01))
			cap.scale = Vector3(1.0, 0.8, 1.05)


func _weapon(arm: Node3D) -> void:
	var steel: StandardMaterial3D = _mat(Color(0.82, 0.85, 0.9), 0.25, 0.9)
	var grip: StandardMaterial3D = _mat(Color(0.3, 0.18, 0.1), 0.7)
	DeckArt.add_mesh(arm, _sphere(0.07), _skin_mat, Vector3(0, -0.52, 0.28))
	var w := Node3D.new()
	w.name = "Weapon"
	w.position = Vector3(0, -0.52, 0.3)
	arm.add_child(w)
	match fighter.melee:
		"boarding_axe", "club":
			DeckArt.add_mesh(w, DeckArt.cyl(0.03, 0.035, 0.9, 6), grip, Vector3(0, 0.0, 0.3), Vector3(90, 0, 0))
			if fighter.melee == "boarding_axe":
				DeckArt.add_mesh(w, DeckArt.box(Vector3(0.04, 0.3, 0.22)), steel, Vector3(0, 0.1, 0.62))
			else:
				var knob: MeshInstance3D = DeckArt.add_mesh(w, _sphere(0.09), grip, Vector3(0, 0, 0.7))
				knob.scale = Vector3(1, 1, 1.5)
		"bayonet", "musket":
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.04, 0.05, 1.0)), _mat(Color(0.25, 0.15, 0.08), 0.6), Vector3(0, 0, 0.4))
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.015, 0.03, 0.4)), steel, Vector3(0, 0, 1.08))
		"none":
			pass
		"halberd":
			DeckArt.add_mesh(w, DeckArt.cyl(0.025, 0.025, 2.1, 6), grip, Vector3(0, 0.0, 0.2), Vector3(90, 0, 0))
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.03, 0.28, 0.3)), steel, Vector3(0, 0.12, 1.1))
			DeckArt.add_mesh(w, DeckArt.cyl(0.0, 0.03, 0.3, 6), steel, Vector3(0, 0, 1.4), Vector3(90, 0, 0))
		"dagger":
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.025, 0.05, 0.3)), steel, Vector3(0, 0, 0.3))
		"rapier":
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.012, 0.025, 1.0)), steel, Vector3(0, 0, 0.55))
			DeckArt.add_mesh(w, DeckArt.cyl(0.08, 0.08, 0.01, 10), steel, Vector3(0, 0, 0.08), Vector3(90, 0, 0))
		_:  # cutlass and friends: curved blade from two segments
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.02, 0.07, 0.5)), steel, Vector3(0, 0.0, 0.34))
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.02, 0.07, 0.3)), steel, Vector3(0, -0.05, 0.72), Vector3(14, 0, 0))
			DeckArt.add_mesh(w, DeckArt.box(Vector3(0.05, 0.14, 0.03)), _mat(Color(0.8, 0.65, 0.2), 0.4, 0.7), Vector3(0, 0, 0.09))


## A flintlock pistol or a long musket: iron barrel, wooden stock, brass fittings, the cock and the pan.
func _gun(arm: Node3D) -> void:
	var long: bool = fighter.ranged != "flintlock"
	var iron: StandardMaterial3D = _mat(Color(0.18, 0.18, 0.2), 0.35, 0.85)
	var wood: StandardMaterial3D = _mat(Color(0.32, 0.19, 0.1), 0.55)
	var brass: StandardMaterial3D = _mat(Color(0.8, 0.62, 0.2), 0.3, 0.9)
	var g := Node3D.new()
	g.name = "Gun"
	g.position = Vector3(0, -0.5, 0.45)
	arm.add_child(g)
	var len: float = 1.0 if long else 0.32
	DeckArt.add_mesh(g, DeckArt.cyl(0.017, 0.02, len, 8), iron, Vector3(0, 0.02, len * 0.5), Vector3(90, 0, 0))
	DeckArt.add_mesh(g, DeckArt.box(Vector3(0.05, 0.08, 0.3 if long else 0.14)), wood, Vector3(0, -0.02, -0.02))
	DeckArt.add_mesh(g, DeckArt.box(Vector3(0.045, 0.14, 0.07)), wood, Vector3(0, -0.1, -0.12), Vector3(-25, 0, 0))
	DeckArt.add_mesh(g, DeckArt.box(Vector3(0.04, 0.04, 0.05)), iron, Vector3(0, 0.05, 0.08))
	DeckArt.add_mesh(g, DeckArt.box(Vector3(0.015, 0.07, 0.025)), iron, Vector3(0, 0.1, 0.05), Vector3(-30, 0, 0))
	for i in (3 if long else 1):
		DeckArt.add_mesh(g, DeckArt.cyl(0.024, 0.024, 0.015, 8), brass, Vector3(0, 0.02, 0.25 + 0.25 * i), Vector3(90, 0, 0))


func _guard_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.32
	m.bottom_radius = 0.32
	m.height = 0.04
	m.radial_segments = 6
	return m


func flash(result: String) -> void:
	_flash_left = 0.18
	match result:
		"parried":
			_flash_color = Color(1.0, 1.0, 0.4)
		"blocked", "guard_broken":
			_flash_color = Color(0.6, 0.8, 1.0)
		_:
			_flash_color = Color(1.0, 0.35, 0.3)


func _process(delta: float) -> void:
	if fighter == null or _hips == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	_sync(delta)


func _sync(delta: float) -> void:
	var moved: float = fighter.pos.distance_to(_last_pos)
	_last_pos = fighter.pos
	_speed = lerpf(_speed, moved / maxf(delta, 0.0001) if delta > 0.0 else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	_stride += _speed * delta * 2.4
	position = Vector3(fighter.pos.x, 0.0, fighter.pos.y)
	rotation.y = atan2(fighter.dir.x, fighter.dir.y)
	var tint: Color = _flash_color if _flash_left > 0.0 else Color.WHITE
	_skin_mat.emission_enabled = _flash_left > 0.0
	_skin_mat.emission = tint
	_shield.visible = fighter.state == FighterState.State.BLOCK
	var swing: float = clampf(_speed / 4.0, 0.0, 1.2)
	_leg_l.rotation_degrees.x = sin(_stride) * 38.0 * swing
	_leg_r.rotation_degrees.x = -sin(_stride) * 38.0 * swing
	_arm_r.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	_arm_l.rotation_degrees = Vector3(-15.0 - sin(_stride) * 10.0 * swing, 0.0, 0.0)
	_body.rotation_degrees = Vector3.ZERO
	_body.position = Vector3.ZERO
	_hips.position.y = 0.92 + absf(sin(_stride)) * 0.04 * swing
	match fighter.state:
		FighterState.State.SWING:
			var t: float = clampf(fighter.state_t / maxf(fighter.swing_dur, 0.01), 0.0, 1.0)
			var flip: float = 1.0 if fighter.combo % 2 == 0 else -1.0
			_arm_r.rotation_degrees = Vector3(lerpf(-150.0, -20.0, t) if not fighter.swing_heavy else lerpf(-170.0, 10.0, t), lerpf(70.0, -70.0, t) * flip, 0.0)
			_body.rotation_degrees.y = lerpf(25.0, -25.0, t) * flip
			_body.rotation_degrees.x = 8.0
		FighterState.State.BLOCK:
			_arm_r.rotation_degrees = Vector3(-95.0, 25.0, 0.0)
			_arm_l.rotation_degrees = Vector3(-80.0, -20.0, 0.0)
			_body.rotation_degrees.x = 6.0
		FighterState.State.STAGGER:
			_body.rotation_degrees.x = -22.0
			_arm_r.rotation_degrees = Vector3(30.0, 0.0, 20.0)
			_arm_l.rotation_degrees = Vector3(30.0, 0.0, -20.0)
		FighterState.State.DODGE:
			_body.rotation_degrees.x = 35.0
			_body.position.y = -0.25
		FighterState.State.KICK:
			var kt: float = clampf(fighter.state_t / DeckData.KICK_TIME_S, 0.0, 1.0)
			_leg_r.rotation_degrees.x = -lerpf(0.0, 85.0, sin(kt * PI))
			_body.rotation_degrees.x = -10.0
		FighterState.State.DOWN, FighterState.State.DEAD:
			_body.rotation_degrees.x = -88.0
			_body.position = Vector3(0.0, 0.25, -0.3)
	visible = not fighter.overboard
	var tag: String = fighter.display_name if fighter.display_name != "" else fighter.kind
	_label.text = "%s  %d" % [tag, ceili(maxf(fighter.hp, 0.0))] if fighter.is_alive() else ""
	_label.modulate = Color(1, 1, 1) if fighter.team == 0 else Color(1.0, 0.65, 0.6)
