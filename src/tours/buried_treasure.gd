class_name BuriedTreasure
extends RefCounted
## Treasure maps with buried loot: a map marks an X on one island's shore. Sail to the X, slow down and the crew
## rows ashore and digs up the chest: gold, trade goods and, on the better maps, gems. Maps are sold in taverns
## (one a port every few days) and found in the cabins of boarded ships. Pure functions on state["buried"]:
## {"maps": [map], "seq": int, "dug": int, "gold_dug": int, "bought": {port_id: window}}.
## A map is {"id", "island", "tier", "x", "y", "shore"} with the X stored as two floats so it survives JSON.

const TIERS: Dictionary = {
	"common": {"gold": [250, 600], "goods": ["rum", "tobacco", "sugar", "tea"], "units": [6, 14], "gems": [0, 0], "price": 150},
	"rich": {"gold": [700, 1600], "goods": ["spices", "silk", "tea"], "units": [8, 16], "gems": [1, 4], "price": 420},
	"legendary": {"gold": [2000, 4500], "goods": ["silk", "spices"], "units": [6, 12], "gems": [4, 10], "price": 0},
}
const TIER_ORDER: Array[String] = ["common", "rich", "legendary"]
const MAX_HELD: int = 3
const OFFER_DAYS: int = 3  ## a tavern has one map for sale every this many days
const RICH_OFFER_CHANCE: float = 0.35  ## at taverns of level 2 and up
const SHORE_OFFSET_M: float = 80.0  ## the X lies this far off the island's edge, in water a boat can row from
const CLEARANCE_M: float = 40.0  ## and at least this far from every other island
const DIG_RADIUS_M: float = 90.0
const DIG_MAX_SPEED_KN: float = 3.0
## Chance a boarded ship carries a map, and of a rich or legendary one when it does.
const DROP_RATE: Dictionary = {"merchant": 0.06, "pirate": 0.14, "navy": 0.05, "rival": 0.35, "crew": 0.25, "treasure_galleon": 0.6}
const DROP_RICH: float = 0.30
const DROP_LEGENDARY: float = 0.08
const SHORES: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]


static func root(state: Dictionary) -> Dictionary:
	if not (state.get("buried") is Dictionary):
		state["buried"] = {}
	var b: Dictionary = state["buried"]
	for k: String in ["maps", "bought"]:
		if not b.has(k):
			b[k] = [] if k == "maps" else {}
	for k: String in ["seq", "dug", "gold_dug"]:
		b[k] = int(b.get(k, 0))
	return b


static func maps(state: Dictionary) -> Array:
	return root(state)["maps"]


static func can_hold_more(state: Dictionary) -> bool:
	return maps(state).size() < MAX_HELD


## Islands a map may point at: the wild ones, with no town to see the digging, and never the player's own lagoon.
static func candidate_islands() -> Array[int]:
	var out: Array[int] = []
	var g: WorldGen = PortData.gen()
	for i in g.islands.size():
		if str(g.islands[i]["city"]) == "" and not Landings.RESERVED.has(str(g.islands[i]["name"])):
			out.append(i)
	return out


static func spot(m: Dictionary) -> Vector2:
	return Vector2(float(m["x"]), float(m["y"]))


## Compass side of the island the X lies on, for the clue. World +z is south on the chart.
static func shore_of(dir: Vector2) -> String:
	var a: float = atan2(dir.x, -dir.y)
	return SHORES[posmod(roundi(a / (TAU / 8.0)), 8)]


static func _clear_of_islands(p: Vector2, except: int) -> bool:
	var g: WorldGen = PortData.gen()
	for i in g.islands.size():
		if i != except and p.distance_to(g.islands[i]["pos"]) < float(g.islands[i]["radius"]) + CLEARANCE_M:
			return false
	return absf(p.x) < WorldMap.SIZE_M * 0.5 and absf(p.y) < WorldMap.SIZE_M * 0.5


## A new map of `tier` (not yet held). Islands that already have a held map are skipped where possible.
static func make_map(state: Dictionary, tier: String, rng: RandomNumberGenerator) -> Dictionary:
	var g: WorldGen = PortData.gen()
	var taken: Array = []
	for m: Dictionary in maps(state):
		taken.append(str(m["island"]))
	var pool: Array[int] = []
	for i in candidate_islands():
		if not taken.has(str(g.islands[i]["name"])):
			pool.append(i)
	if pool.is_empty():
		pool = candidate_islands()
	var idx: int = pool[rng.randi_range(0, pool.size() - 1)]
	var isl: Dictionary = g.islands[idx]
	var p: Vector2 = isl["pos"]
	var dir: Vector2 = Vector2.UP
	for attempt in 16:
		dir = Vector2.from_angle(rng.randf_range(0.0, TAU))
		p = (isl["pos"] as Vector2) + dir * (float(isl["radius"]) + SHORE_OFFSET_M)
		if _clear_of_islands(p, idx):
			break
	var b: Dictionary = root(state)
	b["seq"] = int(b["seq"]) + 1
	return {"id": "bmap_%d" % int(b["seq"]), "island": str(isl["name"]), "tier": tier, "x": p.x, "y": p.y, "shore": shore_of(dir)}


## Keeps a map when there is room in the chart case. Returns true when it was added.
static func add_map(state: Dictionary, m: Dictionary) -> bool:
	if m.is_empty() or not can_hold_more(state):
		return false
	maps(state).append(m)
	return true


