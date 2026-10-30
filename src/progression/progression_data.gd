class_name ProgressionData
extends RefCounted
## Captain levels, XP rules and the five skill trees. Every number the progression system uses is here.

const MAX_LEVEL: int = 30
const LEVEL_STEP_BASE: int = 120    ## XP from level 1 to 2
const LEVEL_STEP_GROWTH: int = 35   ## each later level asks this much more
const MAX_RANK: int = 3
const POINTS_PER_LEVEL: int = 1
const HP_PER_LEVEL: int = 10

const XP: Dictionary = {
	"sink_per_tier": 20, "capture_per_tier": 35, "duel": 50, "island": 25, "trade_gold_per_xp": 100,
}
## XP for finishing each treasure tour, 500 for the first up to 2,000 for the last.
const TOUR_XP: Dictionary = {
	"drowned_purse": 500, "song_of_sirens": 700, "ghost_ledger": 900, "iron_heart": 1200, "frostmourn_vault": 1600, "krakens_maw": 2000,
}
const TOUR_XP_DEFAULT: int = 500
## How big a ship is for XP purposes.
const CLASS_TIER: Dictionary = {
	"cutter": 1, "lugger": 1, "sloop": 2, "schooner": 2, "brigantine": 3, "frigate": 4, "galleon": 4,
	"man_o_war": 5, "revenant": 5, "sovereign": 6, "pinnace": 2, "xebec": 3, "corvette": 3, "east_indiaman": 4,
	"treasure_galleon": 6, "dreadnought": 6, "leviathan": 7,
}

const TREES: Array[String] = ["gunnery", "seamanship", "swordplay", "leadership", "trade"]

## tree -> skills in order. Each skill names the stat it changes and that stat's value at ranks 1, 2 and 3;
## rank 0 gives `neutral`. "mult" stats multiply the base, "add" stats add to it.
const SKILLS: Dictionary = {
	"gunnery": [
		{"id": "reload", "stat": "reload_mult", "neutral": 1.0, "ranks": [0.92, 0.84, 0.75]},
		{"id": "spread", "stat": "spread_mult", "neutral": 1.0, "ranks": [0.9, 0.8, 0.7]},
		{"id": "arc", "stat": "arc_preview_mult", "neutral": 1.0, "ranks": [1.25, 1.5, 2.0]},
		{"id": "double_shot", "stat": "double_shot_chance", "neutral": 0.0, "ranks": [0.05, 0.10, 0.15]},
		{"id": "mast_crit", "stat": "mast_crit_chance", "neutral": 0.0, "ranks": [0.10, 0.20, 0.30]},
	],
	"seamanship": [
		{"id": "speed", "stat": "speed_mult", "neutral": 1.0, "ranks": [1.03, 1.06, 1.10]},
		{"id": "turn", "stat": "turn_mult", "neutral": 1.0, "ranks": [1.05, 1.10, 1.18]},
		{"id": "storm", "stat": "storm_damage_mult", "neutral": 1.0, "ranks": [0.85, 0.70, 0.50]},
		{"id": "kedge", "stat": "kedge_speed_mult", "neutral": 1.0, "ranks": [1.2, 1.4, 1.7]},
		{"id": "currents", "stat": "current_read_m", "neutral": 0.0, "ranks": [500.0, 1000.0, 2000.0]},
	],
	"swordplay": [
		{"id": "damage", "stat": "melee_damage_mult", "neutral": 1.0, "ranks": [1.08, 1.16, 1.25]},
		{"id": "parry", "stat": "parry_window_mult", "neutral": 1.0, "ranks": [1.15, 1.30, 1.50]},
		{"id": "stamina", "stat": "stamina_add", "neutral": 0.0, "ranks": [10.0, 20.0, 35.0]},
		{"id": "pistol", "stat": "pistol_reload_mult", "neutral": 1.0, "ranks": [0.9, 0.8, 0.65]},
		{"id": "finisher", "stat": "finisher_hp_frac", "neutral": 0.0, "ranks": [0.10, 0.15, 0.20]},
	],
	"leadership": [
		{"id": "morale", "stat": "morale_gain_mult", "neutral": 1.0, "ranks": [1.10, 1.20, 1.35]},
		{"id": "hiring", "stat": "hire_cost_mult", "neutral": 1.0, "ranks": [0.95, 0.90, 0.80]},
		{"id": "fleet", "stat": "fleet_size_add", "neutral": 0.0, "ranks": [1.0, 2.0, 3.0]},
		{"id": "boarding", "stat": "boarding_strength_mult", "neutral": 1.0, "ranks": [1.05, 1.10, 1.20]},
		{"id": "bribes", "stat": "bribe_cost_mult", "neutral": 1.0, "ranks": [0.9, 0.8, 0.65]},
	],
	"trade": [
		{"id": "prices", "stat": "sell_price_mult", "neutral": 1.0, "ranks": [1.02, 1.04, 1.07]},
		{"id": "cargo", "stat": "cargo_mult", "neutral": 1.0, "ranks": [1.05, 1.10, 1.15]},
		{"id": "evasion", "stat": "inspection_evasion_add", "neutral": 0.0, "ranks": [0.10, 0.20, 0.30]},
		{"id": "insurance", "stat": "insurance_cost_mult", "neutral": 1.0, "ranks": [0.9, 0.8, 0.6]},
		{"id": "haggling", "stat": "haggle_add", "neutral": 0.0, "ranks": [0.10, 0.20, 0.30]},
	],
}


## Total XP needed to reach `level` (level 1 needs none).
static func xp_to_reach(level: int) -> int:
	var total: int = 0
	for l in range(1, clampi(level, 1, MAX_LEVEL)):
		total += LEVEL_STEP_BASE + LEVEL_STEP_GROWTH * (l - 1)
	return total


static func skill_ids() -> Array[String]:
	var out: Array[String] = []
	for tree: String in TREES:
		for s: Dictionary in SKILLS[tree]:
			out.append("%s.%s" % [tree, s["id"]])
	return out


## The definition of "tree.skill".
static func skill(full_id: String) -> Dictionary:
	var parts: PackedStringArray = full_id.split(".")
	if parts.size() != 2 or not SKILLS.has(parts[0]):
		return {}
	for s: Dictionary in SKILLS[parts[0]]:
		if s["id"] == parts[1]:
			return s
	return {}
