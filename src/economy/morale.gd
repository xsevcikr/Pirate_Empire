class_name Morale
extends RefCounted
## Crew morale (0 to 100): the daily formula, the five bands and what each band does (spec section 4).

## Band name -> [min, max, work efficiency, boarding strength bonus, desertion per day in port]
const BANDS: Dictionary = {
	"loyal": {"min": 80.0, "efficiency": 1.10, "boarding": 0.10, "desert": 0.0},
	"content": {"min": 50.0, "efficiency": 1.0, "boarding": 0.0, "desert": 0.0},
	"grumbling": {"min": 30.0, "efficiency": 0.90, "boarding": 0.0, "desert": 0.0},
	"mutinous": {"min": 15.0, "efficiency": 0.75, "boarding": 0.0, "desert": 0.05},
	"mutiny": {"min": 0.0, "efficiency": 0.75, "boarding": 0.0, "desert": 0.05},
}
const BAND_ORDER: PackedStringArray = ["loyal", "content", "grumbling", "mutinous", "mutiny"]

## Morale change per cause (spec section 4).
const DELTA: Dictionary = {
	"rum_ration": 3.0, "cook_bonus": 3.0, "victory": 10.0, "loot_per_50_gold": 1.0, "shore_leave": 5.0,
	"no_food": -15.0, "no_water": -25.0, "wages_unpaid": -10.0, "no_rum": -3.0,
	"killed_per_5_percent": -1.0, "storm_day": -2.0, "defeat": -15.0,
	"cut_high": -5.0, "cut_low": 5.0,
}
const DECAY_PER_DAY: float = 2.0
const DECAY_TARGET: float = 50.0
const CUT_MIN: float = 0.10
const CUT_MAX: float = 0.50
const CUT_DEFAULT: float = 0.25
const CUT_HIGH_ABOVE: float = 0.35
const CUT_LOW_BELOW: float = 0.15


static func band(morale: float) -> String:
	for b: String in BAND_ORDER:
		if morale >= BANDS[b]["min"]:
			return b
	return "mutiny"


static func efficiency(morale: float) -> float:
	return BANDS[band(morale)]["efficiency"]


static func boarding_bonus(morale: float) -> float:
	return BANDS[band(morale)]["boarding"]


static func desertion_per_day(morale: float) -> float:
	return BANDS[band(morale)]["desert"]


## Morale after one day's causes. `c` keys (all optional): rum_ration, cook_bonus, shore_leave, no_food, no_water,
## wages_unpaid, no_rum (bool); victories (int), loot_gold (float, the crew's paid share), killed_fraction (0..1),
## storm_day (bool), defeat (bool). Clamped to 0..100, then pulled toward 50 by the daily decay.
static func daily(morale: float, c: Dictionary, quartermaster: bool = false) -> float:
	var m: float = morale
	if c.get("rum_ration", false):
		m += DELTA["rum_ration"]
	if c.get("cook_bonus", false):
		m += DELTA["cook_bonus"]
	m += DELTA["victory"] * float(c.get("victories", 0))
	m += DELTA["loot_per_50_gold"] * floorf(float(c.get("loot_gold", 0.0)) / 50.0)
	if c.get("shore_leave", false):
		m += DELTA["shore_leave"]
	if c.get("no_food", false):
		m += DELTA["no_food"]
	if c.get("no_water", false):
		m += DELTA["no_water"]
	if c.get("wages_unpaid", false):
		m += DELTA["wages_unpaid"]
	if c.get("no_rum", false):
		m += DELTA["no_rum"]
	m += DELTA["killed_per_5_percent"] * floorf(float(c.get("killed_fraction", 0.0)) * 100.0 / 5.0)
	if c.get("storm_day", false):
		m += DELTA["storm_day"]
	if c.get("defeat", false):
		m += DELTA["defeat"]
	return decay(clampf(m, 0.0, 100.0), quartermaster)


static func decay(morale: float, quartermaster: bool = false) -> float:
	var step: float = DECAY_PER_DAY * (1.0 + CrewTypes.TYPES["quartermaster"]["morale_decay"] if quartermaster else 1.0)
	var gap: float = DECAY_TARGET - morale
	return morale + signf(gap) * minf(absf(gap), step)


## Loot split: the captain's cut and the crew's paid shares. With no crew the captain keeps everything.
static func loot_split(total: float, cut: float, crew: int) -> Dictionary:
	var c: float = clampf(cut, CUT_MIN, CUT_MAX)
	if crew <= 0:
		return {"captain": total, "crew": 0.0, "morale": 0.0}
	var morale: float = 0.0
	if c > CUT_HIGH_ABOVE:
		morale += DELTA["cut_high"]
	elif c < CUT_LOW_BELOW:
		morale += DELTA["cut_low"]
	var crew_share: float = total * (1.0 - c)
	morale += DELTA["loot_per_50_gold"] * floorf(crew_share / 50.0)
	return {"captain": total * c, "crew": crew_share, "morale": morale}
