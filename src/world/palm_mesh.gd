class_name PalmMesh
extends RefCounted
## A coconut palm built to be looked at from a deck: a leaning, ringed, tapering trunk with a flared foot, a crown of
## drooping fronds with a leaflet on every side of every stalk, a cluster of coconuts and a few dead fronds hanging.
## Three variants differ in lean, height and frond count. Vertex colours carry the palette.

const VARIANTS: Array[Dictionary] = [
	{"height": 8.5, "lean": 1.3, "fronds": 11, "reach": 3.6},
	{"height": 11.0, "lean": 2.4, "fronds": 12, "reach": 4.0},
	{"height": 6.0, "lean": 0.7, "fronds": 9, "reach": 3.2},
]
const TRUNK_A: Color = Color(0.46, 0.34, 0.22)
const TRUNK_B: Color = Color(0.3, 0.21, 0.13)
const FROND_A: Color = Color(0.14, 0.36, 0.1)
const FROND_B: Color = Color(0.34, 0.54, 0.16)
const DEAD: Color = Color(0.5, 0.38, 0.18)
const NUT: Color = Color(0.3, 0.2, 0.08)
const LEAFLETS: int = 11


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v in [a, c, b, b, c, d]:
		st.set_color(col)
		st.add_vertex(v)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


## The trunk's centre line at fraction f of its height.
static func trunk_at(v: Dictionary, f: float) -> Vector3:
	return Vector3(float(v["lean"]) * f * f * 1.4, f * float(v["height"]), float(v["lean"]) * 0.3 * sin(f * 3.0))


static var _cache: Dictionary = {}


## Build every shared palm now, while the world loads, so none is built mid-voyage.
static func prewarm() -> void:
	for v in VARIANTS.size():
		for sd in 4:
			build(v, sd)


## Palms are shared between islands: a few seed buckets per variant keep them varied without rebuilding the
## mesh every time an island streams in.
static func build(variant: int, seed_v: int = 1) -> ArrayMesh:
	var key: int = (variant % VARIANTS.size()) * 8 + posmod(seed_v, 4)
	if not _cache.has(key):
		_cache[key] = _build(variant, posmod(seed_v, 4) + 1)
	return _cache[key] as ArrayMesh


static func _build(variant: int, seed_v: int) -> ArrayMesh:
	var v: Dictionary = VARIANTS[variant % VARIANTS.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 977 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# trunk: rings of eight, flared at the foot, ringed by old frond scars
	var segs: int = 14
	var sides: int = 8
	for i in segs:
		var f0: float = i / float(segs)
		var f1: float = (i + 1) / float(segs)
		var r0: float = lerpf(0.36, 0.17, f0) + 0.28 * pow(1.0 - f0, 6.0)
		var r1: float = lerpf(0.36, 0.17, f1) + 0.28 * pow(1.0 - f1, 6.0)
		if i % 2 == 1:
			r0 *= 1.07
		var c0: Vector3 = trunk_at(v, f0)
		var c1: Vector3 = trunk_at(v, f1)
		var col: Color = TRUNK_A.lerp(TRUNK_B, float(i % 2) * 0.55 + rng.randf() * 0.12)
		for k in sides:
			var a0: float = TAU * k / sides
			var a1: float = TAU * (k + 1) / sides
			var p00: Vector3 = c0 + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p01: Vector3 = c0 + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var p10: Vector3 = c1 + Vector3(cos(a0) * r1, 0.0, sin(a0) * r1)
			var p11: Vector3 = c1 + Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
			_quad(st, p00, p01, p10, p11, col)
	var top: Vector3 = trunk_at(v, 1.0)
	# fronds: a curved stalk with leaflets pairs that droop away from it
	var n: int = int(v["fronds"])
	for fi in n:
		var ang: float = TAU * fi / n + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var length: float = float(v["reach"]) * rng.randf_range(0.85, 1.15)
		var lift: float = rng.randf_range(0.5, 1.4) if fi % 3 != 0 else rng.randf_range(1.2, 2.0)
		var dead: bool = fi % 7 == 6
		var col_f: Color = FROND_A.lerp(FROND_B, rng.randf())
		if dead:
			col_f = DEAD
			lift = -0.4
		var prev: Vector3 = top
		for li in LEAFLETS:
			var t: float = (li + 1) / float(LEAFLETS)
			var pt: Vector3 = top + dir * (length * t) + Vector3(0.0, lift * sin(t * 2.4) - 1.9 * t * t * (1.2 if dead else 1.0), 0.0)
			var w: float = 0.05
			_quad(st, prev + side * w, prev - side * w, pt + side * w, pt - side * w, col_f.darkened(0.25))
			var leaf_len: float = 1.15 * sin(t * PI * 0.85 + 0.25) + 0.15
			for s in [-1.0, 1.0]:
				var base: Vector3 = (prev + pt) * 0.5
				var droop := Vector3(0.0, -0.55 * leaf_len, 0.0)
				var tip: Vector3 = base + side * (s * leaf_len) + dir * 0.35 + droop
				var half: Vector3 = dir * 0.13
				_tri(st, base - half, base + half, tip, col_f)
				_tri(st, base + half, base - half, tip, col_f.darkened(0.12))
			prev = pt
	# coconuts
	for k in 4:
		var a: float = TAU * k / 4.0 + 0.4
		var at: Vector3 = top + Vector3(cos(a) * 0.28, -0.35 - 0.08 * (k % 2), sin(a) * 0.28)
		for t in 8:
			var a0: float = TAU * t / 8.0
			var a1: float = TAU * (t + 1) / 8.0
			_tri(st, at + Vector3(0.0, 0.2, 0.0), at + Vector3(cos(a0) * 0.18, 0.0, sin(a0) * 0.18), at + Vector3(cos(a1) * 0.18, 0.0, sin(a1) * 0.18), NUT)
			_tri(st, at + Vector3(0.0, -0.2, 0.0), at + Vector3(cos(a1) * 0.18, 0.0, sin(a1) * 0.18), at + Vector3(cos(a0) * 0.18, 0.0, sin(a0) * 0.18), NUT.darkened(0.2))
	st.generate_normals()
	return st.commit()
