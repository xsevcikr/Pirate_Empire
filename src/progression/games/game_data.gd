class_name GameData
extends RefCounted
## Stakes, prizes and tuning for the the mini-games (digging lives with the tours).

const BET_MIN: int = 10
const BET_MAX: int = 500
const BETS: Array[int] = [10, 50, 100, 250, 500]

const LIARS_DICE: Dictionary = {
	"dice": 5, "faces": 6, "map_fragment_chance": 0.12, "shady_bet_min": 250,
	"opponents": {
		"cautious": {"call_at": 0.45, "bluff": 0.05},
		"reckless": {"call_at": 0.25, "bluff": 0.35},
		"cunning": {"call_at": 0.35, "bluff": 0.2},
	},
}
const BONES: Dictionary = {
	"target": 21, "dealer_stands": 17, "blackjack_pay": 1.5, "rumour_chance": 0.25,
	"suits": 4, "ranks": 13,
}
const ARM_WRESTLE: Dictionary = {
	"timing_weight": 0.4, "mash_weight": 0.6, "mash_cap": 30.0, "recruit_morale": 5.0,
	"opponents": {"dockhand": 0.35, "sailor": 0.5, "brute": 0.7},
}
const DRINKING: Dictionary = {
	"sway_base": 0.15, "sway_per_drink": 0.12, "fall_at": 1.0, "rounds_max": 10, "gold_per_round": 15, "rival_rumour_rounds": 6,
}
const FISHING: Dictionary = {
	"bite_min_s": 2.0, "bite_max_s": 8.0, "tension_break": 1.0, "reel_tension": 0.55, "relax_tension": 0.35, "distance_start": 1.0,
	"reel_speed": 0.12, "fish_pull": 0.5, "bottle_chance": 0.08, "food_days_per_fish": 0.1,
	"fish": {
		"sardine": {"value": 50, "pull": 0.3, "weight": 50}, "bass": {"value": 90, "pull": 0.5, "weight": 30},
		"tuna": {"value": 180, "pull": 0.8, "weight": 15}, "marlin": {"value": 400, "pull": 1.2, "weight": 5},
	},
}
const RANGE: Dictionary = {
	"duration_s": 60.0, "spawn_every_s": 1.5, "target_radius": 1.2, "range_min_m": 60.0, "range_max_m": 220.0, "speed": 3.0,
	"xp_per_hit": 2, "crew_xp_per_5_hits": 1,
}
const KNIFE: Dictionary = {
	"throws": 3, "board_spin_rps": 0.5, "rings": [[0.08, 50], [0.2, 25], [0.4, 10], [0.6, 5]], "gold_per_point": 1,
	"outfit_score": 120, "outfit": "coat/duelist",
}
