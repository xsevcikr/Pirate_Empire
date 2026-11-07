class_name SeaLifeArt
extends RefCounted
## Low-poly, flat-shaded meshes for the animals of the sea, in the same cartoon look as the Kenney kits: a body lofted
## through a few six-sided rings (dark back, pale belly) plus flat fins. Every mesh is built once and shared.
## Animals face -Z like every other node, so look_at() points them where they swim.

const SIDES: int = 6

static var _cache: Dictionary = {}


## A body through rings of [z, half width, half height, centre y]; vertex colours fade from `back` to `belly`.
static func _loft(st: SurfaceTool, rings: Array, back: Color, belly: Color, s: float = 1.0) -> void:
	var pts: Array = []
	for r: Array in rings:
		var ring: Array[Vector3] = []
		for k in SIDES:
			var a: float = TAU * float(k) / float(SIDES) + PI / float(SIDES)
			ring.append(Vector3(cos(a) * float(r[1]), sin(a) * float(r[2]) + float(r[3]), float(r[0])) * s)
		pts.append(ring)
	for i in pts.size() - 1:
		var a_ring: Array[Vector3] = pts[i]
		var b_ring: Array[Vector3] = pts[i + 1]
		for k in SIDES:
			var k2: int = (k + 1) % SIDES
			_quad(st, a_ring[k], a_ring[k2], b_ring[k2], b_ring[k], back, belly)
	# caps
	var first: Array[Vector3] = pts[0]
	var last: Array[Vector3] = pts[-1]
	var c0: Vector3 = Vector3(0, float(rings[0][3]), float(rings[0][0]) - 0.04) * s
	var c1: Vector3 = Vector3(0, float(rings[-1][3]), float(rings[-1][0]) + 0.04) * s
	for k in SIDES:
		var k2: int = (k + 1) % SIDES
		_tri(st, c0, first[k2], first[k], _shade(first[k].y, back, belly))
		_tri(st, c1, last[k], last[k2], _shade(last[k].y, back, belly))


static func _shade(y: float, back: Color, belly: Color) -> Color:
	return back if y >= 0.0 else belly


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, back: Color, belly: Color) -> void:
	var col: Color = _shade((a.y + b.y + c.y + d.y) * 0.25, back, belly)
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


## One flat triangle; `both` adds the back face too, for thin fins and wings.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, both: bool = false) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(-n)
		st.add_vertex(p)
	if both:
		for p in [a, c, b]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(p)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _finish(key: String, st: SurfaceTool) -> Mesh:
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, Kenney.vcol())
	_cache[key] = m
	return m


## A bottlenose dolphin, about 2.6 m long.
static func dolphin() -> Mesh:
	if _cache.has("dolphin"):
		return _cache["dolphin"]
	var st := _begin()
	var back := Color(0.42, 0.55, 0.7)
	var belly := Color(0.88, 0.92, 0.95)
	_loft(st, [[-1.3, 0.04, 0.04, -0.02], [-1.05, 0.08, 0.07, -0.03], [-0.9, 0.2, 0.22, 0.04], [-0.45, 0.3, 0.32, 0.03],
		[0.15, 0.27, 0.28, 0.0], [0.7, 0.13, 0.14, 0.02], [1.05, 0.05, 0.06, 0.03]], back, belly)
	_fins(st, 1.0, back)
	_eyes(st, Vector3(0.16, 0.12, -0.82), 0.05)
	return _finish("dolphin", st)


## A humpback whale, about 12 m long: a stout body, long white-edged flippers and a broad tail.
static func whale() -> Mesh:
	if _cache.has("whale"):
		return _cache["whale"]
	var st := _begin()
	var back := Color(0.27, 0.33, 0.44)
	var belly := Color(0.8, 0.84, 0.88)
	var s: float = 4.6
	_loft(st, [[-1.3, 0.12, 0.08, -0.06], [-1.15, 0.26, 0.22, -0.04], [-0.8, 0.38, 0.36, 0.0], [-0.2, 0.4, 0.38, 0.02],
		[0.4, 0.3, 0.28, 0.02], [0.9, 0.12, 0.12, 0.04], [1.15, 0.06, 0.06, 0.05]], back, belly, s)
	# a small hump of a dorsal fin far back
	_tri(st, Vector3(0, 0.3, 0.45) * s, Vector3(0, 0.42, 0.62) * s, Vector3(0, 0.26, 0.7) * s, back, true)
	# long flippers, pale
	for x in [-1.0, 1.0]:
		_tri(st, Vector3(0.32 * x, -0.12, -0.55) * s, Vector3(0.95 * x, -0.32, -0.2) * s, Vector3(0.34 * x, -0.14, -0.3) * s, belly, true)
	# the broad tail
	for x in [-1.0, 1.0]:
		_tri(st, Vector3(0, 0.05, 1.1) * s, Vector3(0.62 * x, 0.06, 1.42) * s, Vector3(0.1 * x, 0.05, 1.3) * s, back, true)
	_eyes(st, Vector3(0.3, -0.02, -0.85) * s, 0.12)
	return _finish("whale", st)


## Dorsal fin, flippers and tail flukes of a dolphin-shaped body, scaled by `s`.
static func _fins(st: SurfaceTool, s: float, c: Color) -> void:
	_tri(st, Vector3(0, 0.3, -0.15) * s, Vector3(0, 0.68, 0.25) * s, Vector3(0, 0.27, 0.32) * s, c, true)
	for x in [-1.0, 1.0]:
		_tri(st, Vector3(0.24 * x, -0.12, -0.5) * s, Vector3(0.55 * x, -0.32, -0.15) * s, Vector3(0.26 * x, -0.14, -0.28) * s, c, true)
		_tri(st, Vector3(0, 0.03, 1.0) * s, Vector3(0.45 * x, 0.04, 1.38) * s, Vector3(0.08 * x, 0.03, 1.24) * s, c, true)


