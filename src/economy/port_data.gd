class_name PortData
extends RefCounted
## Port definitions, supplies and shipyard rules. Numbers come from the spec (sections 3, 4, 5, 7, 9).

const CLASS_ORDER: PackedStringArray = [
	"cutter", "sloop", "pinnace", "schooner", "xebec", "brigantine", "corvette", "frigate", "east_indiaman", "galleon", "man_o_war",
	"treasure_galleon", "dreadnought", "leviathan",
]
## City tier -> highest class its shipyard sells. The giants after the Man-o-War are never sold by tier alone.
const TIER_MAX_CLASS: Dictionary = {"village": "pinnace", "town": "brigantine", "city": "frigate", "capital": "man_o_war"}
## Only a grand shipyard (level 3) can lay down a giant's keel.
const GIANT_YARD_LEVEL: int = 3
## A Cutter handed in against a first Sloop is credited at full list price (the spec's 1,400 figure).
const STARTER_EXCHANGE: Dictionary = {"from": "cutter", "to": "sloop", "credit": 600}
const TRADE_IN_FRACTION: float = 0.5
const REPAIR_GOLD_PER_HP: float = 2.0
const DOCK_RADIUS_M: float = 90.0
const DOCK_MAX_SPEED_KN: float = 3.0
const DOCK_FEE_PER_TONNE: float = 1.0  ## lawful ports only
const PRICE_MULT_BY_DIFFICULTY: Array[float] = [0.9, 1.0, 1.0, 1.0]
const AMMO_MULT_BY_DIFFICULTY: Array[float] = [1.0, 1.0, 1.2, 1.2]
const HIRE_REFRESH_DAYS: int = 2

## Supplies: priced from a market good when "good" is set, otherwise a fixed price. Weight in tonnes per unit.
const SUPPLIES: Dictionary = {
	"food": {"good": "fish", "weight": 0.05},
	"water": {"price": 2.0, "weight": 0.05},
	"rum": {"good": "rum", "weight": 0.05},
	"small_arms": {"price": 10.0, "weight": 0.01},
	"timber": {"good": "timber", "weight": 0.1},
	"medicine": {"price": 40.0, "weight": 0.01},
}
const START_SUPPLIES: Dictionary = {"food": 4.0, "water": 4.0, "rum": 1.0, "small_arms": 0.0, "timber": 0.0, "medicine": 0.0}

## Hand-tuned economies for the five ports the early game leans on; the other cities come from IslandData.
const HAND_PORTS: Dictionary = {
	"blackwater": {
		"name": "Blackwater Town", "island": 0, "dock": Vector2(0.0, 360.0), "tier": "capital", "faction": "pirate",
		"lawful": false, "tavern_level": 2, "shipyard_level": 3, "margin": 0.10, "target_units": 100.0,
		"producer": ["rum"], "consumer": ["sugar", "gunpowder"], "black_market": true,
	},
	"meridian": {
		"name": "Saint Marguerite", "island": -1, "dock": Vector2.ZERO, "tier": "capital", "faction": "merchant",
		"lawful": true, "tavern_level": 2, "shipyard_level": 2, "margin": 0.08, "target_units": 100.0,
		"producer": ["sugar", "tobacco", "silk"], "consumer": ["rum", "fish"], "fence": true, "bank": true,
	},
	"albion": {
		"name": "Port Regal", "island": -1, "dock": Vector2.ZERO, "tier": "capital", "faction": "navy",
		"lawful": true, "tavern_level": 3, "shipyard_level": 3, "margin": 0.12, "target_units": 120.0,
		"producer": [], "consumer": ["tobacco", "tea", "silk", "spices", "rum", "fish"], "rum_demand": 2.0, "bank": true,
	},
	"ironhold": {
		"name": "Ironhold", "island": -1, "dock": Vector2.ZERO, "tier": "capital", "faction": "iron_dominion",
		"lawful": true, "tavern_level": 2, "shipyard_level": 2, "margin": 0.14, "target_units": 100.0,
		"producer": ["gunpowder", "iron"], "consumer": ["fish", "timber", "tobacco"],
	},
	"coral_landing": {
		"name": "Tavai Lagoon", "island": -1, "dock": Vector2.ZERO, "tier": "city", "faction": "reef_folk",
		"lawful": true, "tavern_level": 1, "shipyard_level": 1, "margin": 0.10, "target_units": 80.0,
		"producer": ["fish", "spices", "tea"], "consumer": ["iron", "rum"], "fence": true,
	},
}
const START_PORT: String = "blackwater"
## Every port of the archipelago by id: dock position, faction and economy. Built once from the layout.
static var PORTS: Dictionary = _build_ports()
static var _gen: WorldGen


