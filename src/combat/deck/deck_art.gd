class_name DeckArt
extends RefCounted
## Builds the set for a deck fight from primitives: planked deck, balustrade rails, masts with rigging and sails,
## cannons, barrels, crates, the helm, lanterns and the enemy's ship alongside.

const ENEMY_GAP_M: float = 1.2
const RAIL_H: float = 1.05


static func wood(color: Color, plank_w: float = 0.32, along_x: bool = false, _wear: float = 0.5) -> ShaderMaterial:
	return Kenney.planks(color.lightened(0.12), plank_w * 1.4, along_x)


static func plain(color: Color, _rough: float = 0.8, _metal: float = 0.0) -> ShaderMaterial:
	return Kenney.flat(color)


static func add_mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bottom: float, h: float, segs: int = 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


## A whole deck, `side` is -1 for ours and +1 for the enemy's (mirrored, with its mast and sails).
static func build_ship_side(parent: Node3D, side: float, covers: Array[Dictionary]) -> void:
	var hw: float = DeckData.DECK_HALF_WIDTH_M
	var hl: float = DeckData.DECK_HALF_LENGTH_M
	var root := Node3D.new()
	parent.add_child(root)
	var dark: Color = Color(0.20, 0.12, 0.07) if side < 0.0 else Color(0.16, 0.10, 0.08)
	var planks: ShaderMaterial = wood(Color(0.52, 0.36, 0.20) if side < 0.0 else Color(0.46, 0.30, 0.17), 0.3, false)
	var rail_mat: ShaderMaterial = wood(Color(0.34, 0.2, 0.1), 0.2, false, 0.3)
	if side < 0.0:
		add_mesh(root, box(Vector3(hw * 2.0, 0.4, hl * 2.0)), planks, Vector3(0.0, -0.2, 0.0))
	else:
		add_mesh(root, box(Vector3(hw * 2.0, 0.4, hl * 2.0)), planks, Vector3(hw * 2.0 + ENEMY_GAP_M, -0.55, 0.0))
	var cx: float = 0.0 if side < 0.0 else hw * 2.0 + ENEMY_GAP_M
	var y0: float = 0.0 if side < 0.0 else -0.35
	# hull side below the deck, tarred planks with a gold stripe
	for edge in [-1.0, 1.0]:
		var outer_x: float = cx + edge * hw
		add_mesh(root, box(Vector3(0.3, 3.2, hl * 2.0)), wood(dark.lightened(0.1), 0.35, false, 0.7), Vector3(outer_x + edge * 0.05, y0 - 1.7, 0.0))
		add_mesh(root, box(Vector3(0.08, 0.16, hl * 2.0 + 0.2)), plain(Color(0.78, 0.58, 0.16), 0.5, 0.4), Vector3(outer_x + edge * 0.2, y0 - 0.5, 0.0))
	# balustrade along both long sides: rail, base and turned posts
	for edge in [-1.0, 1.0]:
		var x: float = cx + edge * (hw - 0.12)
		add_mesh(root, box(Vector3(0.26, 0.12, hl * 2.0)), rail_mat, Vector3(x, y0 + RAIL_H, 0.0))
		add_mesh(root, box(Vector3(0.22, 0.14, hl * 2.0)), rail_mat, Vector3(x, y0 + 0.07, 0.0))
		var n: int = 17
		for i in n:
			var z: float = lerpf(-hl + 0.4, hl - 0.4, i / float(n - 1))
			var post: MeshInstance3D = add_mesh(root, cyl(0.045, 0.065, RAIL_H - 0.15, 8), rail_mat, Vector3(x, y0 + RAIL_H * 0.5 + 0.02, z))
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# bow and stern walls with a raised quarterdeck block at the stern
	for end in [-1.0, 1.0]:
		add_mesh(root, box(Vector3(hw * 2.0, RAIL_H, 0.25)), wood(Color(0.30, 0.18, 0.09), 0.25, true), Vector3(cx, y0 + RAIL_H * 0.5, end * hl))
	add_mesh(root, box(Vector3(hw * 2.0, 1.0, 3.2)), planks, Vector3(cx, y0 + 0.5, hl - 1.8))
	add_mesh(root, box(Vector3(hw * 2.0 + 0.1, 0.14, 3.4)), rail_mat, Vector3(cx, y0 + 1.05, hl - 1.8))
	# the helm on the quarterdeck
	var wheel_x: float = cx
	add_mesh(root, cyl(0.1, 0.12, 1.0, 10), rail_mat, Vector3(wheel_x, y0 + 1.5, hl - 2.4))
	var wheel: MeshInstance3D = add_mesh(root, _wheel_mesh(), plain(Color(0.45, 0.3, 0.14), 0.5, 0.2), Vector3(wheel_x, y0 + 2.0, hl - 2.4), Vector3(0, 0, 90))
	wheel.rotation_degrees.y = 90.0
	# masts, rigging, sails
	for m in [Vector2(-0.8, -4.0), Vector2(-0.8, 4.0)]:
		_mast(root, Vector3(cx + (m.x if side < 0.0 else -m.x), y0, m.y), side)
	# cannons along the rails with carriages and rope coils
	for edge in [-1.0, 1.0]:
		for z in [-6.0, -2.0, 2.0, 6.0]:
			_cannon(root, Vector3(cx + edge * (hw - 0.95), y0, z), edge)
	# barrels, crates, lanterns
	for p in [Vector2(-5.9, 5.9), Vector2(-5.9, -4.5)]:
		_barrel(root, Vector3(cx + p.x, y0, p.y))
	for c in covers:
		if float(c["radius"]) >= 0.8:
			var cp := Vector3(cx + float(c["pos"].x), y0, c["pos"].y)
			if float(c["radius"]) > 0.85:
				_barrel(root, cp + Vector3(0.3, 0, 0.2))
				_barrel(root, cp + Vector3(-0.35, 0, -0.25))
			else:
				_crate(root, cp, float(c["radius"]))
	_coil(root, Vector3(cx + (hw - 2.2), y0, -8.0))
	_lantern(root, Vector3(cx + (hw - 0.5), y0 + 1.6, hl - 0.8))
	_lantern(root, Vector3(cx - (hw - 0.5), y0 + 1.6, hl - 0.8))