## Two dark eye dots, mirrored across the body.
static func _eyes(st: SurfaceTool, at: Vector3, r: float) -> void:
	var dark := Color(0.08, 0.09, 0.12)
	for x in [-1.0, 1.0]:
		var p := Vector3(at.x * x, at.y, at.z)
		var out := Vector3(x, 0, 0) * 0.01
		_tri(st, p + out + Vector3(0, r, 0), p + out + Vector3(0, -r * 0.7, r), p + out + Vector3(0, -r * 0.7, -r), dark, true)


## A flying fish, about 0.5 m, with its big gliding fins spread.
static func flying_fish() -> Mesh:
	if _cache.has("flying_fish"):
		return _cache["flying_fish"]
	var st := _begin()
	var back := Color(0.18, 0.42, 0.78)
	var belly := Color(0.85, 0.9, 0.95)
	_loft(st, [[-0.25, 0.02, 0.02, 0.0], [-0.18, 0.05, 0.05, 0.0], [0.02, 0.055, 0.055, 0.0], [0.17, 0.025, 0.03, 0.0]], back, belly)
	var wing := Color(0.55, 0.8, 0.95)
	for x in [-1.0, 1.0]:
		_tri(st, Vector3(0.04 * x, 0.01, -0.12), Vector3(0.36 * x, 0.03, 0.02), Vector3(0.04 * x, 0.01, 0.06), wing, true)
		_tri(st, Vector3(0, 0, 0.16), Vector3(0.1 * x, 0.02, 0.3), Vector3(0.02 * x, 0, 0.24), back, true)
	return _finish("flying_fish", st)


## A seagull's body and head (wings are separate so they can flap).
static func gull_body() -> Mesh:
	if _cache.has("gull_body"):
		return _cache["gull_body"]
	var st := _begin()
	var white := Color(0.97, 0.97, 0.95)
	_loft(st, [[-0.32, 0.04, 0.04, 0.06], [-0.26, 0.08, 0.08, 0.06], [-0.14, 0.09, 0.09, 0.02], [0.05, 0.11, 0.1, 0.0],
		[0.24, 0.06, 0.04, 0.02], [0.32, 0.02, 0.01, 0.03]], white, white)
	var beak := Color(1.0, 0.78, 0.15)
	_tri(st, Vector3(-0.03, 0.06, -0.31), Vector3(0.03, 0.06, -0.31), Vector3(0, 0.04, -0.44), beak, true)
	_tri(st, Vector3(-0.03, 0.06, -0.31), Vector3(0, 0.04, -0.44), Vector3(0, 0.09, -0.31), beak, true)
	_tri(st, Vector3(0.03, 0.06, -0.31), Vector3(0, 0.09, -0.31), Vector3(0, 0.04, -0.44), beak, true)
	_eyes(st, Vector3(0.07, 0.09, -0.27), 0.018)
	return _finish("gull_body", st)


## One gull wing, root at the origin and spreading along +x (mirror it with scale.x = -1 for the left one).
static func gull_wing() -> Mesh:
	if _cache.has("gull_wing"):
		return _cache["gull_wing"]
	var st := _begin()
	var grey := Color(0.66, 0.7, 0.76)
	var tip := Color(0.15, 0.16, 0.18)
	_tri(st, Vector3(0, 0, -0.1), Vector3(0.45, 0.02, -0.06), Vector3(0, 0, 0.12), grey, true)
	_tri(st, Vector3(0.45, 0.02, -0.06), Vector3(0.42, 0.02, 0.08), Vector3(0, 0, 0.12), grey, true)
	_tri(st, Vector3(0.45, 0.02, -0.06), Vector3(0.72, 0.0, 0.06), Vector3(0.42, 0.02, 0.08), tip, true)
	return _finish("gull_wing", st)


## A cork float for the fishing line: red top, white bottom.
static func bobber() -> Mesh:
	if _cache.has("bobber"):
		return _cache["bobber"]
	var st := _begin()
	_loft(st, [[-0.13, 0.02, 0.02, 0.0], [-0.07, 0.11, 0.11, 0.0], [0.0, 0.13, 0.13, 0.0], [0.07, 0.11, 0.11, 0.0], [0.13, 0.02, 0.02, 0.0]],
		Color(0.95, 0.2, 0.15), Color(0.97, 0.97, 0.95))
	return _finish("bobber", st)


## A caught fish as it lies on deck: silver with a blue back, sized by kind.
static func catch_fish() -> Mesh:
	if _cache.has("catch_fish"):
		return _cache["catch_fish"]
	var st := _begin()
	var back := Color(0.25, 0.48, 0.72)
	var belly := Color(0.86, 0.88, 0.9)
	_loft(st, [[-0.22, 0.02, 0.03, 0.0], [-0.14, 0.04, 0.08, 0.0], [0.05, 0.035, 0.07, 0.0], [0.18, 0.012, 0.025, 0.0]], back, belly)
	for y in [-1.0, 1.0]:
		_tri(st, Vector3(0, 0, 0.17), Vector3(0, 0.1 * y, 0.28), Vector3(0, 0.02 * y, 0.22), back, true)
	_eyes(st, Vector3(0.035, 0.02, -0.15), 0.014)
	return _finish("catch_fish", st)
