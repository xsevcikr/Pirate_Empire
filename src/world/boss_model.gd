class_name BossModel
extends Node3D
## The bosses as they loom over their arenas, built from primitives: the kraken's mantle and suckered arms, the
## serpent's coils and fanged jaws, the Shell King's armoured claws, the Ghost Admiral's spectral hulk, the brass
## colossus and the ice leviathan. Every model has glowing eyes; parts tagged "sway" move in _process.

const KINDS: Array[String] = ["kraken", "sea_serpent", "shell_king", "ghost_admiral", "brass_colossus", "ice_leviathan"]

var kind: String = ""
var _t: float = 0.0
var _sway: Array[Node3D] = []


static func make(id: String) -> BossModel:
	var b := BossModel.new()
	b.kind = id
	b.name = "Boss_" + id
	return b


static func has_model(id: String) -> bool:
	return KINDS.has(id)


func _ready() -> void:
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


func _mat(c: Color, rough: float = 0.6, emit: float = 0.0, alpha: float = 1.0, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
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
	var skin_m: StandardMaterial3D = _mat(skin, 0.45)
	var sucker_m: StandardMaterial3D = _mat(skin.lightened(0.45), 0.3)
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
		_arm(self, Vector3(cos(yaw) * 22.0, 2.0, sin(yaw) * 22.0), -yaw + PI * 0.5, 90.0 + float(i % 3) * 14.0, 6.0, skin, true)


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
		_sway.append(arm)
	for i in 3:
		for s in [-1.0, 1.0]:
			_part(self, _cyl(0.7, 0.35, 8.0), _mat(shell.darkened(0.2), 0.5), Vector3(s * 9.0, 2.0, -3.0 + float(i) * 3.0), Vector3(0, 0, s * -60.0))
	for s in [-1.0, 1.0]:
		_part(self, _cyl(0.35, 0.35, 3.0), _mat(shell, 0.5), Vector3(s * 3.0, 11.0, 8.0))
		_eye(self, Vector3(s * 3.0, 12.8, 8.5), 1.1, Color(1.0, 0.4, 0.1))


func _ghost_ship() -> void:
	var bone := Color(0.55, 0.85, 0.75)
	var hull: StandardMaterial3D = _mat(bone.darkened(0.55), 0.7, 0.4, 0.78)
	_part(self, _box(Vector3(24, 14, 90)), hull, Vector3(0, 6, 0))
	_part(self, _box(Vector3(20, 12, 24)), hull, Vector3(0, 18, -34))
	for i in 10:
		var z: float = -38.0 + float(i) * 8.0
		for s in [-1.0, 1.0]:
			_part(self, _cyl(0.6, 0.6, 12.0), _mat(Color(0.8, 0.9, 0.85), 0.5, 0.6, 0.85), Vector3(s * 12.2, 17.0, z), Vector3(0, 0, s * 12.0))
	for mz in [-22.0, 6.0, 30.0]:
		_part(self, _cyl(1.0, 1.3, 70.0), _mat(Color(0.3, 0.35, 0.33), 0.8, 0.0, 0.9), Vector3(0, 44, mz))
		_part(self, _box(Vector3(34, 26, 0.4)), _mat(bone, 0.9, 0.9, 0.4), Vector3(0, 52, mz + 1.0))
	_part(self, _sphere(3.0), _mat(Color(0.9, 0.95, 0.9), 0.5, 0.8), Vector3(0, 28, -40))
	_eye(self, Vector3(-1.2, 28.5, -37.0), 0.7, Color(0.3, 1.0, 0.7))
	_eye(self, Vector3(1.2, 28.5, -37.0), 0.7, Color(0.3, 1.0, 0.7))
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
	_part(self, _box(Vector3(6, 6, 6)), brass, Vector3(0, 37, 1))
	_eye(self, Vector3(-1.6, 37.5, 4.2), 0.9, Color(1.0, 0.35, 0.05))
	_eye(self, Vector3(1.6, 37.5, 4.2), 0.9, Color(1.0, 0.35, 0.05))
	for s in [-1.0, 1.0]:
		_part(self, _box(Vector3(5, 18, 5)), brass, Vector3(s * 5.0, 9, 0))
		_part(self, _box(Vector3(7, 3, 9)), dark, Vector3(s * 5.0, 1.5, 1.5))
		_part(self, _sphere(4.0), dark, Vector3(s * 10.0, 28, 0))
		_part(self, _box(Vector3(4.0, 16, 4.0)), brass, Vector3(s * 11.0, 18, 2.0), Vector3(-25, 0, 0))
		_part(self, _box(Vector3(7, 7, 7)), dark, Vector3(s * 11.0, 9, 8.0))
	for i in 3:
		_part(self, _cyl(0.9, 1.1, 10.0), dark, Vector3(-4.0 + float(i) * 4.0, 33, -4.0))
		_part(self, _sphere(2.6, 0.6), _mat(Color(0.85, 0.85, 0.85), 0.9, 0.0, 0.4), Vector3(-4.0 + float(i) * 4.0, 41.0 + float(i % 2) * 2.0, -4.0))
	_part(self, _cyl(3.5, 3.5, 0.4), _mat(Color(1.0, 0.4, 0.05), 0.3, 3.0), Vector3(0, 22, 4.6), Vector3(90, 0, 0))


func _leviathan() -> void:
	var ice := Color(0.62, 0.82, 0.95)
	var m: StandardMaterial3D = _mat(ice, 0.2, 0.0, 0.92)
	m.metallic = 0.2
	for i in 8:
		var r: float = 9.0 - float(i) * 0.5
		_part(self, _sphere(r, 0.9), m, Vector3(sin(float(i)) * 14.0, 0.0, float(i) * -10.0))
	_part(self, _sphere(13.0, 0.9), m, Vector3(0, 12, 22), Vector3(-20, 0, 0))
	_part(self, _cyl(8.0, 6.0, 20.0), m, Vector3(0, 8, 36), Vector3(80, 0, 0))
	for k in 7:
		var x: float = -6.0 + float(k) * 2.0
		_part(self, _cone(1.2, 7.0), _mat(Color(0.95, 0.98, 1.0), 0.15), Vector3(x, 14.0, 41.0), Vector3(180, 0, 0))
		_part(self, _cone(1.2, 7.0), _mat(Color(0.95, 0.98, 1.0), 0.15), Vector3(x, 2.0, 41.0))
	for k in 9:
		var a: float = float(k) * 0.9
		_part(self, _cone(2.5 + float(k % 3), 14.0 + float(k % 4) * 5.0), _mat(Color(0.85, 0.95, 1.0), 0.1, 0.0, 0.9), Vector3(sin(a) * 6.0, 14.0, 18.0 - float(k) * 5.0))
	_eye(self, Vector3(-9, 18, 30), 2.8, Color(0.4, 0.9, 1.0))
	_eye(self, Vector3(9, 18, 30), 2.8, Color(0.4, 0.9, 1.0))


func _process(delta: float) -> void:
	_t += delta
	for i in _sway.size():
		var n: Node3D = _sway[i]
		if n == self:
			n.position.y = sin(_t * 0.6) * 1.6
			n.rotation.z = sin(_t * 0.5) * 0.03
		else:
			n.rotation.x = sin(_t * 0.8 + float(i)) * 0.09
			n.rotation.z = cos(_t * 0.6 + float(i) * 1.7) * 0.07
