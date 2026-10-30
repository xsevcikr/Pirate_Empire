class_name Island
extends StaticBody3D
## A procedural island: noise heightmap with sand, grass and rock vertex colours, plus a solid core ships can ground on.

var radius_m: float = 200.0
var biome: String = "tropical"
var _look: Dictionary = {}
## When set the streamer builds vegetation and shallows on later frames, so a loading island never costs a long frame.
var staged: bool = false
var _stage: int = 0
var seed_value: int = 1
var peak_m: float = 40.0
var _noise: FastNoiseLite
const PALM_CAP: int = 260
const SHORE_H: float = 0.35


static func make(radius: float, seed_v: int, biome_name: String = "tropical") -> Island:
	var isl := Island.new()
	isl.radius_m = radius
	isl.seed_value = seed_v
	isl.biome = biome_name
	isl.peak_m = clampf(radius * 0.22, 18.0, 70.0)
	return isl


func _ready() -> void:
	_look = IslandData.biome(biome)
	collision_layer = 2
	collision_mask = 0
	set_meta("island", true)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/island.gdshader")
	mi.material_override = mat
	add_child(mi)
	_noise = _make_noise()
	if not staged:
		_grow_vegetation()
		_build_shallows()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius_m * 0.92
	cyl.height = 12.0
	cs.shape = cyl
	cs.position.y = -2.0
	add_child(cs)


## One more slice of a staged island's work; false once everything is built.
func build_next_stage() -> bool:
	match _stage:
		0:
			_grow_vegetation()
		1:
			_build_shallows()
	_stage += 1
	return _stage < 2


func height_at(local: Vector2, noise: FastNoiseLite) -> float:
	var d: float = local.length() / radius_m
	var fall: float = clampf(1.0 - d * d, 0.0, 1.0)
	var n: float = 0.55 + 0.45 * noise.get_noise_2d(local.x, local.y)
	return (fall * peak_m * n) - 3.0 * (1.0 - fall) - 1.5 + (4.0 if fall > 0.0 else 0.0) * fall


func _make_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.6 / radius_m
	noise.fractal_octaves = 4
	return noise


## Terrain height at a point, including the coastline warp used by the mesh.
func ground_y(p: Vector2) -> float:
	var warp: float = 1.0 + 0.25 * _noise.get_noise_2d(p.x * 1.7 + 311.0, p.y * 1.7)
	return height_at(p / warp, _noise)


func _build_mesh() -> ArrayMesh:
	var noise: FastNoiseLite = _make_noise()
	var rings: int = 28
	var segs: int = 56
	var outer: float = radius_m * 1.25
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	for r in rings + 1:
		for s in segs:
			var ang: float = TAU * s / segs
			var rad: float = outer * float(r) / rings
			var p := Vector2.from_angle(ang) * rad
			# warp the coastline so it is not a circle
			var warp: float = 1.0 + 0.25 * noise.get_noise_2d(p.x * 1.7 + 311.0, p.y * 1.7)
			var h: float = height_at(p / warp, noise)
			verts.append(Vector3(p.x, h, p.y))
			cols.append(_color_for(h, noise.get_noise_2d(p.x * 3.0, p.y * 3.0)))
	for r in rings:
		for s in segs:
			var a: int = r * segs + s
			var b: int = r * segs + (s + 1) % segs
			var c: int = (r + 1) * segs + s
			var d: int = (r + 1) * segs + (s + 1) % segs
			for idx in [a, c, b, b, c, d]:
				st.set_color(cols[idx])
				st.add_vertex(verts[idx])
	st.generate_normals()
	return st.commit()


func _color_for(h: float, n: float) -> Color:
	var sand: Color = _look["sand"]
	if h < 0.8:
		return sand.darkened(0.25)
	if h < 3.0:
		return sand
	if h < peak_m * 0.55:
		return (_look["grass"] as Color).lerp(_look["forest"], clampf(0.5 + n, 0.0, 1.0))
	return (_look["rock"] as Color).lerp(_look["grass"], clampf(0.3 - n, 0.0, 0.6))


# ---- vegetation and shallows ---------------------------------------------------------------------

