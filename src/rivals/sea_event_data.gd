class_name SeaEventData
extends RefCounted
## The random-event table (spec section 18): chance per game hour at sea, and how region, season and weather
## change it. A region or season missing from a multiplier map counts as 1.0. Multipliers are normalised over
## every region and season, so the table's chance stays the long-run average.

const SEASON_DAYS: int = 10
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const REGIONS: Array[String] = ["albion_shallows", "merchants_reach", "haven_waters", "coral_isles", "iron_marches", "dead_reach"]

## chance: per hour. region/season: multipliers. only_region: the event happens nowhere else. needs: "storm",
## "night". weekly: the chance is given per week and divided by 168.
const EVENTS: Dictionary = {
	"wreckage": {"chance": 0.08, "region": {"merchants_reach": 1.4, "iron_marches": 1.2, "coral_isles": 0.7}, "season": {"autumn": 1.3, "winter": 1.2, "summer": 0.5}, "gold": [50, 400], "fragment": 0.03},
	"merchant_convoy": {"chance": 0.06, "region": {"merchants_reach": 2.0, "albion_shallows": 1.3, "dead_reach": 0.2, "haven_waters": 0.7}, "season": {"summer": 1.3, "winter": 0.7}, "ships": [2, 5], "escorts": [0, 2]},
	"bottle": {"chance": 0.04, "region": {"coral_isles": 1.5, "haven_waters": 1.2}, "season": {"spring": 1.2, "autumn": 1.1, "summer": 0.8}},
	"navy_patrol": {"chance": 0.03, "min": 0.03, "max": 0.12, "region": {"albion_shallows": 1.8, "merchants_reach": 1.2, "dead_reach": 0.3, "haven_waters": 0.5}},
	"castaway": {"chance": 0.03, "region": {"coral_isles": 1.6, "dead_reach": 0.5}, "season": {"autumn": 1.2, "winter": 1.2}, "spy": 0.15},
	"whale_pod": {"chance": 0.02, "region": {"coral_isles": 1.5, "albion_shallows": 1.3, "iron_marches": 0.7}, "season": {"spring": 1.6, "winter": 0.4}, "gold": 300, "rep": {"reef_folk": -5.0}},
	"noble": {"chance": 0.01, "region": {"albion_shallows": 1.6, "merchants_reach": 1.4, "dead_reach": 0.3}, "ransom": [3000, 5000], "rep_return": 15.0},
	"waterspout": {"chance": 0.01, "needs": "storm", "region": {"coral_isles": 1.5, "dead_reach": 1.5}, "season": {"summer": 1.5, "autumn": 1.3, "winter": 0.5}, "sail_damage": 0.35},
	"ghost_ship": {"chance": 0.02, "needs": "night", "only_region": "dead_reach", "season": {"autumn": 1.3, "winter": 1.3, "summer": 0.7}},
	"monster": {"chance": 0.01, "region": {"dead_reach": 2.0, "coral_isles": 1.3, "merchants_reach": 0.5}, "kinds": ["serpent", "shark", "siren"]},
	"plague": {"weekly": 0.01, "season": {"summer": 1.4, "winter": 0.6}, "days": 5, "crew_loss": 0.05, "morale": -3.0},
	"stowaway": {"chance": 0.01, "region": {"merchants_reach": 1.5, "albion_shallows": 1.3}, "thief_share": 0.4, "steal": 0.1},
	# becalmed is off (chance 0): sailing ignores the wind, so nothing can becalm the ship
	"becalmed": {"chance": 0.0, "only_region": "coral_isles", "season": {"summer": 1.5, "winter": 0.5}, "hours": [2, 6], "morale_per_hour": 1.0},
}

## The bottle's contents, by weight.
const BOTTLE: Dictionary = {"rumor": 40, "cove": 25, "taunt": 15, "clue": 20}
const BOTTLE_GOLD_CLUE: int = 120


static func season(day: int) -> String:
	return SEASONS[(maxi(day, 0) / SEASON_DAYS) % SEASONS.size()]


static func mult(map: Dictionary, key: String) -> float:
	return float(map.get(key, 1.0))


## Average of region x season multipliers, so a table chance is the long-run mean over the whole world.
static func norm(id: String) -> float:
	var e: Dictionary = EVENTS[id]
	if e.has("only_region"):
		var s: float = 0.0
		for se in SEASONS:
			s += mult(e.get("season", {}), se)
		return s / float(SEASONS.size())
	var total: float = 0.0
	for r in REGIONS:
		for se in SEASONS:
			total += mult(e.get("region", {}), r) * mult(e.get("season", {}), se)
	return total / float(REGIONS.size() * SEASONS.size())
