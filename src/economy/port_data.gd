class_name PortData
extends RefCounted
## Port definitions, supplies and shipyard rules. Numbers come from the spec (sections 3, 4, 5, 7, 9).

const CLASS_ORDER: PackedStringArray = ["cutter", "sloop", "schooner", "brigantine", "frigate", "galleon", "man_o_war"]
## City tier -> highest class its shipyard sells.
const TIER_MAX_CLASS: Dictionary = {"village": "sloop", "town": "brigantine", "city": "frigate", "capital": "man_o_war"}
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

const PORTS: Dictionary = {
	"blackwater": {
		"name": "Blackwater Town", "island": 0, "dock": Vector2(0.0, 360.0), "tier": "capital", "faction": "pirate",
		"lawful": false, "tavern_level": 2, "shipyard_level": 3, "margin": 0.10, "target_units": 100.0,
		"producer": ["rum"], "consumer": ["sugar", "gunpowder"], "black_market": true,
	},
	"meridian": {
		"name": "Port Meridian", "island": -1, "dock": Vector2(0.0, 5200.0), "tier": "city", "faction": "merchant",
		"lawful": true, "tavern_level": 2, "shipyard_level": 2, "margin": 0.08, "target_units": 100.0,
		"producer": ["sugar", "tobacco", "silk"], "consumer": ["rum", "fish"], "fence": true,
	},
	"albion": {
		"name": "Albion Harbour", "island": -1, "dock": Vector2(-6000.0, 5400.0), "tier": "capital", "faction": "navy",
		"lawful": true, "tavern_level": 3, "shipyard_level": 3, "margin": 0.12, "target_units": 120.0,
		"producer": [], "consumer": ["tobacco", "tea", "silk", "spices", "rum", "fish"], "rum_demand": 2.0, "bank": true,
	},
	"ironhold": {
		"name": "Ironhold", "island": -1, "dock": Vector2(6000.0, 5000.0), "tier": "city", "faction": "iron_dominion",
		"lawful": true, "tavern_level": 2, "shipyard_level": 2, "margin": 0.14, "target_units": 100.0,
		"producer": ["gunpowder", "iron"], "consumer": ["fish", "timber", "tobacco"],
	},
	"coral_landing": {
		"name": "Coral Landing", "island": -1, "dock": Vector2(-6000.0, -6000.0), "tier": "town", "faction": "reef_folk",
		"lawful": true, "tavern_level": 1, "shipyard_level": 1, "margin": 0.10, "target_units": 80.0,
		"producer": ["fish", "spices", "tea"], "consumer": ["iron", "rum"], "fence": true,
	},
}
const START_PORT: String = "blackwater"


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
	var top: int = CLASS_ORDER.find(TIER_MAX_CLASS[PORTS[port_id]["tier"]])
	return CLASS_ORDER.find(class_id) <= top
