class_name ArenaView
extends Node3D
## What a boss arena looks like from the ship: a ring of buoys at its edge and the feature that fills it,
## a spinning whirlpool, drifting fog banks, ice floes, a lava ring or a line of ghost lanterns. Primitives only;
## the art pass replaces them.

var boss_id: String = ""
var centre: Vector2
var radius: float = 500.0
var kind: String = ""
var _spin: Array[Node3D] = []


static func make(id: String) -> ArenaView:
	var v := ArenaView.new()
	v.boss_id = id
	v.centre = BossArena.centre(id)
	v.radius = float(BossArena.ARENAS[id]["radius"])
	v.kind = str(BossArena.ARENAS[id]["kind"])
	v.name = "Arena_" + id
	v.position = Vector3(v.centre.x, 0.0, v.centre.y)
	return v


func _ready() -> void:
	_ring()
	match kind:
		"whirlpool":
			_whirlpool()
		"fog":
			_fog()
		"ice_field":
			_floes()
		"lava_works", "beach":
			_braziers()
		_:
			_buoys(8)


func _mat(c: Color, emit: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.8
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ring() -> void:
	var n: int = clampi(int(radius / 25.0), 16, 64)
	var post := CylinderMesh.new()
	post.top_radius = 1.0
	post.bottom_radius = 1.4
	post.height = 14.0
	var mat: StandardMaterial3D = _mat(Color(0.9, 0.35, 0.2), 1.2)
	for i in n:
		var a: float = TAU * float(i) / float(n)
		_mesh(post, mat, Vector3(cos(a), 0.0, sin(a)) * radius + Vector3(0, 5.0, 0))


func _buoys(count: int) -> void:
	var s := SphereMesh.new()
	s.radius = 3.0
	s.height = 6.0
	for i in count:
		var a: float = TAU * float(i) / float(count)
		_mesh(s, _mat(Color(0.95, 0.85, 0.3), 0.5), Vector3(cos(a), 0.4, sin(a)) * radius * 0.6)


func _whirlpool() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.92
	disc.bottom_radius = radius * 0.1
	disc.height = 1.0
	disc.radial_segments = 48
	var funnel: MeshInstance3D = _mesh(disc, _mat(Color(0.02, 0.08, 0.14), 0.0, 0.85), Vector3(0, 0.6, 0))
	_spin.append(funnel)
	var arm := BoxMesh.new()
	arm.size = Vector3(radius * 0.45, 1.2, 14.0)
	for i in 6:
		var holder := Node3D.new()
		holder.rotation.y = TAU * float(i) / 6.0
		add_child(holder)
		var m := MeshInstance3D.new()
		m.mesh = arm
		m.material_override = _mat(Color(0.8, 0.95, 1.0), 0.6, 0.55)
		m.position = Vector3(radius * 0.4, 1.4, 0.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(m)
		_spin.append(holder)


func _fog() -> void:
	var s := SphereMesh.new()
	s.radius = radius * 0.22
	s.height = radius * 0.3
	for i in 9:
		var a: float = TAU * float(i) / 9.0
		_mesh(s, _mat(Color(0.75, 0.82, 0.85), 0.0, 0.28), Vector3(cos(a), 0.2, sin(a)) * radius * 0.65)
	var lantern := SphereMesh.new()
	lantern.radius = 2.5
	lantern.height = 5.0
	for i in 5:
		var a2: float = TAU * float(i) / 5.0 + 0.3
		_mesh(lantern, _mat(Color(0.4, 1.0, 0.6), 2.5), Vector3(cos(a2), 10.0, sin(a2)) * radius * 0.45)


func _floes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 26:
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(20.0, 70.0), rng.randf_range(2.0, 6.0), rng.randf_range(20.0, 70.0))
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf()) * radius * 0.85
		var mi: MeshInstance3D = _mesh(b, _mat(Color(0.85, 0.94, 1.0)), Vector3(cos(a) * d, 0.5, sin(a) * d))
		mi.rotation.y = rng.randf() * TAU


func _braziers() -> void:
	var c := CylinderMesh.new()
	c.top_radius = 2.0
	c.bottom_radius = 1.5
	c.height = 3.0
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		_mesh(c, _mat(Color(1.0, 0.45, 0.1), 3.0), Vector3(cos(a), 1.5, sin(a)) * radius * 0.8)


func _process(delta: float) -> void:
	for n in _spin:
		n.rotate_y(delta * 0.35)
