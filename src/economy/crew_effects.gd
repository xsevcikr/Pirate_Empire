class_name CrewEffects
extends RefCounted
## What the roster does for the ship: one best member of each specialist type counts, so hiring five gunners
## does not stack. Levels matter only where the spec names a level-5 effect.


static func _best(roster: Array, type: String) -> Dictionary:
	var best: Dictionary = {}
	for m: Dictionary in roster:
		if m["type"] == type and (best.is_empty() or int(m["level"]) > int(best["level"])):
			best = m
	return best


static func compute(roster: Array) -> Dictionary:
	var fx: Dictionary = {
		"reload_mult": 1.0, "spread_mult": 1.0, "food_use_mult": 1.0, "cook_morale": false, "wounded_fraction": 0.0,
		"speed_mult": 1.0, "reveal_radius_mult": 1.0, "forecast_h": 0.0, "repair_hp_per_min": 0.0, "leak_plug_mult": 1.0,
		"sail_change_mult": 1.0, "fire_spread_mult": 1.0, "volley_kill_fraction": 0.0, "quartermaster": false,
		"quality": 1.0, "prevents_mutiny": false,
	}
	var g: Dictionary = _best(roster, "gunner")
	if not g.is_empty():
		fx["reload_mult"] = CrewTypes.TYPES["gunner"]["reload_mult"]
		fx["spread_mult"] = CrewTypes.TYPES["gunner"]["spread_mult"]
	var cook: Dictionary = _best(roster, "cook")
	if not cook.is_empty():
		var key: String = "food_use_l5" if int(cook["level"]) >= CrewTypes.MAX_LEVEL else "food_use"
		fx["food_use_mult"] = 1.0 + CrewTypes.TYPES["cook"][key]
		fx["cook_morale"] = true
	var doc: Dictionary = _best(roster, "surgeon")
	if not doc.is_empty():
		var k2: String = "wounded_fraction_l5" if int(doc["level"]) >= CrewTypes.MAX_LEVEL else "wounded_fraction"
		fx["wounded_fraction"] = CrewTypes.TYPES["surgeon"][k2]
	if not _best(roster, "navigator").is_empty():
		fx["speed_mult"] = 1.0 + CrewTypes.TYPES["navigator"]["speed"]
		fx["reveal_radius_mult"] = 1.0 + CrewTypes.TYPES["navigator"]["reveal_radius"]
		fx["forecast_h"] = CrewTypes.TYPES["navigator"]["forecast_h"]
	if not _best(roster, "carpenter").is_empty():
		fx["repair_hp_per_min"] = CrewTypes.TYPES["carpenter"]["repair_hp_per_min"]
		fx["leak_plug_mult"] = CrewTypes.TYPES["carpenter"]["leak_plug_mult"]
	if not _best(roster, "bosun").is_empty():
		fx["sail_change_mult"] = 1.0 - CrewTypes.TYPES["bosun"]["sail_change"]
		fx["fire_spread_mult"] = 1.0 + CrewTypes.TYPES["bosun"]["fire_spread"]
	if not _best(roster, "musketeer").is_empty():
		fx["volley_kill_fraction"] = CrewTypes.TYPES["musketeer"]["volley_kill_fraction"]
	var qm: Dictionary = _best(roster, "quartermaster")
	if not qm.is_empty():
		fx["quartermaster"] = true
		fx["prevents_mutiny"] = int(qm["level"]) >= CrewTypes.MAX_LEVEL
	if not roster.is_empty():
		var total: float = 0.0
		for m: Dictionary in roster:
			total += CrewTypes.TYPES[m["type"]]["strength"]
		fx["quality"] = total / roster.size()
	return fx
