class_name Kenney
extends RefCounted
## Loads the CC0 Kenney models (assets/kenney/<kit>/<name>.glb) and dresses them in the game's cartoon surface.
## Scenes, meshes and materials are cached: a harbour or island places hundreds of these while streaming in.

const ROOT: String = "res://assets/kenney/"
const TOON: Shader = preload("res://shaders/toon.gdshader")

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _toons: Dictionary = {}


static func path(kit: String, model: String) -> String:
	return "%s%s/%s.glb" % [ROOT, kit, model]


static func scene(kit: String, model: String) -> PackedScene:
	var p: String = path(kit, model)
	if not _scenes.has(p):
		_scenes[p] = load(p)
	return _scenes[p] as PackedScene


## A fresh copy of the model with the toon surface applied. The root is a plain Node3D wrapper.
static func spawn(kit: String, model: String) -> Node3D:
	var n: Node3D = scene(kit, model).instantiate() as Node3D
	n.name = model
	apply_toon(n)
	return n


static func apply_toon(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, toon(mi.mesh.surface_get_material(i)))
	for c in n.get_children():
		apply_toon(c)


## One cached ShaderMaterial per source palette texture or flat colour.
static func toon(src: Material) -> ShaderMaterial:
	var key: String = "none"
	var tex: Texture2D = null
	var col: Color = Color.WHITE
	if src is BaseMaterial3D:
		var b: BaseMaterial3D = src as BaseMaterial3D
		tex = b.albedo_texture
		col = b.albedo_color
		key = ("tex%d" % tex.get_instance_id()) if tex != null else ("col" + col.to_html(false))
	if not _toons.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		if tex != null:
			m.set_shader_parameter("albedo_tex", tex)
			m.set_shader_parameter("use_tex", true)
		else:
			m.set_shader_parameter("use_tex", false)
			m.set_shader_parameter("albedo", Vector3(col.r, col.g, col.b))
		_toons[key] = m
	return _toons[key] as ShaderMaterial


## The first mesh found in a model (toon surfaces already applied), for MultiMesh scatter. Returns the mesh and the
## local transform it had inside the model.
static func mesh(kit: String, model: String) -> Mesh:
	var p: String = path(kit, model)
	if not _meshes.has(p):
		var root: Node = scene(kit, model).instantiate()
		var mi: MeshInstance3D = _first_mesh(root)
		var m: Mesh = null
		if mi != null:
			m = mi.mesh.duplicate() as Mesh
			for i in m.get_surface_count():
				m.surface_set_material(i, toon(mi.mesh.surface_get_material(i)))
		root.free()
		_meshes[p] = m
	return _meshes[p] as Mesh


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _first_mesh(c)
		if r != null:
			return r
	return null


## Every MeshInstance3D under a node, depth-first.
static func meshes_of(n: Node, out: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		meshes_of(c, out)
	return out


## Scales a model so its longest horizontal footprint side equals `length_m` and returns the scale used.
static func fit_length(n: Node3D, model_length: float, length_m: float) -> float:
	var s: float = length_m / model_length
	n.scale = Vector3.ONE * s
	return s


## Colours lifted from the Kenney palette, so code-built pieces sit in the same world as the models.
const PAL: Dictionary = {
	"orange": Color("ff7e44"), "red": Color("cf534f"), "blue": Color("6794d9"), "brown": Color("b06041"),
	"cream": Color("fde4c7"), "grey": Color("868ba1"), "silver": Color("a0a8c9"), "tan": Color("f2bf99"),
	"pink": Color("f378f0"), "green": Color("61cb8b"), "yellow": Color("ffc044"), "sky": Color("d0e8ff"),
	"purple": Color("a878e8"), "dark": Color("38383d"), "slate": Color("4f5260"), "white": Color("ffffff"),
	"plank": Color("f1976c"), "stone": Color("a0a8c9"), "roof_red": Color("cf534f"), "roof_green": Color("51b985"),
}

static var _flats: Dictionary = {}
static var _plank_mats: Dictionary = {}


## A flat-coloured toon surface, one shared material per colour.
static func flat(c: Color, emit: float = 0.0) -> ShaderMaterial:
	var key: String = "%s/%.2f" % [c.to_html(false), emit]
	if not _flats.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("use_tex", false)
		m.set_shader_parameter("albedo", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("emit_amount", emit)
		_flats[key] = m
	return _flats[key] as ShaderMaterial


const PLANKS: Shader = preload("res://shaders/planks.gdshader")


## Planks that run along z (or along x): one shared material per colour and width.
static func planks(c: Color, width: float = 0.4, along_x: bool = false) -> ShaderMaterial:
	var key: String = "%s/%.2f/%s" % [c.to_html(false), width, along_x]
	if not _plank_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = PLANKS
		m.set_shader_parameter("wood_color", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("dark_color", Vector3(c.r * 0.5, c.g * 0.42, c.b * 0.4))
		m.set_shader_parameter("plank_width", width)
		m.set_shader_parameter("along_x", along_x)
		_plank_mats[key] = m
	return _plank_mats[key] as ShaderMaterial


## Puts a model in a parent at a position, yaw (degrees) and uniform scale; returns it.
static func place(parent: Node3D, kit: String, model: String, at: Vector3, yaw_deg: float = 0.0, s: float = 1.0) -> Node3D:
	var n: Node3D = spawn(kit, model)
	n.position = at
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	return n
