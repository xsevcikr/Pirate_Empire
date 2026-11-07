extends TestCase


func _rng(s: int = 9) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["crew"] = 20
	return s


func _ctx_for(id: String) -> Dictionary:
	var e: Dictionary = SeaEventData.EVENTS[id]
	return {"region": str(e.get("only_region", "merchants_reach")), "season": "summer", "storm": true, "night": true, "navy_rep": -30.0, "bounty": 0.0}


func test_each_event_fires_as_often_as_its_chance_over_1000_hours() -> void:
	for id: String in SeaEventData.EVENTS.keys():
		var s: Dictionary = _state()
		var r: RandomNumberGenerator = _rng(3)
		var ctx: Dictionary = _ctx_for(id)
		var expected: float = SeaEvents.chance(id, ctx) * 1000.0
		var hits: int = 0
		for i in 1000:
			if SeaEvents.roll(s, ctx, r).has(id):
				hits += 1
		assert_true(absf(float(hits) - expected) <= maxf(0.1 * expected, 1.0), "%s fired %d, expected %.1f" % [id, hits, expected])


func test_mixed_regions_and_seasons_keep_the_table_average() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(4)
	var counts: Dictionary = {}
	for i in 4800:  # every region/season cell 200 times
		var ctx: Dictionary = {"region": SeaEventData.REGIONS[i % 6], "season": SeaEventData.SEASONS[(i / 6) % 4], "storm": false, "night": false, "navy_rep": -30.0, "bounty": 0.0}
		for id in SeaEvents.roll(s, ctx, r):
			counts[id] = int(counts.get(id, 0)) + 1
	for id in ["wreckage", "merchant_convoy", "bottle", "castaway", "whale_pod", "noble", "monster", "stowaway"]:
		var want: float = float(SeaEventData.EVENTS[id]["chance"]) * 4800.0
		assert_true(absf(float(counts.get(id, 0)) - want) <= maxf(0.1 * want, 1.0), "%s: %d vs %.0f" % [id, int(counts.get(id, 0)), want])


func test_conditions_gate_events() -> void:
	var base: Dictionary = {"region": "merchants_reach", "season": "summer", "storm": false, "night": false, "navy_rep": 0.0, "bounty": 0.0}
	assert_eq(SeaEvents.chance("waterspout", base), 0.0)
	assert_true(SeaEvents.chance("waterspout", base.merged({"storm": true}, true)) > 0.0)
	assert_eq(SeaEvents.chance("ghost_ship", base.merged({"region": "dead_reach", "night": false}, true)), 0.0)
	assert_eq(SeaEvents.chance("ghost_ship", base.merged({"region": "haven_waters", "night": true}, true)), 0.0)
	assert_true(SeaEvents.chance("ghost_ship", base.merged({"region": "dead_reach", "night": true}, true)) > 0.0)
	assert_true(not SeaEventData.EVENTS.has("becalmed"))  # no wind mechanics, so no becalmed spells


func test_navy_patrol_runs_from_3_to_12_percent() -> void:
	var calm: Dictionary = {"region": "iron_marches", "season": "spring", "navy_rep": 30.0, "bounty": 0.0}
	var hot: Dictionary = {"region": "iron_marches", "season": "spring", "navy_rep": -60.0, "bounty": 150.0}
	assert_near(SeaEvents.chance("navy_patrol", calm), 0.03 / (18.0 / 18.0) * 1.0 / (5.8 / 6.0), 0.002)
	assert_near(SeaEvents.chance("navy_patrol", hot), 0.12 / (5.8 / 6.0), 0.005)
	assert_true(SeaEvents.chance("navy_patrol", hot) > 3.0 * SeaEvents.chance("navy_patrol", calm))


func test_seasons_turn_every_ten_days() -> void:
	assert_eq(SeaEventData.season(0), "spring")
	assert_eq(SeaEventData.season(10), "summer")
	assert_eq(SeaEventData.season(39), "winter")
	assert_eq(SeaEventData.season(40), "spring")


