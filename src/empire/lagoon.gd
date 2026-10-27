class_name Lagoon
extends RefCounted
## The player's lagoon as plain functions on the save state, so the rules can be tested without the world or UI.
## state["lagoon"] is empty until the atoll is claimed, then:
## {rank, buildings: [{t, x, y, lv, rot, dmg}], piers: [level...], pop, chest, larder, rest_day, raids, repelled}

const LARDER_CAP: float = 80.0


static func claimed(s: Dictionary) -> bool:
	return not (s.get("lagoon", {}) as Dictionary).is_empty()


static func data(s: Dictionary) -> Dictionary:
	return s["lagoon"]


static func new_lagoon() -> Dictionary:
	return {"rank": 0, "buildings": [], "piers": [], "pop": 0, "chest": 0.0, "larder": 0.0, "rest_day": -1, "raids": 0, "repelled": 0}


static func claim(s: Dictionary) -> bool:
	if claimed(s) or int(s["gold"]) < LagoonData.CLAIM_COST:
		return false
	s["gold"] = int(s["gold"]) - LagoonData.CLAIM_COST
	s["lagoon"] = new_lagoon()
	return true


## JSON brings every number back as a float; put the integer fields back.
static func restore_types(s: Dictionary) -> void:
	if not claimed(s):
		return
	var l: Dictionary = data(s)
	for k in ["rank", "pop", "rest_day", "raids", "repelled"]:
		l[k] = int(l.get(k, 0))
	for b: Dictionary in l["buildings"]:
		for k in ["x", "y", "lv", "rot"]:
			b[k] = int(b[k])
	var piers: Array = l["piers"]
	for i in piers.size():
		piers[i] = int(piers[i])


# ---- plots and buildings ---------------------------------------------------------------------

static func rank_of(s: Dictionary) -> int:
	return int(data(s)["rank"])


static func building_at(s: Dictionary, c: Vector2i) -> Dictionary:
	for b: Dictionary in data(s)["buildings"]:
		if int(b["x"]) == c.x and int(b["y"]) == c.y:
			return b
	return {}


## Why a building cannot go on a plot ("" when it can): "closed", "taken", "gold".
static func place_problem(s: Dictionary, type: String, c: Vector2i) -> String:
	if not LagoonData.cell_open(rank_of(s), c):
		return "closed"
	if not building_at(s, c).is_empty():
		return "taken"
	if int(s["gold"]) < LagoonData.cost(type, 1):
		return "gold"
	return ""


static func place(s: Dictionary, type: String, c: Vector2i, rot: int = 0) -> bool:
	if place_problem(s, type, c) != "":
		return false
	s["gold"] = int(s["gold"]) - LagoonData.cost(type, 1)
	data(s)["buildings"].append({"t": type, "x": c.x, "y": c.y, "lv": 1, "rot": posmod(rot, 4), "dmg": false})
	return true


## Gold for the next level of the building on a plot, -1 when there is none or it is at the top.
static func upgrade_cost(s: Dictionary, c: Vector2i) -> int:
	var b: Dictionary = building_at(s, c)
	if b.is_empty() or int(b["lv"]) >= LagoonData.levels(b["t"]):
		return -1
	return LagoonData.cost(b["t"], int(b["lv"]) + 1)


static func upgrade(s: Dictionary, c: Vector2i) -> bool:
	var cost: int = upgrade_cost(s, c)
	if cost < 0 or cost > int(s["gold"]) or bool(building_at(s, c)["dmg"]):
		return false
	s["gold"] = int(s["gold"]) - cost
	building_at(s, c)["lv"] = int(building_at(s, c)["lv"]) + 1
	return true


## Half of everything spent on the building comes back.
static func demolish(s: Dictionary, c: Vector2i) -> int:
	var b: Dictionary = building_at(s, c)
	if b.is_empty():
		return 0
	var spent: int = 0
	for lv in range(1, int(b["lv"]) + 1):
		spent += LagoonData.cost(b["t"], lv)
	var refund: int = int(spent * LagoonData.DEMOLISH_REFUND)
	data(s)["buildings"].erase(b)
	s["gold"] = int(s["gold"]) + refund
	return refund


