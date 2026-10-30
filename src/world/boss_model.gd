class_name BossModel
extends Node3D
## The bosses as they loom over their arenas, built from primitives: the kraken's mantle and suckered arms, the
## serpent's coils and fanged jaws, the Shell King's armoured claws, the Ghost Admiral's spectral hulk, the brass
## colossus and the ice leviathan. Every model has glowing eyes; parts tagged "sway" move in _process.
## Each model has a rig (body, head, arm_l, arm_r and a mouth marker) so it can act out its attacks: windup()
## holds the tell pose (a fist raised, a head reared back, a mouth glowing with poison), unleash() swings it.

const KINDS: Array[String] = ["kraken", "sea_serpent", "shell_king", "ghost_admiral", "brass_colossus", "ice_leviathan"]

const SIZE: Dictionary = {"kraken": 60.0, "sea_serpent": 60.0, "shell_king": 12.0, "ghost_admiral": 45.0, "brass_colossus": 34.0, "ice_leviathan": 40.0}
const STRIKE_S: float = 0.7

var kind: String = ""
var size: float = 40.0
var pose_fx: String = ""
var pose_part: String = ""
var pose_p: float = 0.0  ## how far into the tell, 0..1
var _t: float = 0.0
var _sway: Array[Node3D] = []
var _rig: Dictionary = {}
var _rest: Dictionary = {}  ## rig node -> its resting transform
var _strike_t: float = -1.0
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D


static func make(id: String) -> BossModel:
	var b := BossModel.new()
	b.kind = id
	b.name = "Boss_" + id
	return b


static func has_model(id: String) -> bool:
	return KINDS.has(id)


func _ready() -> void:
	size = float(SIZE.get(kind, 40.0))
	match kind:
		"kraken":
			_kraken()
		"sea_serpent":
			_serpent()
		"shell_king":
			_shell_king()
		"ghost_admiral":
			_ghost_ship()
		"brass_colossus":
			_colossus()
		"ice_leviathan":
			_leviathan()
	_build_rig()


## Everything built so far goes under a Body node; the parts that move on their own are already named in _rig.
func _build_rig() -> void:
	var body := Node3D.new()
	body.name = "Body"
	for c in get_children():
		remove_child(c)
		body.add_child(c)
	add_child(body)
	if _sway.has(self):
		_sway.erase(self)
		_sway.append(body)
	_rig["body"] = body
	for k in ["head", "arm_l", "arm_r"]:
		if not _rig.has(k):
			_rig[k] = body
	if not _rig.has("mouth"):
		_marker(body, Vector3(0, size * 0.3, size * 0.3), "mouth")
	for k in ["body", "head", "arm_l", "arm_r"]:
		var n: Node3D = _rig[k]
		_rest[n] = n.transform
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow = MeshInstance3D.new()
	_glow.mesh = _sphere(size * 0.035)
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	(_rig["mouth"] as Node3D).add_child(_glow)


