class_name Ocean
extends Node3D
## Camera-following polar-grid ocean mesh. Owns the shared WaveModel.

const RING_COUNT: int = 140
const SEGMENTS: int = 192
const INNER_RADIUS: float = 2.0
const OUTER_RADIUS: float = 9000.0
const SNAP: float = 1.0

var model: WaveModel
var follow: Node3D
var _material: ShaderMaterial


func _ready() -> void:
	if model == null:
		model = WaveModel.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh()
	mi.extra_cull_margin = 200.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ocean.gdshader")
	mi.material_override = _material
	add_child(mi)
	_push_params()


func set_sea_state(state: float, wave_dir: Vector2) -> void:
	model.configure(state, wave_dir)
	if _material:
		_push_params()


func set_sky_color(c: Color) -> void:
	if _material:
		_material.set_shader_parameter("sky_color", Vector3(c.r, c.g, c.b))


func _push_params() -> void:
	_material.set_shader_parameter("wave_a", model.shader_wave_a())
	_material.set_shader_parameter("wave_b", model.shader_wave_b())


func _physics_process(delta: float) -> void:
	model.time += delta


func _process(_delta: float) -> void:
	_material.set_shader_parameter("ocean_time", model.time)
	if follow:
		var p: Vector3 = follow.global_position
		global_position = Vector3(snappedf(p.x, SNAP), 0.0, snappedf(p.z, SNAP))


func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var growth: float = pow(OUTER_RADIUS / INNER_RADIUS, 1.0 / float(RING_COUNT))
	verts.append(Vector3.ZERO)
	for ring in RING_COUNT + 1:
		var r: float = INNER_RADIUS * pow(growth, ring)
		for s in SEGMENTS:
			var a: float = TAU * s / float(SEGMENTS)
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var idx := PackedInt32Array()
	# Center fan
	for s in SEGMENTS:
		idx.append_array([0, 1 + (s + 1) % SEGMENTS, 1 + s])
	for ring in RING_COUNT:
		var base0: int = 1 + ring * SEGMENTS
		var base1: int = 1 + (ring + 1) * SEGMENTS
		for s in SEGMENTS:
			var s1: int = (s + 1) % SEGMENTS
			idx.append_array([base0 + s, base0 + s1, base1 + s])
			idx.append_array([base0 + s1, base1 + s1, base1 + s])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