static func rotate(s: Dictionary, c: Vector2i) -> void:
	var b: Dictionary = building_at(s, c)
	if not b.is_empty():
		b["rot"] = (int(b["rot"]) + 1) % 4


static func repair_cost(s: Dictionary, c: Vector2i) -> int:
	var b: Dictionary = building_at(s, c)
	if b.is_empty() or not bool(b["dmg"]):
		return -1
	return int(LagoonData.cost(b["t"], int(b["lv"])) * LagoonData.REPAIR_SHARE)


static func repair(s: Dictionary, c: Vector2i) -> bool:
	var cost: int = repair_cost(s, c)
	if cost < 0 or cost > int(s["gold"]):
		return false
	s["gold"] = int(s["gold"]) - cost
	building_at(s, c)["dmg"] = false
	return true


## Sum of a stat over the standing buildings. Beds stay usable in a raided building.
static func total(s: Dictionary, key: String) -> float:
	if not claimed(s):
		return 0.0
	var t: float = 0.0
	for b: Dictionary in data(s)["buildings"]:
		if bool(b["dmg"]) and key != "beds":
			continue
		t += LagoonData.stat(b["t"], int(b["lv"]), key)
	return t


## Highest level of a stat over the standing buildings (the shipyard's level, the classes it can lay down).
static func best(s: Dictionary, key: String) -> float:
	var m: float = 0.0
	if not claimed(s):
		return m
	for b: Dictionary in data(s)["buildings"]:
		if not bool(b["dmg"]):
			m = maxf(m, LagoonData.stat(b["t"], int(b["lv"]), key))
	return m


static func count_of(s: Dictionary, type: String) -> int:
	var n: int = 0
	for b: Dictionary in data(s)["buildings"]:
		if b["t"] == type:
			n += 1
	return n


static func beds(s: Dictionary) -> int:
	return int(total(s, "beds"))


static func income_daily(s: Dictionary) -> float:
	return total(s, "income") + float(data(s)["pop"]) * LagoonData.TRIBUTE_PER_RESIDENT if claimed(s) else 0.0


static func chest_cap(s: Dictionary) -> float:
	return LagoonData.CHEST_BASE + total(s, "storage")


static func morale_bonus(s: Dictionary) -> float:
	return total(s, "morale")


## Towers, batteries and the broadsides of the ships at the piers.
static func defence(s: Dictionary) -> float:
	var d: float = total(s, "defence")
	for i in moored(s):
		d += float(_stats_of(s["fleet"][i]).guns_per_side) * LagoonData.GUN_DEFENCE
	return d


static func raid_strength(s: Dictionary) -> float:
	return LagoonData.RAID_STRENGTH_PER_RANK * float(rank_of(s) + 1)


# ---- ranks -----------------------------------------------------------------------------------

static func next_rank_cost(s: Dictionary) -> int:
	var r: int = rank_of(s) + 1
	if r >= LagoonData.RANKS.size():
		return -1
	return int(LagoonData.RANKS[r]["cost"])


static func rank_up(s: Dictionary) -> bool:
	var cost: int = next_rank_cost(s)
	if cost < 0 or cost > int(s["gold"]):
		return false
	s["gold"] = int(s["gold"]) - cost
	data(s)["rank"] = rank_of(s) + 1
	return true


# ---- piers and the fleet ---------------------------------------------------------------------

static func pier_slots(s: Dictionary) -> int:
	return int(LagoonData.rank(rank_of(s))["piers"])


static func build_pier(s: Dictionary) -> bool:
	var piers: Array = data(s)["piers"]
	if piers.size() >= pier_slots(s) or int(s["gold"]) < LagoonData.pier_cost(1):
		return false
	s["gold"] = int(s["gold"]) - LagoonData.pier_cost(1)
	piers.append(1)
	return true


