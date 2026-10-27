class_name WorldMap
extends RefCounted
## The Ashen Archipelago: 16 km x 16 km, centred on the origin (x east, z south), 1 km chunks.

const SIZE_M: float = 16000.0
const HALF: float = 8000.0
const CHUNK_M: float = 1000.0
const CHUNKS: int = 16

## Regions as Rect2 in (x, z) metres.
const REGIONS: Dictionary = {
	"albion_shallows": {"rect": Rect2(-8000, 4000, 4000, 4000), "faction": "navy", "weather": {"clear": 0.5, "overcast": 0.4, "rain": 0.1}},
	"merchants_reach": {"rect": Rect2(-2000, 4000, 4000, 4000), "faction": "merchant", "weather": {"clear": 0.6, "rain": 0.3, "overcast": 0.1}},
	"haven_waters": {"rect": Rect2(-2000, -2000, 4000, 4000), "faction": "pirate", "weather": {"clear": 0.4, "overcast": 0.3, "rain": 0.2, "storm": 0.1}},
	"coral_isles": {"rect": Rect2(-8000, -8000, 4000, 4000), "faction": "reef_folk", "weather": {"clear": 0.7, "rain": 0.3}},
	"iron_marches": {"rect": Rect2(4000, 4000, 4000, 4000), "faction": "iron_dominion", "weather": {"fog": 0.4, "storm": 0.3, "overcast": 0.3}},
	"dead_reach": {"rect": Rect2(-4000, -8000, 8000, 4000), "faction": "none", "weather": {"storm": 0.6, "fog": 0.4}},
}

const HAVEN_ROCK: Vector2 = Vector2(0, 0)


static func in_bounds(p: Vector2) -> bool:
	return absf(p.x) <= HALF and absf(p.y) <= HALF


static func chunk_of(p: Vector2) -> Vector2i:
	var cx: int = clampi(int(floor((p.x + HALF) / CHUNK_M)), 0, CHUNKS - 1)
	var cz: int = clampi(int(floor((p.y + HALF) / CHUNK_M)), 0, CHUNKS - 1)
	return Vector2i(cx, cz)


static func chunk_index(c: Vector2i) -> int:
	return c.y * CHUNKS + c.x


static func chunk_center(c: Vector2i) -> Vector2:
	return Vector2(-HALF + (c.x + 0.5) * CHUNK_M, -HALF + (c.y + 0.5) * CHUNK_M)


## Region containing p, or the nearest one for open water between regions.
static func region_at(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for id in REGIONS.keys():
		var r: Rect2 = REGIONS[id]["rect"]
		if r.has_point(p):
			return id
		var cx: float = clampf(p.x, r.position.x, r.end.x)
		var cz: float = clampf(p.y, r.position.y, r.end.y)
		var d: float = p.distance_to(Vector2(cx, cz))
		if d < best_d:
			best_d = d
			best = id
	return best
