class_name CrewLife
extends RefCounted
## Life aboard: daily food, water and rum, wages, starvation, wounded, desertion, morale and the mutiny trigger.
## Plain functions on the save-state dictionary so every rule is testable (spec section 4).

const PEOPLE_PER_FOOD_UNIT: float = 4.0
const PEOPLE_PER_WATER_UNIT: float = 4.0
const PEOPLE_PER_RUM_UNIT: float = 10.0
const STARVE_GRACE_DAYS: int = 3
const STARVE_DEATH_FRACTION: float = 0.02
const THIRST_GRACE_DAYS: int = 2
const THIRST_DEATH_FRACTION: float = 0.04
const WOUNDED_DEATH_FRACTION: float = 0.10
const MEDICINE_WOUNDED_PER_UNIT: float = 5.0
const REPAIR_HP_PER_TIMBER: float = 40.0
const MUTINY_BELOW: float = 15.0
const MUTINY_SHIELD_DAYS: int = 7
const DECKHAND_DIFFICULTY: int = 0  ## no starvation deaths


static func people(state: Dictionary) -> int:
	return int(state["crew"]) + 1  # the captain eats too


static func food_per_day(state: Dictionary) -> float:
	var fx: Dictionary = CrewEffects.compute(state["roster"])
	return float(people(state)) / PEOPLE_PER_FOOD_UNIT * float(fx["food_use_mult"])


static func water_per_day(state: Dictionary) -> float:
	return float(people(state)) / PEOPLE_PER_WATER_UNIT


static func rum_per_day(state: Dictionary) -> float:
	return float(people(state)) / PEOPLE_PER_RUM_UNIT


static func days_left(state: Dictionary, supply: String) -> float:
	var per_day: float = {"food": food_per_day(state), "water": water_per_day(state), "rum": rum_per_day(state)}[supply]
	return float(state["supplies"][supply]) / maxf(per_day, 0.0001)


static func wages_per_day(state: Dictionary) -> int:
	return CrewTypes.wage_total(state["roster"])


## Take `n` crew off the roster (the least experienced go first) and keep `crew` in step.
static func remove_crew(state: Dictionary, n: int) -> int:
	var removed: int = 0
	while removed < n and int(state["crew"]) > 0:
		var worst: int = -1
		for i in state["roster"].size():
			if worst < 0 or int(state["roster"][i]["level"]) < int(state["roster"][worst]["level"]):
				worst = i
		if worst >= 0:
			state["roster"].remove_at(worst)
		state["crew"] = int(state["crew"]) - 1
		removed += 1
	return removed


## Men on their feet: the crew minus the wounded on the sick list.
static func fit_crew(state: Dictionary) -> int:
	return maxi(int(state["crew"]) - int(state["wounded"]), 0)


## `lost` men fell in a fight. A surgeon turns part of them into wounded (they stay aboard, out of action);
## the rest are dead and leave the roster. Costs morale: -1 per 5% of the crew killed. Returns {dead, wounded}.
static func casualties(state: Dictionary, lost: int) -> Dictionary:
	if lost <= 0:
		return {"dead": 0, "wounded": 0}
	var crew_before: int = int(state["crew"])
	var fx: Dictionary = CrewEffects.compute(state["roster"])
	var wounded: int = floori(lost * float(fx["wounded_fraction"]))
	var dead: int = lost - wounded
	state["wounded"] = int(state["wounded"]) + wounded
	remove_crew(state, dead)
	var killed_fraction: float = float(dead) / maxf(float(crew_before), 1.0)
	add_morale(state, Morale.DELTA["killed_per_5_percent"] * floorf(killed_fraction * 100.0 / 5.0))
	return {"dead": dead, "wounded": wounded}


static func add_morale(state: Dictionary, amount: float) -> void:
	state["morale"] = clampf(float(state["morale"]) + amount, 0.0, 100.0)


## Crew XP for an event kind ("battle", "boarding", "storm", "tour"). Returns how many levelled up.
static func award_xp(state: Dictionary, kind: String) -> int:
	var ups: int = 0
	for m: Dictionary in state["roster"]:
		if CrewTypes.add_xp(m, kind):
			ups += 1
	return ups