## Palms, bushes and boulders scattered on the island by height and slope, as three MultiMeshes.
func _grow_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var palms: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var tries: int = int(clampf(radius_m * 5.0, 200.0, 1800.0) * float(_look["density"]))
	for i in tries:
		var ang: float = rng.randf() * TAU
		var rad: float = radius_m * sqrt(rng.randf()) * 1.1
		var p: Vector2 = Vector2.from_angle(ang) * rad
		var h: float = ground_y(p)
		if h < SHORE_H + 0.3:
			continue
		var slope: float = absf(ground_y(p + Vector2(1.5, 0)) - h) + absf(ground_y(p + Vector2(0, 1.5)) - h)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if bool(_look["palms"]) and h < peak_m * 0.5 and slope < 2.2 and palms.size() < PALM_CAP and rng.randf() < 0.55:
			var sc: float = rng.randf_range(0.8, 1.45)
			palms.append(Transform3D(basis.scaled(Vector3.ONE * sc), Vector3(p.x, h - 0.2, p.y)))
		elif bool(_look["bushes"]) and h < peak_m * 0.62 and slope < 3.0 and rng.randf() < 0.5:
			var sb: float = rng.randf_range(0.9, 2.4)
			bushes.append(Transform3D(basis.scaled(Vector3(sb, sb * 0.7, sb)), Vector3(p.x, h, p.y)))
		elif (slope > 1.2 or h > peak_m * 0.5) and biome != "ice":
			var sr: float = rng.randf_range(0.8, 3.2)
			rocks.append(Transform3D(basis.scaled(Vector3(sr, sr * 0.75, sr)), Vector3(p.x, h - sr * 0.2, p.y)))
	_scatter(_palm_mesh(), palms, true)
	_scatter(_bush_mesh(_look["forest"]), bushes, true)
	_scatter(_rock_mesh((_look["rock"] as Color).lightened(0.08)), rocks, true)


func _scatter(mesh: Mesh, xf: Array[Transform3D], vertex_colors: bool) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = vertex_colors
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = mat
	mmi.visibility_range_end = 2500.0
	add_child(mmi)


static func _palm_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.42, 0.3, 0.18)
	var segs: int = 7
	var ring: int = 6
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var f: float = i / float(segs)
		pts.append(Vector3(sin(f * 1.4) * 1.1, f * 8.0, 0.0))
	for i in segs:
		var r0: float = lerpf(0.34, 0.2, i / float(segs))
		var r1: float = lerpf(0.34, 0.2, (i + 1) / float(segs))
		for k in ring:
			var a0: float = TAU * k / ring
			var a1: float = TAU * (k + 1) / ring
			var p00: Vector3 = pts[i] + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p01: Vector3 = pts[i] + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var p10: Vector3 = pts[i + 1] + Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			var p11: Vector3 = pts[i + 1] + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			for v in [p00, p10, p01, p01, p10, p11]:
				st.set_color(trunk.darkened(0.15 * float(i % 2)))
				st.add_vertex(v)
	var top: Vector3 = pts[segs]
	for f in 9:
		var ang: float = TAU * f / 9.0 + 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var tip: Vector3 = top + dir * 3.6 + Vector3(0, -1.8 - 0.2 * float(f % 3), 0)
		var mid: Vector3 = top + dir * 1.8 + Vector3(0, 0.55, 0)
		var green := Color(0.16, 0.38, 0.12).lerp(Color(0.3, 0.5, 0.15), float(f % 3) / 3.0)
		for tri in [[top, mid + side * 0.7, mid - side * 0.7], [mid + side * 0.7, tip, mid - side * 0.7]]:
			for v in tri:
				st.set_color(green)
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _bush_mesh(c: Color) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.6
	sphere.radial_segments = 8
	sphere.rings = 4
	return _tinted(sphere, c.lightened(0.1))


static func _rock_mesh(c: Color) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.7
	sphere.radial_segments = 6
	sphere.rings = 3
	return _tinted(sphere, c)


static func _tinted(src: Mesh, c: Color) -> ArrayMesh:
	var arrays: Array = src.surface_get_arrays(0)
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cols := PackedColorArray()
	for i in n:
		cols.append(c)
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A translucent turquoise skirt and a foam line where the beach meets the water.
func _build_shallows() -> void:
	var segs: int = 72
	var inner: PackedVector3Array = PackedVector3Array()
	var outer: PackedVector3Array = PackedVector3Array()
	for s in segs + 1:
		var ang: float = TAU * (s % segs) / segs
		var dir: Vector2 = Vector2.from_angle(ang)
		var rad: float = radius_m * 1.25
		while rad > 2.0 and ground_y(dir * rad) < SHORE_H:
			rad -= 2.0
		var shore: Vector2 = dir * rad
		inner.append(Vector3(shore.x, 0.0, shore.y))
		var far: Vector2 = dir * (rad + 70.0 + 30.0 * _noise.get_noise_2d(dir.x * 40.0, dir.y * 40.0))
		outer.append(Vector3(far.x, 0.0, far.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segs:
		var a: Vector3 = inner[s]
		var b: Vector3 = inner[s + 1]
		var c: Vector3 = outer[s]
		var d: Vector3 = outer[s + 1]
		for tri in [[a, c, b, 0.0, 1.0, 0.0], [b, c, d, 0.0, 1.0, 1.0]]:
			for k in 3:
				st.set_uv(Vector2(float(s) / segs * 20.0, tri[3 + k]))
				st.add_vertex(tri[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/shallows.gdshader")
	mi.material_override = mat
	mi.position.y = 0.35
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
