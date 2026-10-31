class_name IslandShape
extends RefCounted
## The real outline of an island for the charts, traced from the same height function the 3D island is built
## from: the coastline (sea level), the green land inside the beach, and the high ground. Every outline is a
## star-shaped ring of world points around the island centre, worked out once per island and cached.

const SEGMENTS: int = 48
const STEPS: int = 48
const GRASS_H: float = 2.5  ## metres: above this the beach turns green
const HILL_SHARE: float = 0.5  ## of the island's peak height: the high ground drawn darker
const MIN_SHARE: float = 0.06  ## an outline never pinches to nothing, so polygons stay drawable

static var _cache: Dictionary = {}


## {"coast": PackedVector2Array, "land": ..., "hill": ...} in world metres. `index` is the island's place in
## WorldGen.islands (the 3D island's seed is 100 + index).
static func of(index: int, isl: Dictionary) -> Dictionary:
	var key: String = "%d:%s" % [index, isl["name"]]
	if _cache.has(key):
		return _cache[key]
	var body: Island = Island.make(float(isl["radius"]), 100 + index, str(isl["biome"]))
	body._noise = body._make_noise()
	var hill_h: float = body.peak_m * HILL_SHARE
	var centre: Vector2 = isl["pos"]
	var radii: Dictionary = {"coast": PackedFloat32Array(), "land": PackedFloat32Array(), "hill": PackedFloat32Array()}
	var reach: float = body.radius_m * 1.3
	for s in SEGMENTS:
		var dir: Vector2 = Vector2.from_angle(TAU * float(s) / float(SEGMENTS))
		var edge: Dictionary = {"coast": 0.0, "land": 0.0, "hill": 0.0}
		for k in range(STEPS, 0, -1):  # walk in from the sea: the first high point is the outermost one
			var r: float = reach * float(k) / float(STEPS)
			var h: float = body.ground_y(dir * r)
			if edge["coast"] == 0.0 and h > 0.0:
				edge["coast"] = r
			if edge["land"] == 0.0 and h > GRASS_H:
				edge["land"] = r
			if edge["hill"] == 0.0 and h > hill_h:
				edge["hill"] = r
				break
		var floor_r: float = body.radius_m * MIN_SHARE
		var coast: float = maxf(edge["coast"], body.radius_m * 0.3)
		var land: float = clampf(edge["land"], floor_r * 2.0, coast * 0.82)  # always a beach to see
		radii["coast"].append(coast)
		radii["land"].append(land)
		radii["hill"].append(clampf(edge["hill"], floor_r, land))
	body.free()
	var out: Dictionary = {}
	for k in radii:  # soften the steps of the march into a hand-drawn line
		var r: PackedFloat32Array = _smooth(_smooth(radii[k]))
		var ring := PackedVector2Array()
		for s in SEGMENTS:
			ring.append(centre + Vector2.from_angle(TAU * float(s) / float(SEGMENTS)) * r[s])
		out[k] = ring
	_cache[key] = out
	return out


static func _smooth(r: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n: int = r.size()
	out.resize(n)
	for i in n:
		out[i] = r[(i + n - 1) % n] * 0.25 + r[i] * 0.5 + r[(i + 1) % n] * 0.25
	return out


## A ring of world points mapped through `to_screen` (a Callable taking and returning Vector2).
static func project(ring: PackedVector2Array, to_screen: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(ring.size())
	for i in ring.size():
		pts[i] = to_screen.call(ring[i])
	return pts


## Draws one island as a chart picture: shallow water, beach, green land, high ground and an inked coastline.
## `scale_px` is pixels per metre, used to size the shallow-water halo.
static func draw(on: CanvasItem, shape: Dictionary, look: Dictionary, to_screen: Callable, ink: Color, scale_px: float) -> void:
	var coast: PackedVector2Array = project(shape["coast"], to_screen)
	var centre: Vector2 = Vector2.ZERO
	for p in coast:
		centre += p
	centre /= float(coast.size())
	var halo := PackedVector2Array()
	var grow: float = maxf(18.0 * scale_px, 2.5)
	for p in coast:
		halo.append(p + (p - centre).normalized() * grow)
	on.draw_colored_polygon(halo, Color(0.55, 0.8, 0.82, 0.55))
	var sand: Color = look["sand"]
	var grass: Color = look["grass"]
	on.draw_colored_polygon(coast, sand.lightened(0.25))
	on.draw_colored_polygon(project(shape["land"], to_screen), Look.cartoon(grass.lightened(0.2)))
	on.draw_colored_polygon(project(shape["hill"], to_screen), Look.cartoon(grass.lerp(look["forest"], 0.5).lightened(0.05)))
	var line: PackedVector2Array = coast.duplicate()
	line.append(coast[0])
	on.draw_polyline(line, ink, 1.6 if scale_px > 0.04 else 1.2, true)


## The look of a harbour on the chart: a little house with a roof in the flag's colour.
static func draw_harbour(on: CanvasItem, at: Vector2, flag: Color, ink: Color, s: float) -> void:
	var body := Rect2(at + Vector2(-s, -s * 0.2), Vector2(s * 2.0, s * 1.3))
	on.draw_rect(body, Color(0.96, 0.92, 0.82))
	on.draw_rect(body, ink, false, 1.2)
	var roof := PackedVector2Array([at + Vector2(-s * 1.35, -s * 0.2), at + Vector2(0, -s * 1.3), at + Vector2(s * 1.35, -s * 0.2)])
	on.draw_colored_polygon(roof, flag)
	roof.append(roof[0])
	on.draw_polyline(roof, ink, 1.2)


## A gold five-point star, for home.
static func draw_star(on: CanvasItem, at: Vector2, r: float, fill: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a: float = -PI * 0.5 + float(k) * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	on.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	on.draw_polyline(pts, ink, 1.4)


## A ship marker: an arrow pointing where she sails.
static func draw_arrow(on: CanvasItem, at: Vector2, dir: Vector2, s: float, col: Color, ink: Color) -> void:
	var f: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
	var side: Vector2 = f.orthogonal()
	var pts := PackedVector2Array([at + f * s * 1.4, at - f * s + side * s * 0.8, at - f * s * 0.5, at - f * s - side * s * 0.8])
	on.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	on.draw_polyline(pts, ink, 1.2)
