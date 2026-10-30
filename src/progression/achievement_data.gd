class_name AchievementData
extends RefCounted
## The 32 starting achievements. Each one unlocks when a counter reaches its goal; counters are the lifetime stats in
## state["stats"] plus a few read straight from the state (see Achievements.value).

const LIST: Array[Dictionary] = [
	{"id": "from_driftwood", "stat": "ships_bought", "goal": 1},
	{"id": "broadside", "stat": "best_broadside_hits", "goal": 10},
	{"id": "timber", "stat": "best_masts_window", "goal": 3},
	{"id": "hard_aground", "stat": "kedged_free", "goal": 1},
	{"id": "one_against_many", "stat": "outnumbered_boardings_won", "goal": 1},
	{"id": "parry_master", "stat": "best_parries", "goal": 10},
	{"id": "market_maker", "stat": "convoy_goods_sold", "goal": 1},
	{"id": "smooth_smuggler", "stat": "contraband_inspections_passed", "goal": 10},
	{"id": "crab_cakes", "stat": "boss_shell_king", "goal": 1},
	{"id": "wax_in_ears", "stat": "sirens_crossed_clean", "goal": 1},
	{"id": "calamari", "stat": "boss_kraken", "goal": 1},
	{"id": "mollys_redemption", "stat": "recruited_molly", "goal": 1},
	{"id": "empire_builder", "stat": "bases_owned", "goal": 6},
	{"id": "pirate_king", "stat": "boss_black_ibrahim", "goal": 1},
	{"id": "never_starved", "stat": "days_without_starving", "goal": 100},
	{"id": "first_blood", "stat": "ships_sunk", "goal": 1},
	{"id": "sea_wolf", "stat": "ships_sunk", "goal": 25},
	{"id": "scourge", "stat": "ships_sunk", "goal": 100},
	{"id": "prize_hunter", "stat": "prizes_taken", "goal": 10},
	{"id": "well_off", "stat": "gold_earned", "goal": 10000},
	{"id": "tycoon", "stat": "gold_earned", "goal": 100000},
	{"id": "explorer", "stat": "islands_found", "goal": 10},
	{"id": "cartographer", "stat": "islands_found", "goal": 24},
	{"id": "voyager", "stat": "distance_km", "goal": 500},
	{"id": "duelist", "stat": "duels_won", "goal": 10},
	{"id": "seasoned_captain", "stat": "captain_level", "goal": 5},
	{"id": "veteran_captain", "stat": "captain_level", "goal": 15},
	{"id": "legend", "stat": "captain_level", "goal": 30},
	{"id": "master_of_one", "stat": "best_skill_rank", "goal": 3},
	{"id": "treasure_hunter", "stat": "tours_done", "goal": 1},
	{"id": "tour_master", "stat": "tours_done", "goal": 6},
	{"id": "rival_slayer", "stat": "rivals_beaten", "goal": 1},
]

## Counters that keep the highest value seen rather than a running total.
const MAX_STATS: Array[String] = ["best_broadside_hits", "best_masts_window", "best_parries"]
## Seconds within which snapped masts count as one battle.
const MAST_WINDOW_S: float = 120.0
## Guardian tour steps whose defeat counts as a boss kill.
const BOSS_STEPS: Array[String] = ["shell_king", "serpent", "ghost_admiral", "colossus", "leviathan", "kraken"]
const BOSS_STAT_OF_STEP: Dictionary = {"shell_king": "boss_shell_king", "kraken": "boss_kraken"}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for a in LIST:
		out.append(str(a["id"]))
	return out