## One game day. `ctx`: {in_port, friendly_port, storm_day, shore_leave, victories, defeat, loot_gold}.
## Returns a report: {morale, deaths, deserted, wages_paid, wages_unpaid, no_food, no_water, mutiny}.
static func daily_tick(state: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {"deaths": 0, "deserted": 0, "wages_paid": 0, "wages_unpaid": false, "no_food": false, "no_water": false, "mutiny": false, "died_of": ""}
	var fx: Dictionary = CrewEffects.compute(state["roster"])
	var sup: Dictionary = state["supplies"]
	var causes: Dictionary = {}
	# --- food ---
	var food_need: float = food_per_day(state)
	if float(sup["food"]) >= food_need:
		sup["food"] = float(sup["food"]) - food_need
		state["starve_days"] = 0
		causes["cook_bonus"] = bool(fx["cook_morale"])
	else:
		sup["food"] = 0.0
		state["starve_days"] = int(state["starve_days"]) + 1
		causes["no_food"] = true
		report["no_food"] = true
	# --- water ---
	var water_need: float = water_per_day(state)
	if float(sup["water"]) >= water_need or bool(ctx.get("in_port", false)):
		if not bool(ctx.get("in_port", false)):
			sup["water"] = float(sup["water"]) - water_need
		state["thirst_days"] = 0
	else:
		sup["water"] = 0.0
		state["thirst_days"] = int(state["thirst_days"]) + 1
		causes["no_water"] = true
		report["no_water"] = true
	# --- rum ration ---
	var rum_need: float = rum_per_day(state)
	if bool(state["rum_ration"]):
		if float(sup["rum"]) >= rum_need:
			sup["rum"] = float(sup["rum"]) - rum_need
			causes["rum_ration"] = true
		else:
			sup["rum"] = 0.0
			causes["no_rum"] = true
	else:
		causes["no_rum"] = true
	# --- wages ---
	var wages: int = wages_per_day(state)
	if wages > 0:
		if int(state["gold"]) >= wages:
			state["gold"] = int(state["gold"]) - wages
			report["wages_paid"] = wages
			state["unpaid_days"] = 0
		else:
			causes["wages_unpaid"] = true
			report["wages_unpaid"] = true
			state["unpaid_days"] = int(state["unpaid_days"]) + 1
	# --- deaths from hunger and thirst (none on Deckhand difficulty) ---
	if int(state["difficulty"]) != DECKHAND_DIFFICULTY:
		var frac: float = 0.0
		if int(state["starve_days"]) > STARVE_GRACE_DAYS:
			frac += STARVE_DEATH_FRACTION
			report["died_of"] = "hunger"
		if int(state["thirst_days"]) > THIRST_GRACE_DAYS:
			frac += THIRST_DEATH_FRACTION
			report["died_of"] = "thirst"
		if frac > 0.0:
			state["death_accum"] = float(state["death_accum"]) + frac * float(state["crew"])
			var dead: int = floori(float(state["death_accum"]))
			if dead > 0:
				state["death_accum"] = float(state["death_accum"]) - dead
				report["deaths"] = remove_crew(state, dead)
	# --- wounded: medicine heals, otherwise 10% die ---
	if int(state["wounded"]) > 0:
		var need: float = ceilf(float(state["wounded"]) / MEDICINE_WOUNDED_PER_UNIT)
		if float(sup["medicine"]) >= need:
			sup["medicine"] = float(sup["medicine"]) - need
			state["wounded"] = 0
		else:
			state["wound_accum"] = float(state["wound_accum"]) + WOUNDED_DEATH_FRACTION * float(state["wounded"])
			var gone: int = mini(floori(float(state["wound_accum"])), int(state["wounded"]))
			if gone > 0:
				state["wound_accum"] = float(state["wound_accum"]) - gone
				state["wounded"] = int(state["wounded"]) - gone
				remove_crew(state, gone)
				report["deaths"] = int(report["deaths"]) + gone
	# --- desertion in port when mutinous ---
	if bool(ctx.get("in_port", false)):
		var dfrac: float = Morale.desertion_per_day(float(state["morale"]))
		if dfrac > 0.0 and int(state["crew"]) > 0:
			state["desert_accum"] = float(state["desert_accum"]) + dfrac * float(state["crew"])
			var gone2: int = floori(float(state["desert_accum"]))
			if gone2 > 0:
				state["desert_accum"] = float(state["desert_accum"]) - gone2
				report["deserted"] = remove_crew(state, gone2)
	# --- morale ---
	for k: String in ["storm_day", "shore_leave", "defeat"]:
		if ctx.get(k, false):
			causes[k] = true
	causes["victories"] = int(ctx.get("victories", 0))
	causes["loot_gold"] = float(ctx.get("loot_gold", 0.0))
	state["morale"] = Morale.daily(float(state["morale"]), causes, bool(fx["quartermaster"]))
	report["morale"] = state["morale"]
	# --- mutiny ---
	if float(state["morale"]) < MUTINY_BELOW and int(state["crew"]) > 0:
		var day: int = int(ctx.get("day", state["day"]))
		if bool(fx["prevents_mutiny"]) and day - int(state["mutiny_shield_day"]) >= MUTINY_SHIELD_DAYS:
			state["mutiny_shield_day"] = day
			state["morale"] = MUTINY_BELOW + 5.0
		else:
			report["mutiny"] = true
	return report


## Time at sea for carpenters: repairs hull at the rated HP per minute, 1 timber per 40 HP. Returns HP repaired.
static func carpenter_repair(state: Dictionary, minutes: float) -> float:
	var fx: Dictionary = CrewEffects.compute(state["roster"])
	if float(fx["repair_hp_per_min"]) <= 0.0:
		return 0.0
	var stats: ShipStats = PortService.ship_stats(state["ship_class"])
	var missing: float = stats.hull_hp * (1.0 - float(state["ship_hull"]))
	var hp: float = minf(float(fx["repair_hp_per_min"]) * minutes, missing)
	var timber_needed: float = hp / REPAIR_HP_PER_TIMBER
	var have: float = float(state["supplies"]["timber"])
	if timber_needed > have:
		hp = have * REPAIR_HP_PER_TIMBER
		timber_needed = have
	state["supplies"]["timber"] = have - timber_needed
	state["ship_hull"] = minf(float(state["ship_hull"]) + hp / stats.hull_hp, 1.0)
	return hp
