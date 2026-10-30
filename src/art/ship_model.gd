class_name ShipModel
extends RefCounted
## Takes a Kenney ship apart so the game can animate it: the hull with its deck furniture, one mesh per mast pole and
## crow's nest (so a mast can come down), the sails (their yard is part of the sail mesh) and the flag positions.
## Models face +Z; the game faces -Z, so callers turn the result half a circle.

const DECK_Y: float = 2.1  ## model units: the main deck
const WATER_Y: float = 1.0  ## where the waterline cuts the hull
const MAST_MIN_TOP_Y: float = 3.0

static var _cache: Dictionary = {}


## {hull: Mesh, length: float, masts: [{z, mesh, sail: Mesh, sail_pos: Vector3, top_y: float}], ensign: Vector3}
static func parts(model: String) -> Dictionary:
	if _cache.has(model):
		return _cache[model]
	var scene: Node = Kenney.scene("pirate", model).instantiate()
	var hull_mi: MeshInstance3D = null
	var sails: Array[MeshInstance3D] = []
	var flags: Array[MeshInstance3D] = []
	for mi in Kenney.meshes_of(scene):
		if mi.name.begins_with("sail"):
			sails.append(mi)
		elif mi.name.begins_with("flag"):
			flags.append(mi)
		elif hull_mi == null:
			hull_mi = mi
	var src: Mesh = hull_mi.mesh
	var mat: ShaderMaterial = Kenney.toon(src.surface_get_material(0))
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var comp_of: PackedInt32Array = _components(verts, idx)
	# mast positions come from the sails: one mast per sail, plus the main mast under the flag
	var masts: Array[Dictionary] = []
	for s in sails:
		var top_y: float = 9.0
		for f in flags:
			if absf(f.position.z - s.position.z) < 0.2 and f.position.y > 7.0:
				top_y = f.position.y
		masts.append({"z": s.position.z, "sail_node": s, "top_y": top_y, "tris": []})
	var hull_tris: Array = []
	var ci: Dictionary = {}  # component -> {min, max, tris}
	for t in range(0, idx.size(), 3):
		var c: int = comp_of[idx[t]]
		if not ci.has(c):
			ci[c] = {"min": Vector3(1e9, 1e9, 1e9), "max": Vector3(-1e9, -1e9, -1e9), "tris": []}
		var e: Dictionary = ci[c]
		for k in 3:
			var v: Vector3 = verts[idx[t + k]]
			e["min"] = (e["min"] as Vector3).min(v)
			e["max"] = (e["max"] as Vector3).max(v)
		(e["tris"] as Array).append(t)
	for c: int in ci:
		var e: Dictionary = ci[c]
		var lo: Vector3 = e["min"]
		var hi: Vector3 = e["max"]
		var mast_i: int = -1
		if lo.y >= 2.0 and hi.y > MAST_MIN_TOP_Y and absf(lo.x) < 1.0 and absf(hi.x) < 1.0:
			var cz: float = (lo.z + hi.z) * 0.5
			for i in masts.size():
				if absf(cz - float(masts[i]["z"])) < 0.75:
					mast_i = i
		if mast_i >= 0:
			(masts[mast_i]["tris"] as Array).append_array(e["tris"])
		else:
			hull_tris.append_array(e["tris"])
	var out: Dictionary = {"hull": _subset(arrays, hull_tris, Vector3.ZERO, mat), "masts": [], "length": src.get_aabb().size.z}
	masts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["z"]) > float(b["z"]))  # bow (+z) first
	for m in masts:
		var sail_mi: MeshInstance3D = m["sail_node"]
		var z: float = m["z"]
		var pole: Mesh = _subset(arrays, m["tris"], Vector3(0, 0, z), mat) if (m["tris"] as Array).size() > 0 else null
		(out["masts"] as Array).append({
			"z": z, "mesh": pole, "sail": sail_mi.mesh, "sail_pos": Vector3(0, sail_mi.position.y, 0),
			"sail_size": sail_mi.mesh.get_aabb().size, "top_y": m["top_y"]})
	var ensign := Vector3(0, 5.5, -3.0)
	for f in flags:
		if f.position.y < 7.0:
			ensign = f.position
	out["ensign"] = ensign
	scene.free()
	_cache[model] = out
	return out


