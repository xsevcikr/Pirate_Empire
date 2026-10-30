extends TestCase
## Crew personalities and loyalty (CrewPersona) and the surrender hail (Parley).


func _state(traits: Array, loyalty: float = 50.0) -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	for i in traits.size():
		s["roster"].append({"name": "Hand %d" % i, "type": "green", "level": 1, "xp": 0, "trait": traits[i], "loyalty": loyalty})
	s["crew"] = traits.size()
	s["supplies"]["water"] = 1000.0
	s["supplies"]["food"] = 1000.0
	s["supplies"]["rum"] = 1000.0
	s["gold"] = 10000
	return s


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_new_hands_get_a_trait_and_loyalty() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 1000
	for i in 3:
		assert_true(PortService.hire(s, "green", PortData.START_PORT), "hired")
	assert_eq(s["roster"].size(), 3)
	for m: Dictionary in s["roster"]:
		assert_true(CrewPersona.TRAITS.has(m["trait"]), "known trait %s" % m["trait"])
		assert_true(float(m["loyalty"]) >= 40.0 and float(m["loyalty"]) <= 60.0, "starting loyalty %.0f" % m["loyalty"])


func test_traits_are_deterministic_and_varied() -> void:
	var seen: Dictionary = {}
	for i in 40:
		var a: Dictionary = {"name": PortService.NAMES[i % PortService.NAMES.size()], "type": "green"}
		var b: Dictionary = a.duplicate()
		CrewPersona.ensure(a, 7 + i * 13)
		CrewPersona.ensure(b, 7 + i * 13)
		assert_eq(a["trait"], b["trait"])
		seen[a["trait"]] = true
	assert_true(seen.size() >= 5, "%d different traits in 40 hands" % seen.size())


func test_loyalty_bands() -> void:
	assert_eq(CrewPersona.band(90.0), "devoted")
	assert_eq(CrewPersona.band(80.0), "devoted")
	assert_eq(CrewPersona.band(60.0), "loyal")
	assert_eq(CrewPersona.band(40.0), "wavering")
	assert_eq(CrewPersona.band(10.0), "disloyal")


func test_loyalty_drifts_toward_morale() -> void:
	var s: Dictionary = _state(["brave"], 50.0)
	s["morale"] = 90.0
	CrewPersona.daily(s, {}, {}, _rng())
	assert_near(CrewPersona.loyalty(s["roster"][0]), 56.0, 0.001)


func test_steadfast_falls_slowly_and_has_a_floor() -> void:
	var s: Dictionary = _state(["steadfast", "brave"], 50.0)
	s["morale"] = 10.0
	CrewPersona.daily(s, {}, {}, _rng())
	assert_near(CrewPersona.loyalty(s["roster"][0]), 47.0, 0.001)
	assert_near(CrewPersona.loyalty(s["roster"][1]), 44.0, 0.001)
	CrewPersona.add_loyalty(s["roster"][0], -50.0)
	assert_near(CrewPersona.loyalty(s["roster"][0]), 35.0, 0.001)


func test_drunkard_wants_his_rum() -> void:
	var wet: Dictionary = _state(["drunkard"], 50.0)
	var dry: Dictionary = _state(["drunkard"], 50.0)
	wet["morale"] = 50.0
	dry["morale"] = 50.0
	CrewPersona.daily(wet, {"rum_ration": true}, {}, _rng())
	CrewPersona.daily(dry, {"no_rum": true}, {}, _rng())
	assert_near(CrewPersona.loyalty(wet["roster"][0]), 52.0, 0.001)
	assert_near(CrewPersona.loyalty(dry["roster"][0]), 45.0, 0.001)


func test_greedy_hates_a_fat_captains_cut_and_loves_loot() -> void:
	var s: Dictionary = _state(["greedy", "brave"], 50.0)
	s["morale"] = 50.0
	s["captain_cut"] = 0.45
	CrewPersona.daily(s, {}, {}, _rng())
	assert_near(CrewPersona.loyalty(s["roster"][0]), 47.0, 0.001)
	assert_near(CrewPersona.loyalty(s["roster"][1]), 50.0, 0.001)
	CrewPersona.on_loot(s, 200.0)
	assert_near(CrewPersona.loyalty(s["roster"][0]), 55.0, 0.001)
	assert_near(CrewPersona.loyalty(s["roster"][1]), 54.0, 0.001)