func _marker(parent: Node3D, at: Vector3, key: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = key.capitalize()
	m.position = at
	parent.add_child(m)
	_rig[key] = m
	return m


func part_node(part: String) -> Node3D:
	return _rig.get(part, _rig.get("body", self))


func mouth_global() -> Vector3:
	return (_rig["mouth"] as Node3D).global_position


## Where a limb's business end is now: the tip of a raised fist or claw, for the stage's effects.
func part_global(part: String) -> Vector3:
	var n: Node3D = part_node(part)
	if n.has_meta("tip"):
		return n.to_global(n.get_meta("tip"))
	return n.global_position


## Hold the tell pose of an attack, p from 0 (just started) to 1 (about to land). c tints the mouth glow.
func windup(fx: String, part: String, p: float, c: Color = Color(1, 0.3, 0.2)) -> void:
	if _strike_t >= 0.0 and pose_fx == fx:
		return
	pose_fx = fx
	pose_part = part
	pose_p = clampf(p, 0.0, 1.0)
	_strike_t = -1.0
	if _glow != null:
		var mouthy: bool = fx in ["spit", "breath", "roar", "freeze", "nova", "volley", "rain", "summon", "grab"]
		_glow.visible = mouthy and p > 0.05
		_glow_mat.albedo_color = Color(c.r, c.g, c.b, 0.85)
		var gs: float = 0.4 + pose_p * 1.4 + sin(_t * 18.0) * 0.08 * pose_p
		_glow.scale = Vector3.ONE * (gs * (2.2 if fx == "nova" else 1.0))


## Let the attack go: the raised limb comes down, the head snaps forward. Plays for STRIKE_S.
func unleash(fx: String, part: String) -> void:
	pose_fx = fx
	pose_part = part
	pose_p = 1.0
	_strike_t = 0.0
	if _glow != null:
		_glow.visible = false


func calm() -> void:
	pose_fx = ""
	pose_p = 0.0
	_strike_t = -1.0
	if _glow != null:
		_glow.visible = false


## Weight of the pose now: the tell eases in to 1, the strike snaps past the rest pose to -0.6 and settles back.
func pose_weight() -> float:
	if _strike_t >= 0.0:
		if _strike_t < 0.12:
			return 1.0 - _strike_t / 0.12 * 1.6
		return -0.6 * maxf(1.0 - (_strike_t - 0.12) / (STRIKE_S - 0.12), 0.0)
	return ease(pose_p, 0.6)


func _apply_pose() -> void:
	for n: Node3D in _rest.keys():
		var tr: Transform3D = _rest[n]
		n.position = tr.origin
		n.scale = tr.basis.get_scale()
		n.rotation = tr.basis.get_euler()
	if pose_fx == "":
		return
	var w: float = pose_weight()
	var body: Node3D = _rig["body"]
	var head: Node3D = _rig["head"]
	var limb: Node3D = part_node(pose_part)
	match pose_fx:
		"slam", "quake":
			if limb == body:
				body.rotation.x += -0.22 * w
				body.position.y += size * 0.12 * maxf(w, 0.0)
			else:
				limb.rotation.x += -1.2 * w
			if pose_fx == "quake":
				body.position.y += size * 0.06 * w
		"sweep":
			if limb == body:
				body.rotation.y += 0.7 * w
			else:
				limb.rotation.y += (0.9 if pose_part == "arm_r" else -0.9) * w
				limb.rotation.x += -0.4 * absf(w)
		"throw":
			limb.rotation.x += -1.3 * w
			body.rotation.y += 0.15 * w
		"spit", "breath", "roar", "freeze", "lunge":
			head.rotation.x += -0.4 * w
			if pose_fx == "lunge":
				head.position.z += size * 0.5 * -minf(w, 0.0) * 2.0
				head.rotation.x += 0.9 * -minf(w, 0.0)
			if head == body:
				body.position.y += size * 0.05 * w
		"dive":
			body.position.y -= size * 0.9 * clampf(w, 0.0, 1.0)
		"spin":
			body.rotation.y += _t * 14.0 * maxf(w, 0.2 if _strike_t >= 0.0 else 0.0)
		"teleport":
			body.scale *= maxf(1.0 - 0.95 * clampf(w, 0.0, 1.0), 0.05)
		_:
			body.scale *= 1.0 + 0.06 * w
			body.position.y += size * 0.04 * w


func _mat(c: Color, _rough: float = 0.6, emit: float = 0.0, alpha: float = 1.0, _metal: float = 0.0) -> Material:
	if alpha >= 1.0:
		return Kenney.flat(Look.cartoon(c), minf(emit * 0.3, 0.7))
	var m := StandardMaterial3D.new()  # ghostly pieces stay flat-coloured, unlit and see-through
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sphere(r: float, squash: float = 1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 * squash
	s.radial_segments = 24
	s.rings = 12
	return s


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


func _cyl(r0: float, r1: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = 12
	return c


func _eye(parent: Node3D, at: Vector3, r: float, c: Color) -> void:
	_part(parent, _sphere(r), _mat(c.darkened(0.25), 0.3, 1.6), at)
	var slit: MeshInstance3D = _part(parent, _sphere(r * 0.4), _mat(Color(0.0, 0.0, 0.0), 0.3), at + Vector3(0, 0, r * 0.78))
	slit.scale = Vector3(0.28, 1.5, 0.5)
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = r * 14.0
	l.light_energy = 1.4
	l.position = at
	parent.add_child(l)


## A tapering arm made of segments that curl; returns the root so it can sway.
func _arm(parent: Node3D, base: Vector3, yaw: float, length: float, thick: float, skin: Color, suckers: bool) -> Node3D:
	var root := Node3D.new()
	root.position = base
	root.rotation.y = yaw
	parent.add_child(root)
	var segs: int = 9
	var seg_len: float = length / float(segs)
	var cur := Node3D.new()
	root.add_child(cur)
	var skin_m: Material = _mat(skin, 0.45)
	var sucker_m: Material = _mat(skin.lightened(0.45), 0.3)
	for i in segs:
		var r0: float = thick * (1.0 - float(i) / float(segs) * 0.85)
		var r1: float = thick * (1.0 - float(i + 1) / float(segs) * 0.85)
		var seg: MeshInstance3D = _part(cur, _cyl(r0, r1, seg_len), skin_m, Vector3(0, seg_len * 0.5, 0))
		if suckers and i > 1:
			for k in 3:
				var a: float = float(k) * 2.1 + float(i)
				_part(seg, _sphere(r0 * 0.28, 0.55), sucker_m, Vector3(cos(a), 0.0, sin(a)) * r0 * 0.92)
		var nxt := Node3D.new()
		nxt.position = Vector3(0, seg_len, 0)
		nxt.rotation_degrees = Vector3(11.0 + float(i) * 1.5, 7.0, 0)
		cur.add_child(nxt)
		cur = nxt
	_sway.append(root)
	root.set_meta("tip", Vector3(0, length * 0.8, length * 0.25))
	return root


func _kraken() -> void:
	var skin := Color(0.42, 0.1, 0.14)
	_part(self, _sphere(26.0, 1.5), _mat(skin, 0.4), Vector3(0, 8, 0))
	_part(self, _cone(20.0, 46.0), _mat(skin.darkened(0.2), 0.45), Vector3(0, 42, -6), Vector3(-14, 0, 0))
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		_part(self, _cone(2.4, 14.0), _mat(Color(0.85, 0.8, 0.7), 0.4), Vector3(cos(a) * 17.0, 28.0, sin(a) * 17.0 - 4.0))
	_eye(self, Vector3(-13, 22, 22), 4.8, Color(1.0, 0.8, 0.1))
	_eye(self, Vector3(13, 22, 22), 4.8, Color(1.0, 0.8, 0.1))
	# the beak
	_part(self, _cone(6.0, 10.0), _mat(Color(0.1, 0.07, 0.05), 0.3), Vector3(0, 0, 25), Vector3(90, 0, 0))
	for i in 8:
		var yaw: float = TAU * float(i) / 8.0
		var arm: Node3D = _arm(self, Vector3(cos(yaw) * 22.0, 2.0, sin(yaw) * 22.0), -yaw + PI * 0.5, 90.0 + float(i % 3) * 14.0, 6.0, skin, true)
		if i == 2:
			_rig["arm_r"] = arm  # the two arms nearest the front do the slapping
		elif i == 1:
			_rig["arm_l"] = arm
	_marker(self, Vector3(0, 4, 32), "mouth")


func _serpent() -> void:
	var skin := Color(0.12, 0.38, 0.3)
	var belly := Color(0.75, 0.8, 0.55)
	var n: int = 14
	for i in n:
		var a: float = float(i) * 0.55
		var r: float = 11.0 - float(i) * 0.4
		var at := Vector3(cos(a) * 26.0, 3.0 + sin(a * 2.0) * 3.0, float(i) * -9.0 + 20.0)
		_part(self, _sphere(r, 0.9), _mat(skin, 0.35), at)
		_part(self, _cone(2.0, 9.0), _mat(Color(0.7, 0.18, 0.15), 0.5), at + Vector3(0, r, 0))
	# raised neck and head
	var neck: Node3D = Node3D.new()
	add_child(neck)
	for i in 8:
		_part(neck, _sphere(9.5 - float(i) * 0.3), _mat(skin, 0.35), Vector3(0, 5.0 + float(i) * 8.0, 24.0 - float(i) * 1.5))
		_part(neck, _sphere(7.0, 0.5), _mat(belly, 0.5), Vector3(0, 5.0 + float(i) * 8.0, 29.0 - float(i) * 1.5))
	var head: Node3D = Node3D.new()
	head.position = Vector3(0, 74, 15)
	neck.add_child(head)
	_part(head, _sphere(11.0, 0.8), _mat(skin, 0.35), Vector3.ZERO)
	_part(head, _cyl(6.0, 4.0, 18.0), _mat(skin, 0.35), Vector3(0, -1, 14), Vector3(90, 0, 0))
	_part(head, _cyl(5.0, 3.0, 16.0), _mat(belly, 0.5), Vector3(0, -7, 12), Vector3(95, 0, 0))
	for k in 6:
		var x: float = -4.0 + float(k) * 1.6
		_part(head, _cone(0.9, 5.0), _mat(Color(0.95, 0.93, 0.85), 0.3), Vector3(x, -4.0, 16.0), Vector3(180, 0, 0))
		_part(head, _cone(0.9, 5.0), _mat(Color(0.95, 0.93, 0.85), 0.3), Vector3(x, -5.5, 14.0))
	_part(head, _cone(2.0, 14.0), _mat(Color(0.7, 0.18, 0.15), 0.5), Vector3(-7, 8, -5), Vector3(0, 0, 30))
	_part(head, _cone(2.0, 14.0), _mat(Color(0.7, 0.18, 0.15), 0.5), Vector3(7, 8, -5), Vector3(0, 0, -30))
	_eye(head, Vector3(-7, 3, 7), 2.6, Color(1.0, 0.2, 0.1))
	_eye(head, Vector3(7, 3, 7), 2.6, Color(1.0, 0.2, 0.1))
	_marker(head, Vector3(0, -4, 24), "mouth")
	_rig["head"] = head
	_sway.append(neck)


func _shell_king() -> void:
	var shell := Color(0.55, 0.2, 0.12)
	_part(self, _sphere(9.0, 0.7), _mat(shell, 0.5), Vector3(0, 6, 0))
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		_part(self, _cone(1.4, 4.5), _mat(Color(0.85, 0.7, 0.5), 0.4), Vector3(cos(a) * 6.0, 10.5, sin(a) * 6.0) * Vector3(1, 1, 1))
	for s in [-1.0, 1.0]:
		var arm: Node3D = Node3D.new()
		arm.position = Vector3(s * 8.0, 5.0, 7.0)
		add_child(arm)
		_part(arm, _cyl(1.6, 1.2, 9.0), _mat(shell, 0.5), Vector3(s * 3.0, 0, 4.0), Vector3(70, 0, s * 40.0))
		var claw: Node3D = Node3D.new()
		claw.position = Vector3(s * 6.0, 0, 9.0)
		arm.add_child(claw)
		_part(claw, _sphere(3.6, 0.8), _mat(shell.lightened(0.1), 0.45), Vector3.ZERO)
		_part(claw, _cone(1.8, 7.0), _mat(Color(0.9, 0.75, 0.55), 0.35), Vector3(s * 1.4, 0, 5.0), Vector3(90, 0, 0))
		_part(claw, _cone(1.5, 6.0), _mat(Color(0.9, 0.75, 0.55), 0.35), Vector3(-s * 1.4, -0.5, 4.5), Vector3(90, 0, 0))
		arm.set_meta("tip", Vector3(s * 6.0, 0, 13.0))
		_rig["arm_r" if s > 0.0 else "arm_l"] = arm
	for i in 3:
		for s in [-1.0, 1.0]:
			_part(self, _cyl(0.7, 0.35, 8.0), _mat(shell.darkened(0.2), 0.5), Vector3(s * 9.0, 2.0, -3.0 + float(i) * 3.0), Vector3(0, 0, s * -60.0))
	for s in [-1.0, 1.0]:
		_part(self, _cyl(0.35, 0.35, 3.0), _mat(shell, 0.5), Vector3(s * 3.0, 11.0, 8.0))
		_eye(self, Vector3(s * 3.0, 12.8, 8.5), 1.1, Color(1.0, 0.4, 0.1))
	_marker(self, Vector3(0, 7.5, 9.5), "mouth")


func _ghost_ship() -> void:
	var parts: Dictionary = ShipModel.parts("ship-ghost")
	var sc: float = 90.0 / float(parts["length"])
	var ship: Node3D = Kenney.spawn("pirate", "ship-ghost")
	ship.rotation.y = PI
	ship.scale = Vector3.ONE * sc
	ship.position.y = -ShipModel.WATER_Y * sc
	add_child(ship)
	var head := Node3D.new()
	head.position = Vector3(0, 28, -40)
	add_child(head)
	_part(head, _sphere(3.0), _mat(Color(0.9, 0.95, 0.9), 0.5, 0.8), Vector3.ZERO)
	_eye(head, Vector3(-1.2, 0.5, 3.0), 0.7, Color(0.3, 1.0, 0.7))
	_eye(head, Vector3(1.2, 0.5, 3.0), 0.7, Color(0.3, 1.0, 0.7))
	_marker(head, Vector3(0, -0.5, 4.0), "mouth")
	_rig["head"] = head
	for k in 5:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.7)
		l.omni_range = 30.0
		l.position = Vector3(0, 8, -30.0 + float(k) * 16.0)
		add_child(l)
	_sway.append(self)


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _colossus() -> void:
	var brass := _mat(Color(0.72, 0.52, 0.18), 0.35, 0.0, 1.0, 0.85)
	var dark := _mat(Color(0.25, 0.18, 0.1), 0.5, 0.0, 1.0, 0.7)
	_part(self, _box(Vector3(14, 16, 9)), brass, Vector3(0, 22, 0))
	_part(self, _cyl(3.0, 3.0, 6.0), dark, Vector3(0, 33, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 35, 1)
	add_child(head)
	_part(head, _box(Vector3(6, 6, 6)), brass, Vector3(0, 2, 0))
	_eye(head, Vector3(-1.6, 2.5, 3.2), 0.9, Color(1.0, 0.35, 0.05))
	_eye(head, Vector3(1.6, 2.5, 3.2), 0.9, Color(1.0, 0.35, 0.05))
	_part(head, _box(Vector3(3.5, 0.8, 0.6)), _mat(Color(1.0, 0.4, 0.05), 0.3, 3.0), Vector3(0, 0.4, 3.1))
	_marker(head, Vector3(0, 0.4, 3.8), "mouth")
	_rig["head"] = head
	for s in [-1.0, 1.0]:
		_part(self, _box(Vector3(5, 18, 5)), brass, Vector3(s * 5.0, 9, 0))
		_part(self, _box(Vector3(7, 3, 9)), dark, Vector3(s * 5.0, 1.5, 1.5))
		var arm := Node3D.new()  # pivots at the shoulder so the fist can be raised and slammed
		arm.position = Vector3(s * 10.0, 28, 0)
		add_child(arm)
		_part(arm, _sphere(4.0), dark, Vector3.ZERO)
		_part(arm, _box(Vector3(4.0, 16, 4.0)), brass, Vector3(s * 1.0, -10, 2.0), Vector3(-25, 0, 0))
		_part(arm, _box(Vector3(7, 7, 7)), dark, Vector3(s * 1.0, -19, 8.0))
		for k in 4:
			_part(arm, _box(Vector3(1.4, 1.6, 2.0)), brass, Vector3(s * 1.0 - 2.4 + float(k) * 1.6, -16.2, 11.4))
		arm.set_meta("tip", Vector3(s * 1.0, -19, 8.0))
		_rig["arm_r" if s > 0.0 else "arm_l"] = arm
	for i in 3:
		_part(self, _cyl(0.9, 1.1, 10.0), dark, Vector3(-4.0 + float(i) * 4.0, 33, -4.0))
		_part(self, _sphere(2.6, 0.6), _mat(Color(0.85, 0.85, 0.85), 0.9, 0.0, 0.4), Vector3(-4.0 + float(i) * 4.0, 41.0 + float(i % 2) * 2.0, -4.0))
	_part(self, _cyl(3.5, 3.5, 0.4), _mat(Color(1.0, 0.4, 0.05), 0.3, 3.0), Vector3(0, 22, 4.6), Vector3(90, 0, 0))


func _leviathan() -> void:
	var ice := Color(0.62, 0.82, 0.95)
	var m: Material = _mat(ice, 0.2, 0.0, 0.92)
	m.metallic = 0.2
	for i in 8:
		var r: float = 9.0 - float(i) * 0.5
		_part(self, _sphere(r, 0.9), m, Vector3(sin(float(i)) * 14.0, 0.0, float(i) * -10.0))
	var head := Node3D.new()  # pivots at the neck so it can rear back and breathe
	head.position = Vector3(0, 12, 22)
	add_child(head)
	_part(head, _sphere(13.0, 0.9), m, Vector3.ZERO, Vector3(-20, 0, 0))
	_part(head, _cyl(8.0, 6.0, 20.0), m, Vector3(0, -4, 14), Vector3(80, 0, 0))
	for k in 7:
		var x: float = -6.0 + float(k) * 2.0
		_part(head, _cone(1.2, 7.0), _mat(Color(0.95, 0.98, 1.0), 0.15), Vector3(x, 2.0, 19.0), Vector3(180, 0, 0))
		_part(head, _cone(1.2, 7.0), _mat(Color(0.95, 0.98, 1.0), 0.15), Vector3(x, -10.0, 19.0))
	_eye(head, Vector3(-9, 6, 8), 2.8, Color(0.4, 0.9, 1.0))
	_eye(head, Vector3(9, 6, 8), 2.8, Color(0.4, 0.9, 1.0))
	_marker(head, Vector3(0, -4, 25), "mouth")
	_rig["head"] = head
	for k in 9:
		var a: float = float(k) * 0.9
		_part(self, _cone(2.5 + float(k % 3), 14.0 + float(k % 4) * 5.0), _mat(Color(0.85, 0.95, 1.0), 0.1, 0.0, 0.9), Vector3(sin(a) * 6.0, 14.0, 18.0 - float(k) * 5.0))


func _process(delta: float) -> void:
	_t += delta
	if _strike_t >= 0.0:
		_strike_t += delta
		if _strike_t >= STRIKE_S:
			calm()
	if not _rest.is_empty():
		_apply_pose()
	for i in _sway.size():
		var n: Node3D = _sway[i]
		if n == _rig.get("body"):
			n.position.y += sin(_t * 0.6) * 1.6
			n.rotation.z += sin(_t * 0.5) * 0.03
		elif _rest.has(n):  # a rigged limb: the pose was just set, sway on top of it
			n.rotation.x += sin(_t * 0.8 + float(i)) * 0.09
			n.rotation.z += cos(_t * 0.6 + float(i) * 1.7) * 0.07
		else:
			n.rotation.x = sin(_t * 0.8 + float(i)) * 0.09
			n.rotation.z = cos(_t * 0.6 + float(i) * 1.7) * 0.07
