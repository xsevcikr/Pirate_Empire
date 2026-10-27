class_name Encounters
extends RefCounted
## Random encounter table and density rules.

const TABLE: Dictionary = {
	"merchant_convoy": 22, "navy_patrol": 18, "rival_pirate": 14, "smuggler_meeting": 6, "castaways": 6,
}
const MAX_ACTIVE: int = 12
const ACTIVE_RADIUS_M: float = 6000.0
const DENSITY_LANE_PER_KM2: float = 1.0 / 4.0
const DENSITY_OPEN_PER_KM2: float = 1.0 / 25.0


static func pick(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for w in TABLE.values():
		total += w
	var r: int = rng.randi() % total
	for k in TABLE.keys():
		r -= TABLE[k]
		if r < 0:
			return k
	return "merchant_convoy"


## Ships wanted in a 1 km sector; capped globally by MAX_ACTIVE.
static func sector_target(near_lane: bool) -> float:
	return DENSITY_LANE_PER_KM2 if near_lane else DENSITY_OPEN_PER_KM2


static func can_spawn(active_count: int) -> bool:
	return active_count < MAX_ACTIVE
