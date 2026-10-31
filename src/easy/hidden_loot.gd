class_name HiddenLoot
extends RefCounted
## Hidden treasure in the shallows round every island. A spot cannot be seen until the parrot spots it (the ship
## within SPOT_M); then a floating chest marks it, and sailing up to it (PICKUP_M) collects gold and, most times,
## a seashell or a rare pirate flag for the collection book. A spot fills again REFILL_DAYS after it was emptied.

const PER_ISLAND: int = 2
const SHORE_GAP_M: float = 90.0  ## how far off the island's edge the spot floats, in open water
const SPOT_M: float = 380.0
const PICKUP_M: float = 26.0
const REFILL_DAYS: int = 7
const GOLD: Array[int] = [25, 70]
const SHELL_CHANCE: float = 0.75
const FLAG_CHANCE: float = 0.15  ## when a found-only flag is still missing


static func spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gen: WorldGen = PortData.gen()
	for isl: Dictionary in gen.islands:
		var nm: String = str(isl["name"])
		for i in PER_ISLAND:
			var h: int = absi(hash(nm + ":" + str(i)))
			var ang: float = TAU * float(h % 3600) / 3600.0
			var r: float = float(isl["radius"]) + SHORE_GAP_M + float(h % 50)
			out.append({"id": "%s:%d" % [nm, i], "pos": (isl["pos"] as Vector2) + Vector2.from_angle(ang) * r, "island": nm})
	return out


## Whether the spot is full of loot today.
static func is_full(state: Dictionary, spot_id: String) -> bool:
	var loot: Dictionary = EasyPlay.store(state)["loot"]
	if not loot.has(spot_id):
		return true
	return int(state.get("day", 0)) - int(loot[spot_id]) >= REFILL_DAYS


## Full spots within `radius` of `pos`, nearest first.
static func near(state: Dictionary, pos: Vector2, radius: float = SPOT_M, all: Array[Dictionary] = []) -> Array[Dictionary]:
	var src: Array[Dictionary] = all if not all.is_empty() else spots()
	var out: Array[Dictionary] = []
	for s in src:
		if (s["pos"] as Vector2).distance_to(pos) <= radius and is_full(state, str(s["id"])):
			out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector2).distance_to(pos) < (b["pos"] as Vector2).distance_to(pos))
	return out


## What the spot holds today; the same answer every time it is asked on the same day.
static func roll(state: Dictionary, spot_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s|%d|%d" % [spot_id, int(state.get("seed", 1)), int(state.get("day", 0)) / REFILL_DAYS]))
	var gold: int = rng.randi_range(GOLD[0], GOLD[1])
	if int(state.get("difficulty", 1)) == AimAssist.EASY:
		gold = int(gold * 1.5)
	var item: String = ""
	var missing_flags: PackedStringArray = []
	for f in CollectionData.found_flag_ids():
		if not EasyPlay.has_item(state, f):
			missing_flags.append(f)
	var r: float = rng.randf()
	if not missing_flags.is_empty() and r < FLAG_CHANCE:
		item = missing_flags[rng.randi() % missing_flags.size()]
	elif r < FLAG_CHANCE + SHELL_CHANCE:
		var total: int = 0
		for s in CollectionData.SHELLS:
			total += int(s["weight"])
		var pick: int = rng.randi() % total
		for s in CollectionData.SHELLS:
			pick -= int(s["weight"])
			if pick < 0:
				item = str(s["id"])
				break
	return {"gold": gold, "item": item}


## Empties the spot into the state. Returns what was taken, with "new" true when the item is a new book entry.
static func take(state: Dictionary, spot_id: String) -> Dictionary:
	if not is_full(state, spot_id):
		return {}
	var got: Dictionary = roll(state, spot_id)
	var s: Dictionary = EasyPlay.store(state)
	s["loot"][spot_id] = int(state.get("day", 0))
	s["finds"] = int(s["finds"]) + 1
	state["gold"] = int(state.get("gold", 0)) + int(got["gold"])
	got["new"] = EasyPlay.collect(state, str(got["item"])) if str(got["item"]) != "" else false
	return got


## A compass word (north, north_east, ...) for the direction from `from` to `to`. -Z is north on the chart.
static func compass(from: Vector2, to: Vector2) -> String:
	var d: Vector2 = to - from
	var bearing: float = fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)
	var names: PackedStringArray = ["north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west"]
	return names[int(round(bearing / 45.0)) % 8]