func test_event_effects_on_the_state() -> void:
	var s: Dictionary = _state()
	var g: int = int(s["gold"])
	var out: Dictionary = SeaEvents.apply("wreckage", s, _rng(), {})
	assert_true(int(s["gold"]) - g >= 50 and int(s["gold"]) - g <= 400)
	assert_eq(out["toast"], "event.wreckage")
	s["rep"]["reef_folk"] = 0.0
	SeaEvents.apply("whale_pod", s, _rng(), {})
	assert_eq(s["rep"]["reef_folk"], -5.0)
	var c: int = int(s["crew"])
	SeaEvents.apply("castaway", s, _rng(2), {})
	assert_eq(int(s["crew"]), c + 1)
	var n: Dictionary = SeaEvents.noble(s, _rng(), true)
	assert_true(int(n["args"][0]) >= 3000 and int(n["args"][0]) <= 5000)
	var nav: float = float(s["rep"]["navy"])
	SeaEvents.noble(s, _rng(), false)
	assert_near(float(s["rep"]["navy"]), nav + 15.0, 0.001)
	assert_eq(SeaEvents.apply("merchant_convoy", s, _rng(), {})["spawn"], "merchant_convoy")


func test_stowaway_is_a_boy_or_a_thief() -> void:
	var boys: int = 0
	var thieves: int = 0
	for seed_v in 200:
		var s: Dictionary = _state()
		s["gold"] = 1000
		var out: Dictionary = SeaEvents.apply("stowaway", s, _rng(seed_v), {})
		if bool(out["thief"]):
			thieves += 1
			assert_eq(int(s["gold"]), 900)
		else:
			boys += 1
			assert_eq(int(s["crew"]), 21)
	assert_true(thieves > 50 and boys > 80)


func test_plague_kills_until_a_surgeon_cures_it() -> void:
	var s: Dictionary = _state()
	SeaEvents.apply("plague", s, _rng(), {})
	var out: Dictionary = SeaEvents.plague_day(s)
	assert_true(bool(out["active"]))
	assert_true(int(s["crew"]) < 20)
	var s2: Dictionary = _state()
	s2["officers"] = ["surgeon"]
	s2["supplies"]["medicine"] = 2.0
	SeaEvents.apply("plague", s2, _rng(), {})
	var out2: Dictionary = SeaEvents.plague_day(s2)
	assert_true(bool(out2["cured"]))
	assert_eq(int(s2["crew"]), 20)
	assert_near(float(s2["supplies"]["medicine"]), 1.0, 0.001)
	assert_eq(SeaEvents.plague_day(s2)["active"], false)


func test_plague_runs_out_by_itself() -> void:
	var s: Dictionary = _state()
	SeaEvents.apply("plague", s, _rng(), {})
	for i in 5:
		SeaEvents.plague_day(s)
	assert_eq(SeaEvents.plague_day(s)["active"], false)


# ---- rivals ----------------------------------------------------------------------------------------

func test_six_rivals_each_with_a_three_step_arc_or_a_boss_fight() -> void:
	assert_eq(RivalData.ORDER.size(), 6)
	for id in ["molly", "isabeau", "saltjaw", "vale"]:
		assert_eq((RivalData.ARC[id] as Array).size(), 3)


func test_arcs_start_when_their_condition_is_met() -> void:
	var s: Dictionary = _state()
	assert_true(not RivalState.available(s, "molly"))
	s["map_fragments"].append("drowned_purse_1")
	assert_true(RivalState.available(s, "molly"))
	assert_true(not RivalState.available(s, "saltjaw"))
	s["prizes_taken"] = 4
	assert_true(RivalState.available(s, "saltjaw"))
	assert_true(not RivalState.available(s, "vale"))
	s["bounty"]["navy"] = 45.0
	assert_true(RivalState.available(s, "vale"))
	assert_true(not RivalState.available(s, "valcourt"), "campaign bosses come with the campaign")


func test_challenge_chance_follows_the_meter_and_the_home_waters() -> void:
	var s: Dictionary = _state()
	s["map_fragments"].append("drowned_purse_1")
	assert_eq(RivalState.challenge_chance(s, "molly", "haven_waters"), 0.0)
	RivalState.get_rival(s, "molly")["meter"] = 50.0
	assert_near(RivalState.challenge_chance(s, "molly", "haven_waters"), 0.03, 0.0001)
	assert_eq(RivalState.challenge_chance(s, "molly", "iron_marches"), 0.0)