static func _wheel_mesh() -> ArrayMesh:
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.52
	tor.rings = 20
	tor.ring_segments = 6
	return _torus_with_spokes(tor)


static func _torus_with_spokes(tor: TorusMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tor.get_mesh_arrays())
	for i in 4:
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.05, 1.12, 0.05)
		var arrays: Array = spoke.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var t := Transform3D(Basis(Vector3(0, 1, 0), 0.0) * Basis(Vector3.FORWARD, PI * 0.25 * i), Vector3.ZERO)
		for v in verts.size():
			verts[v] = t * verts[v]
		arrays[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _mast(root: Node3D, at: Vector3, _side: float) -> void:
	var piece: Dictionary = ShipModel.mast_piece()
	var k: float = 2.4
	var g := Node3D.new()
	g.position = at + Vector3(0, -float(piece["pole_y"]) * k, 0)
	g.scale = Vector3(1.3, k, 1.3)
	root.add_child(g)
	var pole := MeshInstance3D.new()
	pole.mesh = piece["mesh"]
	g.add_child(pole)
	var sail := MeshInstance3D.new()
	sail.mesh = piece["sail"]
	sail.material_override = Kenney.toon((piece["sail"] as Mesh).surface_get_material(0))
	sail.position = piece["sail_pos"]
	g.add_child(sail)
	# ratlines: shrouds from the rail up to the nest, with rungs
	var rope: ShaderMaterial = plain(Color(0.3, 0.2, 0.12))
	for z_off in [-0.9, 0.9]:
		for edge in [-1.0, 1.0]:
			var base := Vector3(at.x + edge * 3.4, 0.9, at.z + z_off * 1.1)
			var top := Vector3(at.x + edge * 0.7, 9.0, at.z + z_off * 0.5)
			_rope(root, base, top, 0.04, rope)
			for j in range(1, 9):
				var f: float = j / 9.0
				_rope(root, base.lerp(top, f) + Vector3(0, 0, -0.35), base.lerp(top, f) + Vector3(0, 0, 0.35), 0.03, rope)


static func _sail_arrays(w: float, h: float, nx: int, ny: int) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ny:
		for i in nx:
			var pts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for q in [[0, 0], [1, 0], [0, 1], [1, 1]]:
				var u: float = (i + q[0]) / float(nx)
				var v: float = (j + q[1]) / float(ny)
				var width: float = w * lerpf(0.88, 1.0, 1.0 - v)
				pts.append(Vector3((u - 0.5) * width, v * h, 0.0))
				uvs.append(Vector2(u, v))
			for tri in [[0, 1, 2], [1, 3, 2]]:
				for k in tri:
					st.set_uv(uvs[k])
					st.add_vertex(pts[k])
	st.generate_normals()
	return st.commit().surface_get_arrays(0)


static func _rope(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d: Vector3 = b - a
	var mi: MeshInstance3D = add_mesh(root, cyl(r, r, d.length(), 4), mat, (a + b) * 0.5)
	var up: Vector3 = d.normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() > 0.0001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _cannon(root: Node3D, at: Vector3, edge: float) -> void:
	Kenney.place(root, "pirate", "cannon", at, edge * 90.0, 0.85)


static func _barrel(root: Node3D, at: Vector3) -> void:
	Kenney.place(root, "pirate", "barrel", at, at.x * 37.0 + at.z * 11.0, 0.65)


static func _crate(root: Node3D, at: Vector3, r: float) -> void:
	Kenney.place(root, "pirate", "crate", at, at.z * 23.0, r * 1.3)


static func _coil(root: Node3D, at: Vector3) -> void:
	var tor := TorusMesh.new()
	tor.inner_radius = 0.18
	tor.outer_radius = 0.5
	tor.rings = 16
	tor.ring_segments = 6
	add_mesh(root, tor, plain(Color(0.62, 0.5, 0.3), 0.95), at + Vector3(0, 0.12, 0))


static func _lantern(root: Node3D, at: Vector3) -> void:
	add_mesh(root, box(Vector3(0.05, 0.9, 0.05)), plain(Color(0.1, 0.1, 0.1), 0.6, 0.6), at + Vector3(0, -0.2, 0))
	var glass: ShaderMaterial = Kenney.flat(Color(1.0, 0.75, 0.3), 1.2)
	add_mesh(root, cyl(0.1, 0.13, 0.28, 8), glass, at + Vector3(0, 0.35, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.light_energy = 0.6
	l.omni_range = 5.0
	l.position = at + Vector3(0, 0.35, 0)
	root.add_child(l)
