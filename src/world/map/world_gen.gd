class_name WorldGen
extends RefCounted
## Deterministic layout of the archipelago: 24 named islands and the points of interest on them.

const SEED: int = 20240601
const ISLAND_COUNTS: Dictionary = {
	"albion_shallows": 4, "merchants_reach": 4, "haven_waters": 4, "coral_isles": 4, "iron_marches": 4, "dead_reach": 4,
}
const POI_COUNTS: Dictionary = {
	"port": 16, "fort": 6, "base": 8, "treasure_island": 20, "cave": 10, "wreck": 12, "reef": 15, "whirlpool": 3, "lighthouse": 8,
}
const MIN_ISLAND_GAP_M: float = 700.0
const HARBOR_OFFSET_M: float = 200.0

var islands: Array[Dictionary] = []  ## {name, pos Vector2, radius, region}
var pois: Array[Dictionary] = []  ## {type, pos Vector2, island int (-1 for open water)}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = SEED
	_place_islands()
	_place_pois()


func _place_islands() -> void:
	islands.append(_named({"pos": WorldMap.HAVEN_ROCK, "radius": 160.0, "region": "haven_waters"}, 0))
	for region in ISLAND_COUNTS.keys():
		var rect: Rect2 = WorldMap.REGIONS[region]["rect"]
		var want: int = ISLAND_COUNTS[region] - (1 if region == "haven_waters" else 0)
		var made: int = 0
		var tries: int = 0
		while made < want and tries < 5000:
			tries += 1
			var p := Vector2(_rng.randf_range(rect.position.x + 400.0, rect.end.x - 400.0), _rng.randf_range(rect.position.y + 400.0, rect.end.y - 400.0))
			var r: float = _rng.randf_range(120.0, 300.0)
			if _clear(p, r, MIN_ISLAND_GAP_M):
				islands.append(_named({"pos": p, "radius": r, "region": region}, made + (1 if region == "haven_waters" else 0)))
				made += 1


## Adds the hand-made name, city, tier and biome for the `slot`-th island of its region.
func _named(isl: Dictionary, slot: int) -> Dictionary:
	var e: Dictionary = IslandData.entries_for(isl["region"])[slot]
	isl["name"] = e["name"]
	isl["city"] = e["city"]
	isl["tier"] = e["tier"]
	isl["biome"] = e["biome"]
	isl["note"] = e["note"]
	return isl


func index_of(island_name: String) -> int:
	for i in islands.size():
		if islands[i]["name"] == island_name:
			return i
	return -1


## The islands that have a harbour, in layout order.
func city_islands() -> Array[int]:
	var out: Array[int] = []
	for i in islands.size():
		if islands[i]["city"] != "":
			out.append(i)
	return out


## Angle from an island out to its harbour: facing the centre of the map, so every pier points the same way
## on each run, and Haven Rock keeps its south-facing pier.
func harbor_angle(island_index: int) -> float:
	if island_index == 0:
		return PI * 0.5
	var to_centre: Vector2 = -islands[island_index]["pos"]
	return to_centre.angle() if to_centre.length() > 1.0 else PI * 0.5


func _clear(p: Vector2, r: float, gap: float) -> bool:
	for i in islands:
		if p.distance_to(i["pos"]) < r + i["radius"] + gap:
			return false
	return true


func harbor_point(island_index: int, angle: float) -> Vector2:
	var i: Dictionary = islands[island_index]
	return i["pos"] + Vector2.from_angle(angle) * (i["radius"] + HARBOR_OFFSET_M)


func _place_pois() -> void:
	# Every city island gets its port; Haven Rock is port 0, the start hub.
	for idx in city_islands():
		pois.append({"type": "port", "pos": harbor_point(idx, harbor_angle(idx)), "island": idx, "city": islands[idx]["city"]})
	var counters: Dictionary = {}
	for type in ["fort", "base", "lighthouse", "cave"]:
		var n: int = POI_COUNTS[type]
		for k in n:
			var idx: int = (k * 5 + (3 if type != "port" else 1) + counters.size() * 7) % islands.size()
			var ang: float = _rng.randf() * TAU
			pois.append({"type": type, "pos": harbor_point(idx, ang), "island": idx})
		counters[type] = true
	for type in ["treasure_island", "wreck", "reef", "whirlpool"]:
		for k in POI_COUNTS[type]:
			var region_ids: Array = WorldMap.REGIONS.keys()
			var region: String = "dead_reach" if type == "whirlpool" else region_ids[_rng.randi() % region_ids.size()]
			var rect: Rect2 = WorldMap.REGIONS[region]["rect"]
			for attempt in 200:
				var p := Vector2(_rng.randf_range(rect.position.x + 200.0, rect.end.x - 200.0), _rng.randf_range(rect.position.y + 200.0, rect.end.y - 200.0))
				if _clear(p, 40.0, 150.0):
					pois.append({"type": type, "pos": p, "island": -1})
					break


func count_of(type: String) -> int:
	var n: int = 0
	for p in pois:
		if p["type"] == type:
			n += 1
	return n


## True if p lies on land (inside any island disc).
func is_land(p: Vector2) -> bool:
	for i in islands:
		if p.distance_to(i["pos"]) < i["radius"]:
			return true
	return false
