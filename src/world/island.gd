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
		IslandCamp.build(self, _veg_rng)
		_build_shallows()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius_m * 0.92
	cyl.height = 12.0
	cs.shape = cyl
	cs.position.y = -2.0
	add_child(cs)


var _veg_rng: RandomNumberGenerator
var _palm_sets: Array = []
var _bushes: Array[Transform3D] = []
var _rocks: Array[Transform3D] = []
var _tries: int = 0
var _camp_plan: Dictionary = {}


## One more slice of a staged island's work; false once everything is built.
func build_next_stage() -> bool:
	match _stage:
		0:
			_sample_start()
			_sample_range(0, _tries / 2)
		1:
			_sample_range(_tries / 2, _tries)
		2:
			_scatter_vegetation()
		3:
			_camp_plan = IslandCamp.plan_camp(self, _veg_rng)
		4, 5, 6:
			if not _camp_plan.is_empty():
				(_camp_plan["jobs"][_stage - 4] as Callable).call()
		7:
			_build_shallows()
	_stage += 1
	return _stage < 8


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
	_sample_start()
	_sample_range(0, _tries)
	_scatter_vegetation()


func _sample_start() -> void:
	_veg_rng = RandomNumberGenerator.new()
	_veg_rng.seed = seed_value * 31 + 7
	_palm_sets = [[], [], []]
	_bushes = []
	_rocks = []
	_tries = int(clampf(radius_m * 5.0, 200.0, 1800.0) * float(_look["density"]))


func _sample_range(from: int, to: int) -> void:
	var rng: RandomNumberGenerator = _veg_rng
	for i in range(from, to):
		var ang: float = rng.randf() * TAU
		var rad: float = radius_m * sqrt(rng.randf()) * 1.1
		var p: Vector2 = Vector2.from_angle(ang) * rad
		var h: float = ground_y(p)
		if h < SHORE_H + 0.3:
			continue
		var slope: float = absf(ground_y(p + Vector2(1.5, 0)) - h) + absf(ground_y(p + Vector2(0, 1.5)) - h)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if _has_trees() and h < peak_m * 0.5 and slope < 2.2 and (_palm_sets[0].size() + _palm_sets[1].size() + _palm_sets[2].size()) < PALM_CAP and rng.randf() < 0.55:
			var sc: float = rng.randf_range(0.8, 1.45)
			_palm_sets[rng.randi_range(0, 2)].append(Transform3D(basis.scaled(Vector3.ONE * sc), Vector3(p.x, h - 0.2, p.y)))
		elif bool(_look["bushes"]) and h < peak_m * 0.62 and slope < 3.0 and rng.randf() < 0.5:
			var sb: float = rng.randf_range(0.9, 2.4)
			_bushes.append(Transform3D(basis.scaled(Vector3(sb, sb * 0.7, sb)), Vector3(p.x, h, p.y)))
		elif (slope > 1.2 or h > peak_m * 0.5) and biome != "ice":
			var sr: float = rng.randf_range(0.8, 3.2)
			_rocks.append(Transform3D(basis.scaled(Vector3(sr, sr * 0.75, sr)), Vector3(p.x, h - sr * 0.2, p.y)))


## Trees: palms on the warm islands, oaks and pines on the temperate and rocky ones.
func _has_trees() -> bool:
	return bool(_look["palms"]) or biome == "temperate" or biome == "rocky"


## [kit, model, scale] of the three tree variants of this biome.
func _tree_models() -> Array:
	if bool(_look["palms"]):
		return [["pirate", "palm-bend", 2.1], ["pirate", "palm-straight", 2.4], ["pirate", "palm-detailed-bend", 1.8]]
	if biome == "rocky":
		return [["nature", "tree_pineTallA", 6.0], ["nature", "tree_pineTallB", 6.5], ["nature", "tree_pineSmallA", 5.5]]
	return [["nature", "tree_oak", 6.0], ["nature", "tree_default", 6.5], ["nature", "tree_pineTallA", 6.5]]


const ROCKS: Array = [["pirate", "rocks-a", 0.5], ["pirate", "rocks-b", 0.5], ["pirate", "rocks-c", 0.5]]


## Every model an island can use, built into shared merged meshes while the world loads.
static func prewarm() -> void:
	for set in [["pirate", "palm-bend"], ["pirate", "palm-straight"], ["pirate", "palm-detailed-bend"], ["nature", "tree_pineTallA"], ["nature", "tree_pineTallB"], ["nature", "tree_pineSmallA"], ["nature", "tree_oak"], ["nature", "tree_default"], ["nature", "plant_bushLarge"], ["pirate", "rocks-a"], ["pirate", "rocks-b"], ["pirate", "rocks-c"], ["nature", "campfire_logs"]]:
		Kenney.merged(set[0], set[1])
	for m in ["flower_redA", "flower_yellowB", "grass_large", "mushroom_redGroup", "log"]:
		Kenney.merged("nature", m, false)
	Kenney.merged("nature", "plant_bushLarge", false)


func _scatter_vegetation() -> void:
	var models: Array = _tree_models()
	for v in 3:
		var xs: Array[Transform3D] = []
		xs.assign(_palm_sets[v])
		_scatter(Kenney.merged(models[v][0], models[v][1]), xs, float(models[v][2]), 1.0)
	_scatter(Kenney.merged("nature", "plant_bushLarge", false), _bushes, 5.0, 0.6)
	_scatter_small_props()
	for v in 3:
		var rs: Array[Transform3D] = []
		for i in range(v, _rocks.size(), 3):
			rs.append(_rocks[i])
		_scatter(Kenney.merged(ROCKS[v][0], ROCKS[v][1]), rs, float(ROCKS[v][2]))


## Flowers, grass tufts, mushrooms, logs and stones on the grass: a few hundred small instances in five MultiMeshes.
func _scatter_small_props() -> void:
	if biome in ["volcanic", "ice", "ruined"]:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + 3
	var sets: Array = [[], [], [], [], []]
	var count: int = int(clampf(radius_m * 1.6, 60.0, 420.0))
	for i in count:
		var p: Vector2 = Vector2.from_angle(rng.randf() * TAU) * radius_m * sqrt(rng.randf()) * 1.05
		var h: float = ground_y(p)
		if h < 1.4 or h > peak_m * 0.5:
			continue
		var slope: float = absf(ground_y(p + Vector2(1.5, 0)) - h) + absf(ground_y(p + Vector2(0, 1.5)) - h)
		if slope > 2.0:
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		(sets[rng.randi_range(0, 4)] as Array).append(Transform3D(b, Vector3(p.x, h - 0.05, p.y)))
	var models: Array = [["nature", "flower_redA", 6.0], ["nature", "flower_yellowB", 6.0], ["nature", "grass_large", 6.0], ["nature", "mushroom_redGroup", 5.0], ["nature", "log", 5.0]]
	for k in 5:
		var xs: Array[Transform3D] = []
		xs.assign(sets[k])
		_scatter(Kenney.merged(models[k][0], models[k][1], false), xs, float(models[k][2]), 1.0 if k < 3 else 0.0)


func _scatter(mesh: Mesh, xf: Array[Transform3D], base_scale: float, sway: float = 0.0) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.use_custom_data = sway > 0.0
	mm.instance_count = xf.size()
	for i in xf.size():
		var t: Transform3D = xf[i]
		t.basis = t.basis.scaled(Vector3.ONE * base_scale)
		mm.set_instance_transform(i, t)
		if sway > 0.0:
			mm.set_instance_custom_data(i, Color(sway, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 2500.0
	add_child(mmi)


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
