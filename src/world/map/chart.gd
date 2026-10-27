class_name Chart
extends RefCounted
## Maths of the chart screen: world <-> screen mapping, routes around islands and their length and travel time.

const MS_PER_KN: float = 0.5144
const CRUISE_FRACTION: float = 0.7  ## of top speed, for ETAs
const CLEARANCE_M: float = 80.0

var gen: WorldGen
var nav: SeaNav


func _init(g: WorldGen = null) -> void:
	gen = g if g != null else PortData.gen()
	nav = SeaNav.new(gen)


static func to_screen(p: Vector2, rect: Rect2) -> Vector2:
	return rect.position + Vector2((p.x + WorldMap.HALF) / WorldMap.SIZE_M, (p.y + WorldMap.HALF) / WorldMap.SIZE_M) * rect.size


static func to_world(s: Vector2, rect: Rect2) -> Vector2:
	var f: Vector2 = (s - rect.position) / rect.size
	return Vector2(f.x * WorldMap.SIZE_M - WorldMap.HALF, f.y * WorldMap.SIZE_M - WorldMap.HALF)


## True when the straight line a-b stays clear of every island (plus a margin).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps: int = int(ceil(a.distance_to(b) / 60.0))
	for k in steps + 1:
		var p: Vector2 = a.lerp(b, float(k) / float(maxi(steps, 1)))
		for isl in gen.islands:
			if p.distance_to(isl["pos"]) < float(isl["radius"]) + CLEARANCE_M:
				return false
	return true


## Waypoints from a to b: straight if open water allows it, else around the islands. Starts after `a`.
func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	if line_clear(a, b):
		return PackedVector2Array([b])
	var raw: PackedVector2Array = nav.find_path(a, b)
	if raw.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array()
	var at: Vector2 = a
	var i: int = 0
	while i < raw.size():
		var far: int = i
		for j in range(raw.size() - 1, i - 1, -1):
			if line_clear(at, raw[j]):
				far = j
				break
		out.append(raw[far])
		at = raw[far]
		i = far + 1
	if out[out.size() - 1] != b and line_clear(at, b):
		out.append(b)
	return out


static func length_m(from: Vector2, waypoints: PackedVector2Array) -> float:
	var d: float = 0.0
	var at: Vector2 = from
	for w in waypoints:
		d += at.distance_to(w)
		at = w
	return d


## Game hours to sail `metres` at the cruising fraction of the ship's top speed.
static func eta_hours(metres: float, max_speed_kn: float) -> float:
	return metres / (max_speed_kn * CRUISE_FRACTION * MS_PER_KN) / 3600.0


static func eta_text(hours: float) -> String:
	var total_min: int = int(round(hours * 60.0))
	return "%d h %02d min" % [total_min / 60, total_min % 60]