static func gen() -> WorldGen:
	if _gen == null:
		_gen = WorldGen.new()
	return _gen


static func _build_ports() -> Dictionary:
	var g: WorldGen = gen()
	var out: Dictionary = {}
	for idx in g.city_islands():
		var isl: Dictionary = g.islands[idx]
		var city: String = isl["city"]
		var id: String = IslandData.port_id_of(city)
		var faction: String = str(WorldMap.REGIONS[isl["region"]]["faction"])
		var p: Dictionary
		if HAND_PORTS.has(id):
			p = (HAND_PORTS[id] as Dictionary).duplicate(true)
		else:
			var tier: Dictionary = IslandData.TIER_STATS[isl["tier"]]
			var eco: Dictionary = IslandData.ECONOMY[city]
			p = {"tier": isl["tier"], "faction": faction, "lawful": faction != "pirate", "tavern_level": tier["tavern"], "shipyard_level": tier["yard"],
				"margin": 0.10, "target_units": tier["target"], "producer": eco["producer"], "consumer": eco["consumer"]}
			if faction == "pirate":
				p["black_market"] = true
			elif isl["tier"] in ["town", "city"] and faction != "navy":
				p["fence"] = true
		p["name"] = city
		p["island"] = idx
		p["dock"] = g.harbor_point(idx, g.harbor_angle(idx))
		p["biome"] = isl["biome"]
		out[id] = p
	return out


## The port whose dock is within `radius` of a world point, or "".
static func port_near(p: Vector2, radius: float = DOCK_RADIUS_M) -> String:
	var best: String = ""
	var best_d: float = radius
	for id: String in PORTS:
		var d: float = (PORTS[id]["dock"] as Vector2).distance_to(p)
		if d <= best_d:
			best_d = d
			best = id
	return best


static func build_market(port_id: String) -> Market:
	var p: Dictionary = PORTS[port_id]
	var m := Market.new(p["target_units"])
	m.margin = p["margin"]
	for g: String in p["producer"]:
		m.role[g] = "producer"
	for g: String in p["consumer"]:
		m.role[g] = "consumer"
	var demand: float = float(p.get("rum_demand", 1.0))
	if demand != 1.0:
		m.target["rum"] = float(p["target_units"]) * demand  # navy ports drink twice as much
		m.stock["rum"] = m.target["rum"]
	return m


static func can_sell_class(port_id: String, class_id: String) -> bool:
	var i: int = CLASS_ORDER.find(class_id)
	if i < 0:
		return false
	if is_giant(class_id):
		return int(PORTS[port_id]["shipyard_level"]) >= GIANT_YARD_LEVEL
	return i <= CLASS_ORDER.find(TIER_MAX_CLASS[PORTS[port_id]["tier"]])


static func is_giant(class_id: String) -> bool:
	return CLASS_ORDER.find(class_id) > CLASS_ORDER.find("man_o_war")


## Ports whose yard builds the giants, for the shipyard hint and the chart.
static func giant_yards() -> Array[String]:
	var out: Array[String] = []
	for id: String in PORTS:
		if int(PORTS[id]["shipyard_level"]) >= GIANT_YARD_LEVEL:
			out.append(id)
	out.sort()
	return out