func test_events_by_trait() -> void:
	var s: Dictionary = _state(["brave", "coward", "hothead", "cheerful"], 50.0)
	CrewPersona.on_event(s, "boarding_win")
	assert_near(CrewPersona.loyalty(s["roster"][0]), 56.0, 0.001)
	assert_near(CrewPersona.loyalty(s["roster"][3]), 52.0, 0.001)
	CrewPersona.on_event(s, "defeat")
	assert_near(CrewPersona.loyalty(s["roster"][1]), 52.0 - 9.0, 0.001)
	assert_near(CrewPersona.loyalty(s["roster"][2]), 52.0 - 11.0, 0.001)


func test_cheerful_hands_lift_morale_capped() -> void:
	var s: Dictionary = _state(["cheerful", "cheerful", "cheerful", "cheerful", "cheerful"], 50.0)
	s["morale"] = 50.0
	var out: Dictionary = CrewPersona.daily(s, {}, {}, _rng())
	assert_near(float(out["morale_delta"]), CrewPersona.CHEER_MAX, 0.001)


func test_disloyal_men_desert_in_port_only() -> void:
	var s: Dictionary = _state(["coward", "coward", "coward", "coward", "coward", "coward", "brave", "brave"], 5.0)
	s["roster"][6]["loyalty"] = 90.0
	s["roster"][7]["loyalty"] = 90.0
	s["morale"] = 5.0
	var at_sea: Dictionary = CrewPersona.daily(s, {}, {}, _rng())
	assert_eq(at_sea["deserted"].size(), 0)
	var gone: int = 0
	for d in 10:
		gone += CrewPersona.daily(s, {}, {"in_port": true}, _rng(d + 3))["deserted"].size()
	assert_true(gone >= 4, "%d cowards deserted" % gone)
	assert_eq(int(s["crew"]), s["roster"].size())
	var brave_left: int = 0
	for m: Dictionary in s["roster"]:
		if m["trait"] == "brave":
			brave_left += 1
	assert_eq(brave_left, 2, "the loyal men stay")


func test_hands_without_a_trait_are_left_alone() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["roster"].append({"name": "Old", "type": "green", "level": 1, "xp": 0})
	s["crew"] = 1
	s["morale"] = 0.0
	var out: Dictionary = CrewPersona.daily(s, {"storm_day": true}, {"in_port": true}, _rng())
	assert_near(float(out["morale_delta"]), 0.0, 0.001)
	assert_eq(out["deserted"].size(), 0)
	assert_true(not s["roster"][0].has("loyalty"))


func test_fight_mods() -> void:
	var brave: Dictionary = {"trait": "brave", "loyalty": 85.0}
	var coward: Dictionary = {"trait": "coward", "loyalty": 10.0}
	var bm: Dictionary = CrewPersona.fight_mods(brave)
	var cm: Dictionary = CrewPersona.fight_mods(coward)
	assert_near(bm["melee_mult"], 1.15, 0.001)
	assert_near(bm["nerve"], 1.05 * CrewPersona.DEVOTED_NERVE, 0.001)
	assert_true(bm["rallies"] and not bm["panics"])
	assert_near(cm["melee_mult"], 0.85, 0.001)
	assert_near(cm["nerve"], CrewPersona.DISLOYAL_NERVE, 0.001)
	assert_true(cm["panics"])