func test_losing_levels_the_rival_up_takes_a_trophy_and_makes_a_nemesis() -> void:
	var s: Dictionary = _state()
	s["map_fragments"].append("drowned_purse_1")
	var out: Dictionary = RivalState.record(s, "molly", false)
	var r: Dictionary = RivalState.get_rival(s, "molly")
	assert_eq(int(r["level"]), 2)
	assert_true(out["trophy"] == "flag" or out["trophy"] == "figurehead")
	assert_eq(RivalState.nemesis(s), "molly")
	assert_eq(out["taunt"], "rival.taunt.molly")
	assert_eq((RivalState.root(s)["taunts"] as Array).size(), 1)
	assert_true(float(r["meter"]) >= RivalData.MEET_GAIN + RivalData.LOSS_GAIN)
	assert_eq(RivalState.challenge_chance(s, "molly", "iron_marches"), RivalData.CHALLENGE_PER_HOUR_MAX * float(r["meter"]) / 100.0 * RivalData.NEMESIS_FACTOR)


func test_level_raises_hull_and_guns_and_molly_trades_up() -> void:
	var s: Dictionary = _state()
	var a: Dictionary = RivalState.ship_strength(s, "molly")
	assert_eq(a["class"], "sloop")
	for i in 3:
		RivalState.record(s, "molly", false)
	var b: Dictionary = RivalState.ship_strength(s, "molly")
	assert_eq(b["class"], "brigantine")
	assert_true(float(b["hp"]) > float(a["hp"]) * 1.2)
	assert_eq(int(b["level"]), 4)


func test_the_third_win_ends_the_arc_and_pays_once() -> void:
	var s: Dictionary = _state()
	var g: int = int(s["gold"])
	RivalState.record(s, "saltjaw", true)
	RivalState.record(s, "saltjaw", true)
	assert_true(not RivalState.is_defeated(s, "saltjaw"))
	var out: Dictionary = RivalState.record(s, "saltjaw", true)
	assert_true(RivalState.is_defeated(s, "saltjaw"))
	assert_eq(int(s["gold"]) - g, 25000)
	assert_eq(out["reward"]["ship"], "galleon")
	assert_eq((s["fleet"] as Array).size(), 1)
	assert_true((RivalState.record(s, "saltjaw", true)["reward"] as Dictionary).is_empty())
	assert_eq(int(s["gold"]) - g, 25000)


func test_beating_a_rival_who_beat_you_pays_double() -> void:
	var s: Dictionary = _state()
	RivalState.record(s, "saltjaw", false)
	var g: int = int(s["gold"])
	for i in 3:
		RivalState.record(s, "saltjaw", true)
	assert_eq(int(s["gold"]) - g, 50000)
	assert_eq(RivalState.nemesis(s), "")


func test_sparing_molly_gives_an_officer_and_beating_her_a_brigantine() -> void:
	var a: Dictionary = _state()
	for i in 3:
		RivalState.record(a, "molly", true, i == 2)
	assert_true((a["officers"] as Array).has("molly"))
	assert_eq((a["fleet"] as Array).size(), 0)
	var b: Dictionary = _state()
	for i in 3:
		RivalState.record(b, "molly", true, false)
	assert_eq(b["fleet"][0]["class"], "brigantine")
	assert_true(not (b["officers"] as Array).has("molly"))


func test_isabeau_gives_the_smugglers_hold_and_coves() -> void:
	var s: Dictionary = _state()
	for i in 3:
		RivalState.record(s, "isabeau", true)
	var rw: Array = RivalState.root(s)["rewards"]
	assert_true(rw.has("smugglers_hold") and rw.has("cove_network"))


func test_boss_rivals_pay_on_the_first_win_with_their_perk() -> void:
	var s: Dictionary = _state()
	var out: Dictionary = RivalState.boss_result(s, "valcourt", true)
	assert_true(RivalState.is_defeated(s, "valcourt"))
	assert_true((out["reward"]["perks"] as Array).has("ship_sovereign"))
	var lose: Dictionary = RivalState.boss_result(s, "ibrahim", false)
	assert_eq(int(RivalState.get_rival(s, "ibrahim")["level"]), 2)
	assert_true(lose["trophy"] != "")


func test_save_v10_loads_with_rivals_and_events() -> void:
	var old: Dictionary = SaveGame.new_state()
	for k in ["rivals", "sea_events", "prizes_taken"]:
		old.erase(k)
	old["version"] = 10
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(int(m["version"]), SaveGame.VERSION)
	assert_true(m.has("rivals") and m.has("sea_events"))
	assert_eq(int(m["prizes_taken"]), 0)
