class_name Kenney
extends RefCounted
## Loads the CC0 Kenney models (assets/kenney/<kit>/<name>.glb) and dresses them in the game's cartoon surface.
## Scenes, meshes and materials are cached: a harbour or island places hundreds of these while streaming in.

const ROOT: String = "res://assets/kenney/"
const TOON: Shader = preload("res://shaders/toon.gdshader")

const OUTLINE: Shader = preload("res://shaders/outline.gdshader")
static var _outline: ShaderMaterial
static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _toons: Dictionary = {}


static func path(kit: String, model: String) -> String:
	return "%s%s/%s.glb" % [ROOT, kit, model]


static func scene(kit: String, model: String) -> PackedScene:
	_hook_exit()
	var p: String = path(kit, model)
	if not _scenes.has(p):
		_scenes[p] = load(p)
	return _scenes[p] as PackedScene


## A fresh copy of the model with the toon surface applied. The root is a plain Node3D wrapper.
static func spawn(kit: String, model: String, lined: bool = true) -> Node3D:
	var n: Node3D = scene(kit, model).instantiate() as Node3D
	n.name = model
	apply_toon(n, lined)
	return n


static func apply_toon(n: Node, lined: bool = true) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, toon(mi.mesh.surface_get_material(i), lined))
	for c in n.get_children():
		apply_toon(c, lined)


## One cached ShaderMaterial per source palette texture or flat colour.
static func toon(src: Material, lined: bool = true) -> ShaderMaterial:
	_hook_exit()
	var key: String = "none" if lined else "none-"
	var tex: Texture2D = null
	var col: Color = Color.WHITE
	if src is BaseMaterial3D:
		var b: BaseMaterial3D = src as BaseMaterial3D
		tex = b.albedo_texture
		col = b.albedo_color
		key = ("tex%d" % tex.get_instance_id()) if tex != null else ("col" + col.to_html(false))
		if not lined:
			key += "-"
	if not _toons.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		if tex != null:
			m.set_shader_parameter("albedo_tex", tex)
			m.set_shader_parameter("use_tex", true)
		else:
			m.set_shader_parameter("use_tex", false)
			m.set_shader_parameter("albedo", Vector3(col.r, col.g, col.b))
		if lined:
			m.next_pass = outline()
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


## Every mesh of a model merged into one multi-surface mesh (node transforms baked in), cached, for MultiMesh scatter.
static func merged(kit: String, model: String, lined: bool = true) -> Mesh:
	_hook_exit()
	var key: String = "m:" + path(kit, model) + ("" if lined else "-")
	if _meshes.has(key):
		return _meshes[key] as Mesh
	var root: Node3D = scene(kit, model).instantiate() as Node3D
	var out := ArrayMesh.new()
	for mi in meshes_of(root):
		var xf: Transform3D = Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for i in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(i)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for k in vs.size():
				vs[k] = xf * vs[k]
				if k < ns.size():
					ns[k] = (xf.basis * ns[k]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = vs
			arrays[Mesh.ARRAY_NORMAL] = ns
			arrays[Mesh.ARRAY_TANGENT] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, toon(mi.mesh.surface_get_material(i), lined))
	root.free()
	_meshes[key] = out
	return out


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
static func flat(c: Color, emit: float = 0.0, lined: bool = false) -> ShaderMaterial:
	_hook_exit()
	var key: String = "%s/%.2f/%s" % [c.to_html(false), emit, lined]
	if not _flats.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("use_tex", false)
		m.set_shader_parameter("albedo", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("emit_amount", emit)
		if lined:
			m.next_pass = outline()
		_flats[key] = m
	return _flats[key] as ShaderMaterial


static var _vcol: ShaderMaterial


## A white toon material that takes its colour from vertex or MultiMesh instance colours.
static func vcol() -> ShaderMaterial:
	_hook_exit()
	if _vcol == null:
		_vcol = ShaderMaterial.new()
		_vcol.shader = TOON
		_vcol.set_shader_parameter("use_tex", false)
		_vcol.set_shader_parameter("vcol", true)
	return _vcol


const PLANKS: Shader = preload("res://shaders/planks.gdshader")


## Planks that run along z (or along x): one shared material per colour and width.
static func planks(c: Color, width: float = 0.4, along_x: bool = false) -> ShaderMaterial:
	_hook_exit()
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


static var _hooked: bool = false


## Clears the caches when the window closes, so nothing is still alive at engine shutdown.
static func _hook_exit() -> void:
	if _hooked:
		return
	_hooked = true
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null:
		loop.root.tree_exiting.connect(clear_caches)


## Drops every cached scene, mesh and material, so nothing is still alive when the engine shuts down.
static func clear_caches() -> void:
	_outline = null
	_scenes.clear()
	_meshes.clear()
	_toons.clear()
	_flats.clear()
	_plank_mats.clear()
	_vcol = null
	ShipModel.clear_cache()
	DeckFighterView.clear_cache()
	TownBuilder.clear_cache()


## The shared dark outline every toon surface draws as its second pass.
static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE
	return _outline
