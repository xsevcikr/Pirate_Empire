class_name Landings
extends RefCounted
## Islands without a harbour still have a landing: a beach where the ship can drop anchor and send a boat ashore
## for water, food, salvage or a bit of luck, once every few days. Each landing has a kind that sets what is
## found there and the props on the beach. Skull Atoll is left out: it is the player's own lagoon.

const RESERVED: Array[String] = ["Skull Atoll"]
## island name -> kind
const KINDS: Dictionary = {
	"Admiralty Rock": "prison", "Moana Reef": "ruins", "Cinder Bay": "volcano", "Wraith Isle": "chapel",
	"Bonefield Shoals": "wreck", "Frostmourn": "ice", "Kraken's Maw": "atoll",
}
## kind -> supplies found (units), gold range, wounded healed, chance a castaway or prisoner joins the crew
const YIELDS: Dictionary = {
	"prison": {"supplies": {"water": 3.0}, "gold": [0, 40], "heal": 0, "recruit": 0.5},
	"ruins": {"supplies": {"food": 3.0}, "gold": [60, 220], "heal": 0, "recruit": 0.0},
	"volcano": {"supplies": {"water": 1.0}, "gold": [20, 120], "heal": 4, "recruit": 0.0},
	"chapel": {"supplies": {"medicine": 2.0}, "gold": [30, 160], "heal": 2, "recruit": 0.0},
	"wreck": {"supplies": {"timber": 4.0, "small_arms": 2.0}, "gold": [40, 180], "heal": 0, "recruit": 0.2},
	"ice": {"supplies": {"water": 6.0}, "gold": [0, 60], "heal": 0, "recruit": 0.0},
	"atoll": {"supplies": {"food": 4.0, "water": 2.0}, "gold": [0, 90], "heal": 0, "recruit": 0.1},
}
const COOLDOWN_DAYS: int = 3
const OFFSHORE_M: float = 110.0  ## anchorage distance beyond the island's radius
const RADIUS_M: float = 120.0
const MAX_SPEED_KN: float = 3.0


static func has_landing(isl: Dictionary) -> bool:
	return str(isl["city"]) == "" and KINDS.has(str(isl["name"])) and not RESERVED.has(str(isl["name"]))


static func kind_of(isl: Dictionary) -> String:
	return str(KINDS.get(str(isl["name"]), ""))


## Indices of every island with a landing, in layout order.
static func islands(g: WorldGen) -> Array[int]:
	var out: Array[int] = []
	for i in g.islands.size():
		if has_landing(g.islands[i]):
			out.append(i)
	return out


## Direction from the island to its anchorage: towards the middle of the map, like the harbours.
static func angle(g: WorldGen, i: int) -> float:
	return g.harbor_angle(i)


static func anchorage(g: WorldGen, i: int) -> Vector2:
	var isl: Dictionary = g.islands[i]
	return (isl["pos"] as Vector2) + Vector2.from_angle(angle(g, i)) * (float(isl["radius"]) + OFFSHORE_M)


## The island whose anchorage is within reach of `p`, or -1.
static func near(g: WorldGen, p: Vector2, radius: float = RADIUS_M) -> int:
	for i in islands(g):
		if anchorage(g, i).distance_to(p) <= radius:
			return i
	return -1


static func days_until_ready(state: Dictionary, island_name: String) -> int:
	var visits: Dictionary = state.get("landings", {})
	if not visits.has(island_name):
		return 0
	return maxi(int(visits[island_name]) + COOLDOWN_DAYS - int(state["day"]), 0)


## Sends the boat ashore: supplies (as far as the hold has room), gold, wounded rested and maybe a new hand.
## Returns {"ok", "kind", "supplies": {id: units}, "gold", "healed", "recruit"} or {"ok": false, "wait": days}.
static func go_ashore(state: Dictionary, island_name: String, rng: RandomNumberGenerator) -> Dictionary:
	var kind: String = str(KINDS.get(island_name, ""))
	if kind == "" or RESERVED.has(island_name):
		return {"ok": false, "wait": 0}
	var wait: int = days_until_ready(state, island_name)
	if wait > 0:
		return {"ok": false, "wait": wait}
	var y: Dictionary = YIELDS[kind]
	var got: Dictionary = {}
	for id: String in y["supplies"]:
		var w: float = float(PortData.SUPPLIES[id]["weight"])
		var units: float = minf(float(y["supplies"][id]), floorf(PortService.cargo_free(state) / w))
		if units <= 0.0:
			continue
		state["supplies"][id] = float(state["supplies"].get(id, 0.0)) + units
		got[id] = units
	var gold: int = rng.randi_range(int(y["gold"][0]), int(y["gold"][1]))
	state["gold"] = int(state["gold"]) + gold
	var healed: int = mini(int(y["heal"]), int(state.get("wounded", 0)))
	state["wounded"] = int(state.get("wounded", 0)) - healed
	var recruit: bool = rng.randf() < float(y["recruit"]) and PortService.crew_room(state) > 0
	if recruit:
		state["roster"].append({"name": PortService.NAMES[rng.randi() % PortService.NAMES.size()], "type": "green", "level": 1, "xp": 0})
		state["crew"] = int(state["crew"]) + 1
	if not state.has("landings"):
		state["landings"] = {}
	state["landings"][island_name] = int(state["day"])
	return {"ok": true, "kind": kind, "supplies": got, "gold": gold, "healed": healed, "recruit": recruit}


## One line for the toast: what the boat brought back, or how long until the beach is worth another visit.
static func summary(r: Dictionary, island_name: String) -> String:
	if not bool(r.get("ok", false)):
		return Loc.t("land.wait") % [island_name, int(r.get("wait", 0))]
	var parts: Array[String] = []
	for id: String in r["supplies"]:
		parts.append("%d %s" % [int(r["supplies"][id]), Loc.t("supply." + id)])
	if int(r["gold"]) > 0:
		parts.append("%d g" % int(r["gold"]))
	if int(r["healed"]) > 0:
		parts.append(Loc.t("land.healed") % int(r["healed"]))
	if bool(r["recruit"]):
		parts.append(Loc.t("land.recruit"))
	var found: String = ", ".join(parts) if not parts.is_empty() else Loc.t("land.nothing")
	return Loc.t("land.kind." + str(r["kind"])) % island_name + " " + found
