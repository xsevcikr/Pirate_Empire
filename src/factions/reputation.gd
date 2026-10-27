class_name Reputation
extends RefCounted
## Faction reputation (-100..100) and bounty (0..500), with tiers, decay and hunter spawns.

const FACTIONS: Array[String] = ["navy", "merchant", "pirate", "reef_folk", "iron_dominion"]
const START_REP: Dictionary = {"navy": -30.0, "merchant": 0.0, "pirate": 20.0, "reef_folk": -10.0, "iron_dominion": -20.0}
const ALLIES: Dictionary = {"navy": ["merchant"], "merchant": ["navy"], "pirate": [], "reef_folk": [], "iron_dominion": []}
const RIVALS: Dictionary = {"navy": ["pirate", "iron_dominion"], "merchant": ["pirate"], "pirate": ["navy", "merchant"], "reef_folk": ["iron_dominion"], "iron_dominion": ["navy", "reef_folk"]}

const REP_DELTA: Dictionary = {
	"sink_ship": -4.0, "sink_ship_ally": -1.0, "capture_ship": -6.0, "plunder_city": -15.0,
	"release_ship": 3.0, "contract_min": 5.0, "contract_max": 10.0, "trade_per_1000g": 0.2, "destroy_rival": 2.0,
}
const BOUNTY_DELTA: Dictionary = {"attack_ship": 10.0, "sink_ship": 15.0, "capture_ship": 20.0, "plunder_city": 60.0, "kill_official": 40.0}
const REP_DECAY_PER_WEEK: float = 1.0
const BOUNTY_DECAY_PER_DAY: float = 2.0
const PARDON_GOLD_PER_POINT: float = 50.0
const MARQUE_COST: int = 10000
const MARQUE_DAYS: int = 20

## stars: [min_bounty, stars, ships, hours_between_spawns]
const HUNTER_TABLE: Array = [
	[450.0, 4, 6, 3.0], [300.0, 3, 3, 4.0], [150.0, 2, 2, 6.0], [50.0, 1, 1, 8.0], [0.0, 0, 0, 0.0],
]

var rep: Dictionary = {}
var bounty: Dictionary = {}
var marque_faction: String = ""
var marque_days_left: float = 0.0


func _init() -> void:
	for f in FACTIONS:
		rep[f] = START_REP[f]
		bounty[f] = 0.0


func add_rep(faction: String, delta: float) -> void:
	rep[faction] = clampf(rep[faction] + delta, -100.0, 100.0)


func add_bounty(faction: String, delta: float) -> void:
	bounty[faction] = clampf(bounty[faction] + delta, 0.0, 500.0)


## Sinking a faction's ship: -4 with them, -1 with its allies, +2 with its rivals; bounty +15 unless a letter of marque covers it.
func sink_ship(faction: String) -> void:
	add_rep(faction, REP_DELTA["sink_ship"])
	for a in ALLIES[faction]:
		add_rep(a, REP_DELTA["sink_ship_ally"])
	for r in RIVALS[faction]:
		add_rep(r, REP_DELTA["destroy_rival"])
	if marque_faction == faction and marque_days_left > 0.0:
		add_rep("navy", 1.0)
	else:
		add_bounty(faction, BOUNTY_DELTA["sink_ship"])


func capture_ship(faction: String) -> void:
	add_rep(faction, REP_DELTA["capture_ship"])
	add_bounty(faction, BOUNTY_DELTA["capture_ship"])


func plunder_city(faction: String) -> void:
	add_rep(faction, REP_DELTA["plunder_city"])
	add_bounty(faction, BOUNTY_DELTA["plunder_city"])
	for a in ALLIES[faction]:
		add_rep(a, -2.0)


func release_ship(faction: String) -> void:
	add_rep(faction, REP_DELTA["release_ship"])


func trade(faction: String, gold_traded: float) -> void:
	add_rep(faction, REP_DELTA["trade_per_1000g"] * gold_traded / 1000.0)


static func tier(value: float) -> String:
	if value <= -61.0:
		return "hated"
	if value <= -21.0:
		return "hostile"
	if value <= 20.0:
		return "neutral"
	if value <= 60.0:
		return "friendly"
	return "allied"


## Price multiplier at a faction's ports by tier.
static func price_mult(value: float) -> float:
	match tier(value):
		"hostile":
			return 1.5
		"friendly":
			return 0.95
		"allied":
			return 0.9
	return 1.0


static func port_access(value: float) -> bool:
	return tier(value) != "hated"


static func hunter_response(bounty_value: float) -> Dictionary:
	for row in HUNTER_TABLE:
		if bounty_value >= row[0]:
			return {"stars": row[1], "ships": row[2], "interval_h": row[3], "ports_closed": bounty_value >= 450.0}
	return {"stars": 0, "ships": 0, "interval_h": 0.0, "ports_closed": false}


func advance_days(days: float, seen_by_patrols: bool = false) -> void:
	for f in FACTIONS:
		var toward_zero: float = REP_DECAY_PER_WEEK / 7.0 * days
		if rep[f] > 0.0:
			rep[f] = maxf(rep[f] - toward_zero, 0.0)
		elif rep[f] < 0.0:
			rep[f] = minf(rep[f] + toward_zero, 0.0)
		if not seen_by_patrols:
			bounty[f] = maxf(bounty[f] - BOUNTY_DECAY_PER_DAY * days, 0.0)
	if marque_days_left > 0.0:
		marque_days_left = maxf(marque_days_left - days, 0.0)


## Returns gold left, or -1 if the governor's faction is hostile or funds are short.
func pardon(faction: String, points: float, gold: float) -> float:
	var cost: float = points * PARDON_GOLD_PER_POINT
	if cost > gold or tier(rep[faction]) in ["hated", "hostile"]:
		return -1.0
	bounty[faction] = maxf(bounty[faction] - points, 0.0)
	return gold - cost


func buy_marque(enemy_faction: String, gold: int) -> int:
	if gold < MARQUE_COST or tier(rep["navy"]) in ["hated"] or enemy_faction == "navy":
		return -1
	marque_faction = enemy_faction
	marque_days_left = float(MARQUE_DAYS)
	return gold - MARQUE_COST


## Attacking anyone but the named enemy cancels the letter.
func attack(faction: String) -> void:
	if marque_faction != "" and faction != marque_faction:
		marque_faction = ""
		marque_days_left = 0.0
	if not (marque_faction == faction and marque_days_left > 0.0):
		add_bounty(faction, BOUNTY_DELTA["attack_ship"])