# ---- taverns ---------------------------------------------------------------------------------------------

static func _window(state: Dictionary) -> int:
	return int(state["day"]) / OFFER_DAYS


static func _offer_rng(state: Dictionary, port_id: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(state.get("seed", 1)) * 977 + port_id.hash() + _window(state) * 131
	return r


## The tier the tavern's map seller offers right now, or "" when the map of this window was already bought.
static func offer_tier(state: Dictionary, port_id: String) -> String:
	if int(root(state)["bought"].get(port_id, -1)) == _window(state):
		return ""
	var r: RandomNumberGenerator = _offer_rng(state, port_id)
	var rich: bool = int(PortData.PORTS[port_id]["tavern_level"]) >= 2 and r.randf() < RICH_OFFER_CHANCE
	return "rich" if rich else "common"


static func offer_price(state: Dictionary, port_id: String) -> int:
	var tier: String = offer_tier(state, port_id)
	return 0 if tier == "" else int(round(float(TIERS[tier]["price"]) * PortService.price_mult(state)))


## Buys the tavern's map. Returns the map, or {} when there is none, no gold or no room.
static func buy_offer(state: Dictionary, port_id: String) -> Dictionary:
	var tier: String = offer_tier(state, port_id)
	var price: int = offer_price(state, port_id)
	if tier == "" or not can_hold_more(state) or int(state["gold"]) < price:
		return {}
	var m: Dictionary = make_map(state, tier, _offer_rng(state, port_id))
	state["gold"] = int(state["gold"]) - price
	add_map(state, m)
	root(state)["bought"][port_id] = _window(state)
	return m


# ---- loot from boarded ships ------------------------------------------------------------------------------

## A boarded ship's cabin may hold a map. Returns the map that was added, or {}.
static func roll_drop(state: Dictionary, source: String, rng: RandomNumberGenerator) -> Dictionary:
	var rate: float = float(DROP_RATE.get(source, 0.0))
	if rate <= 0.0 or not can_hold_more(state) or rng.randf() >= rate:
		return {}
	var r: float = rng.randf()
	var tier: String = "legendary" if r < DROP_LEGENDARY else ("rich" if r < DROP_LEGENDARY + DROP_RICH else "common")
	var m: Dictionary = make_map(state, tier, rng)
	add_map(state, m)
	return m


# ---- digging -----------------------------------------------------------------------------------------------

## Index of the held map whose X is within reach of `pos`, or -1.
static func near(state: Dictionary, pos: Vector2, radius: float = DIG_RADIUS_M) -> int:
	var list: Array = maps(state)
	for i in list.size():
		if spot(list[i]).distance_to(pos) <= radius:
			return i
	return -1


## Digs up the chest of map `index`: gold straight to the purse, goods and gems into the hold as far as there is
## room. The map is used up. Returns {"ok", "tier", "island", "gold", "goods": {good: units}, "left": units}.
static func dig(state: Dictionary, index: int, rng: RandomNumberGenerator) -> Dictionary:
	var list: Array = maps(state)
	if index < 0 or index >= list.size():
		return {"ok": false}
	var m: Dictionary = list[index]
	var t: Dictionary = TIERS[str(m["tier"])]
	var gold: int = int(snappedf(rng.randi_range(int(t["gold"][0]), int(t["gold"][1])), 10.0))
	var found: Dictionary = {}
	var goods: Array = t["goods"]
	found[goods[rng.randi_range(0, goods.size() - 1)]] = float(rng.randi_range(int(t["units"][0]), int(t["units"][1])))
	var gems: int = rng.randi_range(int(t["gems"][0]), int(t["gems"][1]))
	if gems > 0:
		found["gems"] = float(gems)
	var got: Dictionary = {}
	var left: float = 0.0
	for g: String in found:
		var room: float = floorf(maxf(PortService.cargo_free(state), 0.0) / float(Goods.DATA[g]["weight"]))
		var units: float = minf(float(found[g]), room)
		left += float(found[g]) - units
		if units > 0.0:
			state["cargo"][g] = float(state["cargo"].get(g, 0.0)) + units
			got[g] = units
	state["gold"] = int(state["gold"]) + gold
	list.remove_at(index)
	var b: Dictionary = root(state)
	b["dug"] = int(b["dug"]) + 1
	b["gold_dug"] = int(b["gold_dug"]) + gold
	return {"ok": true, "tier": str(m["tier"]), "island": str(m["island"]), "gold": gold, "goods": got, "left": left}


# ---- text ---------------------------------------------------------------------------------------------------

static func clue(m: Dictionary) -> String:
	return Loc.t("buried.clue") % [Loc.t("buried.tier." + str(m["tier"])), Loc.t("buried.shore." + str(m["shore"])), str(m["island"])]


static func summary(r: Dictionary) -> String:
	if not bool(r.get("ok", false)):
		return Loc.t("buried.nothing")
	var parts: Array[String] = ["%d g" % int(r["gold"])]
	for g: String in r["goods"]:
		parts.append("%d %s" % [int(r["goods"][g]), Loc.t("good." + g)])
	var line: String = Loc.t("buried.dug") % [str(r["island"]), ", ".join(parts)]
	if float(r["left"]) > 0.0:
		line += " " + Loc.t("buried.left") % int(r["left"])
	return line
