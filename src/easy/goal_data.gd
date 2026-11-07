class_name GoalData
extends RefCounted
## The friendly goals list for young captains: short, clear jobs that each pay stars and a little gold. Goals are
## done in any order, but the HUD card shows the first ACTIVE_SHOWN unfinished ones in this order, so the list
## walks a new player from "sail a bit" to "beat a sea monster". Each goal reads one counter (Goals.value).

const ACTIVE_SHOWN: int = 3
const GOLD_PER_STAR: int = 50

## id, the counter it reads, the target, and the stars it pays. Text keys are "goal.<id>" and "goal.<id>.hint".
const LIST: Array[Dictionary] = [
	{"id": "first_sail", "stat": "distance_km", "goal": 1, "stars": 1},
	{"id": "find_islands", "stat": "islands_found", "goal": 2, "stars": 1},
	{"id": "parrot_find", "stat": "parrot_finds", "goal": 1, "stars": 1},
	{"id": "shells_3", "stat": "shells", "goal": 3, "stars": 1},
	{"id": "trade_100", "stat": "gold_earned", "goal": 100, "stars": 1},
	{"id": "visit_ports", "stat": "ports_visited", "goal": 3, "stars": 2},
	{"id": "sink_ship", "stat": "ships_sunk", "goal": 1, "stars": 2},
	{"id": "treasure_maps", "stat": "maps_found", "goal": 3, "stars": 2},
	{"id": "win_boarding", "stat": "duels_won", "goal": 1, "stars": 2},
	{"id": "flags_3", "stat": "flags", "goal": 3, "stars": 2},
	{"id": "ship_cards_3", "stat": "ship_cards", "goal": 3, "stars": 2},
	{"id": "parrot_5", "stat": "parrot_finds", "goal": 5, "stars": 2},
	{"id": "level_3", "stat": "captain_level", "goal": 3, "stars": 2},
	{"id": "take_prize", "stat": "prizes_taken", "goal": 1, "stars": 2},
	{"id": "islands_10", "stat": "islands_found", "goal": 10, "stars": 3},
	{"id": "every_shell", "stat": "shell_kinds", "goal": 6, "stars": 3},
	{"id": "rare_ship", "stat": "rare_cards", "goal": 1, "stars": 3},
	{"id": "sail_50", "stat": "distance_km", "goal": 50, "stars": 3},
	{"id": "sea_monster", "stat": "bosses_beaten", "goal": 1, "stars": 3},
	{"id": "all_flags", "stat": "flag_kinds", "goal": 8, "stars": 3},
]

## The parrot's feathers: the best colour whose star count the captain has reached.
const PARROT_COLOURS: Array[Dictionary] = [
	{"id": "green", "stars": 0, "body": Color(0.3, 0.75, 0.3), "wing": Color(0.15, 0.5, 0.85), "head": Color(0.95, 0.85, 0.2)},
	{"id": "blue", "stars": 6, "body": Color(0.2, 0.5, 0.95), "wing": Color(0.98, 0.8, 0.2), "head": Color(0.3, 0.75, 1.0)},
	{"id": "scarlet", "stars": 15, "body": Color(0.92, 0.2, 0.18), "wing": Color(0.2, 0.45, 0.95), "head": Color(1.0, 0.85, 0.2)},
	{"id": "golden", "stars": 30, "body": Color(1.0, 0.78, 0.2), "wing": Color(1.0, 0.95, 0.6), "head": Color(1.0, 0.6, 0.15)},
]


static func by_id(id: String) -> Dictionary:
	for g in LIST:
		if g["id"] == id:
			return g
	return {}


static func total_stars() -> int:
	var n: int = 0
	for g in LIST:
		n += int(g["stars"])
	return n
