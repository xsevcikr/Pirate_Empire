class_name Upgrades
extends RefCounted
## Ship upgrade lines: 8 lines x 5 tiers, base cost times a class multiplier.

const CLASS_MULT: Dictionary = {"cutter": 0.4, "sloop": 1.0, "schooner": 1.5, "brigantine": 2.5, "frigate": 4.0, "galleon": 5.0, "man_o_war": 8.0, "revenant": 4.0, "sovereign": 10.0}
const REFUND_FRACTION: float = 0.4
const RESPEC_REFUND: float = 0.5
const TIERS: int = 5
const BASE_COST: Dictionary = {
	"hull": [400, 900, 2000, 4500, 10000],
	"armor": [500, 1100, 2500, 5500, 12000],
	"sails": [350, 800, 1800, 4000, 9000],
	"rudder": [300, 700, 1500, 3500, 8000],
	"cannons": [600, 1400, 3200, 7000, 15000],
	"ram": [450, 1000, 2200, 5000, 11000],
	"quarters": [250, 600, 1400, 3200, 7000],
	"specialty": [800, 1800, 4000, 8500, 18000],
}


static func cost(line: String, tier: int, class_id: String) -> int:
	return int(round(BASE_COST[line][tier - 1] * CLASS_MULT[class_id]))


static func total_cost(class_id: String) -> int:
	var t: int = 0
	for line in BASE_COST.keys():
		for tier in range(1, TIERS + 1):
			t += cost(line, tier, class_id)
	return t


## Install the next tier on a line. `owned` maps line -> current tier. Returns remaining gold or -1 if refused.
static func purchase(owned: Dictionary, line: String, class_id: String, gold: int, shipyard_level: int = 1) -> int:
	var next_tier: int = int(owned.get(line, 0)) + 1
	if next_tier > TIERS or (next_tier == 5 and shipyard_level < 3):
		return -1
	var c: int = cost(line, next_tier, class_id)
	if c > gold:
		return -1
	owned[line] = next_tier
	return gold - c


static func refund(line: String, tier: int, class_id: String) -> int:
	return int(cost(line, tier, class_id) * REFUND_FRACTION)