## Union of triangles that share a (welded) vertex: component id per vertex index.
static func _components(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedInt32Array:
	var weld: Dictionary = {}
	var wid := PackedInt32Array()
	wid.resize(verts.size())
	for i in verts.size():
		var v: Vector3 = verts[i]
		var key := Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0))
		if not weld.has(key):
			weld[key] = weld.size()
		wid[i] = weld[key]
	var parent := PackedInt32Array()
	parent.resize(weld.size())
	for i in parent.size():
		parent[i] = i
	for t in range(0, idx.size(), 3):
		var a: int = _find(parent, wid[idx[t]])
		for k in [1, 2]:
			var b: int = _find(parent, wid[idx[t + k]])
			if a != b:
				parent[b] = a
	var out := PackedInt32Array()
	out.resize(verts.size())
	for i in verts.size():
		out[i] = _find(parent, wid[i])
	return out


static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


## A new mesh made of the listed triangles, moved by -shift.
static func _subset(arrays: Array, tris: Array, shift: Vector3, mat: Material) -> ArrayMesh:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var remap: Dictionary = {}
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	var ni := PackedInt32Array()
	for t in tris:
		for k in 3:
			var i: int = idx[t + k]
			if not remap.has(i):
				remap[i] = nv.size()
				nv.append(verts[i] - shift)
				nn.append(norms[i])
				nu.append(uvs[i])
			ni.append(remap[i])
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = nv
	a[Mesh.ARRAY_NORMAL] = nn
	a[Mesh.ARRAY_TEX_UV] = nu
	a[Mesh.ARRAY_INDEX] = ni
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.surface_set_material(0, mat)
	return m


## Which Kenney hull a ship class uses: small for the one-masters, medium for the two-masters and the lateen
## three-masters, large for the square-rigged three-masters and everything over 40 m.
static func model_for(stats: ShipStats, faction: String) -> String:
	var size: String = "small"
	if stats.length_m >= 40.0 or (stats.mast_count >= 3 and stats.square_rig):
		size = "large"
	elif stats.mast_count == 2 or stats.length_m >= 22.0:
		size = "medium"
	if stats.class_id == "revenant" or faction == "ghost":
		return "ship-ghost"
	if faction == "pirate" or faction == "player":
		return "ship-pirate-" + size
	return "ship-" + size


## The loose Kenney mast (pole, one sail and a pennant), used as the extra foremast on three-masted classes.
static func mast_piece() -> Dictionary:
	if _cache.has("_mast"):
		return _cache["_mast"]
	var scene: Node = Kenney.scene("pirate", "mast").instantiate()
	var pole: MeshInstance3D = null
	var sail: MeshInstance3D = null
	var flag: MeshInstance3D = null
	for mi in Kenney.meshes_of(scene):
		if mi.name.begins_with("sail"):
			sail = mi
		elif mi.name.begins_with("flag"):
			flag = mi
		elif pole == null:
			pole = mi
	var pole_mesh: Mesh = pole.mesh.duplicate() as Mesh
	pole_mesh.surface_set_material(0, Kenney.toon(pole.mesh.surface_get_material(0)))
	var out: Dictionary = {
		"z": 0.0, "mesh": pole_mesh, "sail": sail.mesh, "sail_pos": Vector3(0, sail.position.y, 0),
		"sail_size": sail.mesh.get_aabb().size, "top_y": flag.position.y, "pole_y": 2.6}
	scene.free()
	_cache["_mast"] = out
	return out

static func clear_cache() -> void:
	_cache.clear()