func test_deck_fight_uses_personalities() -> void:
	var s: Dictionary = _state(["brave", "coward"], 50.0)
	s["roster"][0]["loyalty"] = 90.0
	var c: DeckCombat = DeckBridge.build(3, 1.0, 70.0, "merchant", 4, 1.0, 50.0, s, 5)
	var by_name: Dictionary = {}
	for f: FighterState in c.fighters:
		by_name[f.display_name] = f
	assert_near((by_name["Hand 0"] as FighterState).melee_mult, 1.15, 0.001)
	assert_true((by_name["Hand 0"] as FighterState).rallies)
	assert_near((by_name["Hand 1"] as FighterState).melee_mult, 0.85, 0.001)
	assert_true((by_name["Hand 1"] as FighterState).panics)
	assert_true((by_name["Hand 0"] as FighterState).morale_effic > (by_name["Hand 1"] as FighterState).morale_effic)


func test_loyal_men_help_in_a_mutiny() -> void:
	var s: Dictionary = _state(["brave", "brave", "brave", "coward", "coward"], 70.0)
	s["roster"][3]["loyalty"] = 10.0
	s["roster"][4]["loyalty"] = 5.0
	var none: Dictionary = _state(["coward"], 10.0)
	assert_near(Mutiny.duel_win_chance(s) - Mutiny.duel_win_chance(none), 0.06, 0.0001)
	assert_eq(CrewPersona.ringleader(s), "Hand 4")
	Mutiny.resolve(Mutiny.Option.MAROON, s, _rng())
	assert_eq(int(s["crew"]), 3)
	for m: Dictionary in s["roster"]:
		assert_eq(m["trait"], "brave", "the mutineers were marooned")


func test_devoted_crew_talks_down_a_mutiny() -> void:
	var s: Dictionary = _state(["steadfast", "steadfast", "brave", "coward"], 95.0)
	s["roster"][3]["loyalty"] = 5.0
	s["morale"] = 5.0
	s["rum_ration"] = true
	var r: Dictionary = CrewLife.daily_tick(s, {"day": 10})
	assert_true(not r["mutiny"], "talked down")
	assert_eq(r["talked_down"], "Hand 3")
	s["morale"] = 5.0
	r = CrewLife.daily_tick(s, {"day": 11})
	assert_true(r["mutiny"], "only once a week")


func test_daily_tick_reports_persona() -> void:
	var s: Dictionary = _state(["cheerful", "cheerful"], 50.0)
	s["morale"] = 50.0
	var before: float = Morale.daily(50.0, {"rum_ration": true})
	var r: Dictionary = CrewLife.daily_tick(s, {"day": 3})
	assert_near(float(r["morale"]), before + 2.0, 0.001)
	assert_true(r.has("persona_events") and r.has("deserted_names"))


func test_save_migration_gives_old_crews_personalities() -> void:
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 17
	old["morale"] = 90.0
	old["roster"] = [{"name": "Jack", "type": "gunner", "level": 2, "xp": 120}, {"name": "Ann", "type": "green", "level": 1, "xp": 0}]
	old.erase("persona_talk_day")
	var d: Dictionary = SaveGame.from_json(SaveGame.to_json(old))
	assert_eq(int(d["version"]), SaveGame.VERSION)
	assert_eq(int(d["persona_talk_day"]), -99)
	for m: Dictionary in d["roster"]:
		assert_true(CrewPersona.TRAITS.has(m["trait"]))
		assert_near(float(m["loyalty"]), 70.0, 0.001)


func test_parley_odds() -> void:
	var weak_merchant: float = Parley.chance({"faction": "merchant", "ours": 40.0, "theirs": 10.0, "hull": 0.3, "fame": 1000.0})
	var fresh_navy: float = Parley.chance({"faction": "navy", "ours": 20.0, "theirs": 40.0, "hull": 1.0, "fame": 0.0})
	var even_pirate: float = Parley.chance({"faction": "pirate", "ours": 20.0, "theirs": 20.0, "hull": 1.0})
	assert_true(weak_merchant > 0.85, "battered merchant %.2f" % weak_merchant)
	assert_near(fresh_navy, Parley.CHANCE_CAP[0], 0.001)
	assert_near(even_pirate, 0.05, 0.001)
	var devoted: float = Parley.chance({"faction": "pirate", "ours": 20.0, "theirs": 20.0, "hull": 1.0, "devoted_share": 1.0})
	assert_near(devoted - even_pirate, Parley.LOYAL_WEIGHT, 0.001)
