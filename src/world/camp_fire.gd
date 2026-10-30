class_name CampFire
extends Node3D
## A camp fire: stone ring, crossed logs, flame cones that shift, embers, and a light that flickers. Seeded, so
## every fire burns slightly differently.

var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _t: float = 0.0
var _seed: float = 0.0


func _init(seed_v: float = 0.0) -> void:
	_seed = seed_v


func _ready() -> void:
	var stone: ShaderMaterial = Kenney.flat(Color(0.63, 0.65, 0.73))
	var log_m: ShaderMaterial = Kenney.flat(Color(0.69, 0.38, 0.25))
	var coals: ShaderMaterial = Kenney.flat(Color(1.0, 0.45, 0.2), 0.9)
	for i in 9:
		var a: float = TAU * i / 9.0
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.17
		m.height = 0.24
		m.radial_segments = 6
		m.rings = 3
		s.mesh = m
		s.material_override = stone
		s.position = Vector3(cos(a) * 0.62, 0.08, sin(a) * 0.62)
		add_child(s)
	for i in 4:
		var l := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.06
		c.bottom_radius = 0.07
		c.height = 0.9
		c.radial_segments = 6
		l.mesh = c
		l.material_override = log_m
		l.position = Vector3(0, 0.14 + 0.04 * (i % 2), 0)
		l.rotation_degrees = Vector3(80, i * 45.0 + 12.0, 0)
		add_child(l)
	var bed := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.34
	bm.bottom_radius = 0.4
	bm.height = 0.06
	bed.mesh = bm
	bed.material_override = coals
	bed.position.y = 0.1
	add_child(bed)
	for i in 4:
		var f := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.2 - 0.03 * i
		cm.height = 0.7 + 0.18 * i
		cm.radial_segments = 6
		f.mesh = cm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = [Color(1.0, 0.25, 0.04), Color(1.0, 0.5, 0.08), Color(1.0, 0.75, 0.2), Color(1.0, 0.95, 0.6)][i]
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		f.material_override = fm
		f.position.y = 0.3 + 0.2 * i * 0.0
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.28)
	_light.omni_range = 16.0
	_light.light_energy = 1.6
	_light.position.y = 0.9
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var f: MeshInstance3D = _flames[i]
		var k: float = 1.0 + 0.22 * sin(_t * (9.0 + 3.0 * i) + _seed + i) + 0.1 * sin(_t * 23.0 + i * 2.0)
		f.scale = Vector3(1.0 + 0.1 * sin(_t * 7.0 + i), k, 1.0 + 0.1 * cos(_t * 8.0 + i))
		f.position.y = 0.3 + 0.35 * (f.mesh as CylinderMesh).height * 0.5 * (k - 1.0) + (f.mesh as CylinderMesh).height * 0.5 * k
		f.rotation_degrees.y += delta * (30.0 + 10.0 * i)
	_light.light_energy = 1.5 + 0.35 * sin(_t * 13.0 + _seed) + 0.2 * sin(_t * 31.0)
