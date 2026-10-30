class_name CrewTypes
extends RefCounted
## Crew types, wages, effects and levels (spec section 4). Every number a designer may want to tune lives here.

const TYPES: Dictionary = {
	"green": {"hire": 40, "wage": 1, "strength": 1.0},
	"seasoned": {"hire": 120, "wage": 2, "strength": 1.3, "sail_handling": 0.10},
	"gunner": {"hire": 150, "wage": 3, "strength": 1.0, "reload_mult": 0.88, "spread_mult": 0.90},
	"swordsman": {"hire": 120, "wage": 2, "strength": 1.6},
	"musketeer": {"hire": 160, "wage": 3, "strength": 1.0, "volley_kill_fraction": 0.02},
	"carpenter": {"hire": 180, "wage": 3, "strength": 1.0, "repair_hp_per_min": 15.0, "leak_plug_mult": 2.0},
	"surgeon": {"hire": 300, "wage": 5, "strength": 1.0, "wounded_fraction": 0.35, "wounded_fraction_l5": 0.55},
	"cook": {"hire": 120, "wage": 2, "strength": 1.0, "food_use": -0.15, "food_use_l5": -0.25, "morale_per_day": 3.0},
	"navigator": {"hire": 350, "wage": 6, "strength": 1.0, "speed": 0.04, "reveal_radius": 0.5, "forecast_h": 6.0},
	"bosun": {"hire": 220, "wage": 4, "strength": 1.0, "sail_change": 0.20, "fire_spread": -0.30},
	"quartermaster": {"hire": 400, "wage": 6, "strength": 1.0, "morale_decay": -0.25},
}
const SPECIALISTS: PackedStringArray = ["gunner", "swordsman", "musketeer", "carpenter", "surgeon", "cook", "navigator", "bosun", "quartermaster"]
const MAX_LEVEL: int = 5
const XP_THRESHOLDS: Array[int] = [100, 250, 500, 1000]  ## XP needed for levels 2..5
const XP_GAIN: Dictionary = {"battle": 10, "boarding": 25, "storm": 5, "tour": 50}
const OFFERS_PER_TAVERN_LEVEL: int = 1


static func level_for_xp(xp: int) -> int:
	var lvl: int = 1
	for t in XP_THRESHOLDS:
		if xp >= t:
			lvl += 1
	return lvl


## Adds XP to a roster member and re-levels it. Returns true if it gained a level.
static func add_xp(member: Dictionary, kind: String) -> bool:
	var before: int = int(member["level"])
	member["xp"] = int(member["xp"]) + int(XP_GAIN[kind])
	member["level"] = level_for_xp(int(member["xp"]))
	return int(member["level"]) > before


static func wage_total(roster: Array) -> int:
	var t: int = 0
	for m: Dictionary in roster:
		t += int(TYPES[m["type"]]["wage"])
	return t


## Specialists on offer in a tavern: one per tavern level, redrawn every PortData.HIRE_REFRESH_DAYS days.
static func offers(seed_value: int, day: int, tavern_level: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + floori(float(day) / float(PortData.HIRE_REFRESH_DAYS)) * 131
	var pool: Array[String] = []
	pool.assign(SPECIALISTS)
	var out: Array[String] = []
	for i in tavern_level * OFFERS_PER_TAVERN_LEVEL:
		var pick: int = rng.randi() % pool.size()
		out.append(pool[pick])
		pool.remove_at(pick)
	return out