static func pier_upgrade_cost(s: Dictionary, i: int) -> int:
	var piers: Array = data(s)["piers"]
	if i < 0 or i >= piers.size() or int(piers[i]) >= LagoonData.pier_levels():
		return -1
	return LagoonData.pier_cost(int(piers[i]) + 1)


static func upgrade_pier(s: Dictionary, i: int) -> bool:
	var cost: int = pier_upgrade_cost(s, i)
	if cost < 0 or cost > int(s["gold"]):
		return false
	s["gold"] = int(s["gold"]) - cost
	data(s)["piers"][i] = int(data(s)["piers"][i]) + 1
	return true


static func berths(s: Dictionary) -> int:
	if not claimed(s):
		return 0
	var n: int = 0
	for lv in data(s)["piers"]:
		n += int(LagoonData.PIER["berths"][int(lv) - 1])
	return n


## Fleet indexes lying at a pier: the first ships of the fleet, as many as there are berths.
static func moored(s: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i in mini(berths(s), (s["fleet"] as Array).size()):
		out.append(i)
	return out


static func class_of(entry: Dictionary) -> String:
	return str(entry.get("class", entry.get("class_id", "sloop")))


static func _stats_of(entry: Dictionary) -> ShipStats:
	var id: String = class_of(entry)
	if not ResourceLoader.exists("res://data/ships/%s.tres" % id):
		id = "sloop"
	return PortService.ship_stats(id)


## Classes the lagoon's shipyard can lay down, cheapest first.
static func commission_classes(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var top: int = int(best(s, "ships"))
	if top <= 0:
		return out
	for i in PortData.CLASS_ORDER.size():
		if i <= top:
			out.append(PortData.CLASS_ORDER[i])
	return out


## Why a new ship cannot be laid down ("" when it can): "yard", "berth", "fame", "gold".
static func commission_problem(s: Dictionary, class_id: String) -> String:
	if not commission_classes(s).has(class_id):
		return "yard"
	if (s["fleet"] as Array).size() >= berths(s):
		return "berth"
	var st: ShipStats = PortService.ship_stats(class_id)
	if st.infamy_required > int(s["fame"]):
		return "fame"
	if st.price > int(s["gold"]):
		return "gold"
	return ""


static func commission(s: Dictionary, class_id: String, ship_name: String) -> bool:
	if commission_problem(s, class_id) != "":
		return false
	s["gold"] = int(s["gold"]) - PortService.ship_stats(class_id).price
	s["fleet"].append({"class": class_id, "name": ship_name, "crew": 0, "hull": 1.0})
	return true


## Swap the flagship for a ship of the fleet. The crew and cargo come across; the old flagship takes the berth.
static func take_command(s: Dictionary, index: int) -> bool:
	var fleet: Array = s["fleet"]
	if index < 0 or index >= fleet.size():
		return false
	var entry: Dictionary = fleet[index]
	var new_class: String = class_of(entry)
	if not ResourceLoader.exists("res://data/ships/%s.tres" % new_class):
		return false
	fleet[index] = {"class": s["ship_class"], "name": str(s["ship_name"]), "crew": 0, "hull": float(s["ship_hull"])}
	s["ship_class"] = new_class
	s["ship_name"] = str(entry.get("name", "Prize"))
	s["ship_hull"] = clampf(float(entry.get("hull", 1.0)), 0.05, 1.0)
	s["upgrades"] = {}
	s["crew"] = mini(int(s["crew"]) + int(entry.get("crew", 0)), PortService.ship_stats(new_class).crew_max)
	return true


static func sell_price(s: Dictionary, index: int) -> int:
	var entry: Dictionary = s["fleet"][index]
	return int(float(_stats_of(entry).price) * LagoonData.SELL_SHARE * clampf(float(entry.get("hull", 1.0)), 0.2, 1.0))


static func sell_ship(s: Dictionary, index: int) -> int:
	if index < 0 or index >= (s["fleet"] as Array).size():
		return 0
	var g: int = sell_price(s, index)
	s["fleet"].remove_at(index)
	s["gold"] = int(s["gold"]) + g
	return g


# ---- the days -------------------------------------------------------------------------------

## One day at the lagoon while the captain is away: pirates move in, the chest and larder fill, moored ships mend
## and, from the second rank, a navy raid may come. Returns {income, moved_in, raid: "" | "repelled" | "lost",
## lost_gold, damaged}.
static func daily(s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"income": 0.0, "moved_in": 0, "raid": "", "lost_gold": 0, "damaged": ""}
	if not claimed(s):
		return out
	var l: Dictionary = data(s)
	var room: int = beds(s) - int(l["pop"])
	var grow: int = clampi(room, -999, 1 + count_of(s, "tavern"))
	l["pop"] = maxi(int(l["pop"]) + grow, 0)
	out["moved_in"] = maxi(grow, 0)
	var inc: float = income_daily(s)
	l["chest"] = minf(float(l["chest"]) + inc, chest_cap(s))
	out["income"] = inc
	l["larder"] = minf(float(l["larder"]) + total(s, "food"), LARDER_CAP)
	var yard: float = best(s, "repair")
	for i in moored(s):
		var e: Dictionary = s["fleet"][i]
		e["hull"] = minf(float(e.get("hull", 1.0)) + LagoonData.HULL_REPAIR_PER_DAY * yard, 1.0)
	if rank_of(s) >= 1 and rng.randf() < LagoonData.RAID_CHANCE:
		l["raids"] = int(l["raids"]) + 1
		if defence(s) >= raid_strength(s):
			l["repelled"] = int(l["repelled"]) + 1
			out["raid"] = "repelled"
		else:
			out["raid"] = "lost"
			var lost: int = int(float(l["chest"]) * LagoonData.RAID_CHEST_LOSS)
			l["chest"] = float(l["chest"]) - lost
			out["lost_gold"] = lost
			var standing: Array = (l["buildings"] as Array).filter(func(b: Dictionary) -> bool: return not bool(b["dmg"]))
			if not standing.is_empty():
				var hit: Dictionary = standing[rng.randi() % standing.size()]
				hit["dmg"] = true
				out["damaged"] = hit["t"]
	return out


## The captain comes ashore: the chest is emptied into the purse, the larder into the hold, and once a day the
## crew gets the tavern and the fires (morale), the wounded are tended and the shipyard mends the flagship.
## Returns {gold, food, morale, healed, hull}.
static func land(s: Dictionary, day: int) -> Dictionary:
	var out: Dictionary = {"gold": 0, "food": 0.0, "morale": 0.0, "healed": 0, "hull": 0.0}
	if not claimed(s):
		return out
	var l: Dictionary = data(s)
	var g: int = int(float(l["chest"]))
	s["gold"] = int(s["gold"]) + g
	l["chest"] = float(l["chest"]) - g
	out["gold"] = g
	var w: float = float(PortData.SUPPLIES["food"]["weight"])
	var food: float = minf(floorf(float(l["larder"])), floorf(maxf(PortService.cargo_free(s), 0.0) / w))
	if food > 0.0:
		s["supplies"]["food"] = float(s["supplies"]["food"]) + food
		l["larder"] = float(l["larder"]) - food
		out["food"] = food
	if int(l["rest_day"]) == day:
		return out
	l["rest_day"] = day
	var before: float = float(s["morale"])
	s["morale"] = minf(before + morale_bonus(s), 100.0)
	out["morale"] = float(s["morale"]) - before
	var heal: int = mini(int(s["wounded"]), int(total(s, "heal")))
	if heal > 0:
		s["wounded"] = int(s["wounded"]) - heal
		out["healed"] = heal
	var yard: float = best(s, "repair")
	if yard > 0.0:
		var h: float = float(s["ship_hull"])
		s["ship_hull"] = minf(h + 0.25 * yard, 1.0)
		out["hull"] = float(s["ship_hull"]) - h
	return out
