extends TestCase


func _state(crew: int = 0, type: String = "green") -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	for i in crew:
		s["roster"].append({"name": "Hand %d" % i, "type": type, "level": 1, "xp": 0})
	s["crew"] = crew
	s["supplies"]["water"] = 1000.0
	return s


func _after(start: float, causes: Dictionary) -> float:
	return Morale.daily(start, causes)


# ---- bands -------------------------------------------------------------------------------------

func test_morale_bands_edges() -> void:
	assert_eq(Morale.band(100.0), "loyal")
	assert_eq(Morale.band(80.0), "loyal")
	assert_eq(Morale.band(79.9), "content")
	assert_eq(Morale.band(50.0), "content")
	assert_eq(Morale.band(49.9), "grumbling")
	assert_eq(Morale.band(30.0), "grumbling")
	assert_eq(Morale.band(29.9), "mutinous")
	assert_eq(Morale.band(15.0), "mutinous")
	assert_eq(Morale.band(14.9), "mutiny")
	assert_eq(Morale.band(0.0), "mutiny")


func test_band_effects() -> void:
	assert_near(Morale.efficiency(90.0), 1.10, 0.0001)
	assert_near(Morale.efficiency(60.0), 1.0, 0.0001)
	assert_near(Morale.efficiency(40.0), 0.90, 0.0001)
	assert_near(Morale.efficiency(20.0), 0.75, 0.0001)
	assert_near(Morale.boarding_bonus(85.0), 0.10, 0.0001)
	assert_near(Morale.boarding_bonus(60.0), 0.0, 0.0001)
	assert_near(Morale.desertion_per_day(20.0), 0.05, 0.0001)
	assert_near(Morale.desertion_per_day(60.0), 0.0, 0.0001)


# ---- every delta (from 50, where the decay is zero before the change and 2 toward 50 after) -----

func test_each_morale_delta() -> void:
	var cases: Array = [
		[{"rum_ration": true}, 3.0], [{"cook_bonus": true}, 3.0], [{"victories": 1}, 10.0], [{"victories": 2}, 20.0],
		[{"loot_gold": 100.0}, 2.0], [{"shore_leave": true}, 5.0], [{"no_food": true}, -15.0], [{"no_water": true}, -25.0],
		[{"wages_unpaid": true}, -10.0], [{"no_rum": true}, -3.0], [{"killed_fraction": 0.10}, -2.0], [{"storm_day": true}, -2.0],
		[{"defeat": true}, -15.0],
	]
	for c: Array in cases:
		var expected: float = Morale.decay(clampf(50.0 + float(c[1]), 0.0, 100.0))
		assert_near(_after(50.0, c[0]), expected, 0.0001, str(c[0]))


func test_deltas_add_up_and_clamp() -> void:
	var all: Dictionary = {"no_food": true, "no_water": true, "wages_unpaid": true, "defeat": true}
	assert_near(_after(60.0, all), 2.0, 0.0001)  # 60 -65 -> 0, then +2 toward 50
	assert_near(_after(95.0, {"victories": 3}), 98.0, 0.0001)  # 100 clamp, -2 decay


func test_decay_pulls_toward_fifty() -> void:
	assert_near(Morale.decay(90.0), 88.0, 0.0001)
	assert_near(Morale.decay(10.0), 12.0, 0.0001)
	assert_near(Morale.decay(51.0), 50.0, 0.0001)
	assert_near(Morale.decay(90.0, true), 88.5, 0.0001)  # quartermaster: decay 25% slower
	assert_near(Morale.decay(50.0), 50.0, 0.0001)


func test_loot_cut_rules() -> void:
	var even: Dictionary = Morale.loot_split(1000.0, 0.25, 5)
	assert_near(even["captain"], 250.0, 0.001)
	assert_near(even["crew"], 750.0, 0.001)
	assert_near(even["morale"], 15.0, 0.001)  # 750 gold of shares = +15
	var greedy: Dictionary = Morale.loot_split(1000.0, 0.45, 5)
	assert_near(greedy["morale"], -5.0 + 11.0, 0.001)
	var kind: Dictionary = Morale.loot_split(1000.0, 0.10, 5)
	assert_near(kind["morale"], 5.0 + 18.0, 0.001)
	var alone: Dictionary = Morale.loot_split(1000.0, 0.25, 0)
	assert_near(alone["captain"], 1000.0, 0.001)
	assert_near(Morale.loot_split(1000.0, 0.9, 5)["captain"], 500.0, 0.001)  # slider capped at 50%


# ---- consumption -------------------------------------------------------------------------------

func test_daily_consumption() -> void:
	var s: Dictionary = _state(7)  # 8 mouths with the captain
	s["supplies"]["food"] = 10.0
	s["supplies"]["rum"] = 2.0
	var r: Dictionary = CrewLife.daily_tick(s)
	assert_near(s["supplies"]["food"], 8.0, 0.0001)  # 8 / 4
	assert_near(s["supplies"]["water"], 998.0, 0.0001)
	assert_near(s["supplies"]["rum"], 1.2, 0.0001)  # 8 / 10
	assert_true(not r["no_food"])
	assert_near(CrewLife.days_left(s, "food"), 4.0, 0.0001)


func test_cook_cuts_food_use() -> void:
	var s: Dictionary = _state(7)
	s["roster"][0]["type"] = "cook"
	assert_near(CrewLife.food_per_day(s), 2.0 * 0.85, 0.0001)
	s["roster"][0]["level"] = 5
	assert_near(CrewLife.food_per_day(s), 2.0 * 0.75, 0.0001)
	s["supplies"]["food"] = 10.0
	CrewLife.daily_tick(s)
	assert_near(s["supplies"]["food"], 10.0 - 1.5, 0.0001)


func test_cook_adds_morale_when_fed() -> void:
	var with_cook: Dictionary = _state(3)
	with_cook["roster"][0]["type"] = "cook"
	var without: Dictionary = _state(3)
	for s: Dictionary in [with_cook, without]:
		s["supplies"]["food"] = 10.0
		s["supplies"]["rum"] = 0.0
		s["morale"] = 70.0
		CrewLife.daily_tick(s)
	assert_near(with_cook["morale"] - without["morale"], 3.0, 0.0001)


func test_wages_paid_or_morale_drops() -> void:
	var s: Dictionary = _state(4)  # 4 deckhands, 1 gold each
	s["supplies"]["food"] = 10.0
	s["gold"] = 100
	var r: Dictionary = CrewLife.daily_tick(s)
	assert_eq(s["gold"], 96)
	assert_eq(r["wages_paid"], 4)
	var broke: Dictionary = _state(4)
	broke["supplies"]["food"] = 10.0
	broke["gold"] = 2
	broke["morale"] = 50.0
	broke["rum_ration"] = false
	var r2: Dictionary = CrewLife.daily_tick(broke)
	assert_true(r2["wages_unpaid"])
	assert_near(broke["morale"], 50.0 - 10.0 - 3.0 + 2.0, 0.0001)  # unpaid, no rum, decay back toward 50
	assert_eq(broke["gold"], 2)


# ---- starvation and thirst ---------------------------------------------------------------------

func test_ten_days_without_food() -> void:
	var s: Dictionary = _state(9)  # 10 mouths: exactly the rum unit we hold
	s["supplies"]["food"] = 0.0
	s["gold"] = 100000
	var morale_by_day: Array[float] = []
	var first_mutiny: int = -1
	for day in 1:
		pass
	for day in range(1, 11):
		s["day"] = day
		var r: Dictionary = CrewLife.daily_tick(s, {"day": day})
		morale_by_day.append(s["morale"])
		if r["mutiny"] and first_mutiny < 0:
			first_mutiny = day
	assert_near(morale_by_day[0], 56.0, 0.0001)  # +3 rum, -15 food, -2 decay
	assert_near(morale_by_day[1], 40.0, 0.0001)
	assert_near(morale_by_day[2], 24.0, 0.0001)
	assert_near(morale_by_day[3], 8.0, 0.0001)
	assert_near(morale_by_day[9], 2.0, 0.0001)
	assert_eq(first_mutiny, 4)
	assert_eq(s["starve_days"], 10)
	assert_eq(s["crew"], 8)  # 2% a day from day 4: the first man dies on day 9
	assert_eq(s["roster"].size(), 8)


func test_deckhand_difficulty_has_no_starvation_deaths() -> void:
	var s: Dictionary = _state(9)
	s["difficulty"] = 0
	s["supplies"]["food"] = 0.0
	s["gold"] = 100000
	for day in 10:
		CrewLife.daily_tick(s)
	assert_eq(s["crew"], 9)


func test_no_deaths_during_the_three_day_grace() -> void:
	var s: Dictionary = _state(50)
	s["gold"] = 100000
	for day in 3:
		CrewLife.daily_tick(s)
	assert_eq(s["crew"], 50)
	CrewLife.daily_tick(s)  # day 4: 2% of 50 = 1
	assert_eq(s["crew"], 49)


func test_thirst_kills_four_percent_after_two_days() -> void:
	var s: Dictionary = _state(25)
	s["supplies"]["water"] = 0.0
	s["supplies"]["food"] = 100.0
	s["gold"] = 100000
	CrewLife.daily_tick(s)
	CrewLife.daily_tick(s)
	assert_eq(s["crew"], 25)
	CrewLife.daily_tick(s)  # day 3: 4% of 25 = 1
	assert_eq(s["crew"], 24)
	assert_true(s["morale"] < 50.0)


func test_port_refills_water_for_free() -> void:
	var s: Dictionary = _state(4)
	s["supplies"]["water"] = 0.0
	s["supplies"]["food"] = 10.0
	var r: Dictionary = CrewLife.daily_tick(s, {"in_port": true})
	assert_true(not r["no_water"])


func test_desertion_in_port_when_mutinous() -> void:
	var s: Dictionary = _state(40)
	s["supplies"]["food"] = 100.0
	s["morale"] = 20.0
	s["gold"] = 100000
	var r: Dictionary = CrewLife.daily_tick(s, {"in_port": true})
	assert_eq(r["deserted"], 2)  # 5% of 40
	assert_eq(s["crew"], 38)
	var at_sea: Dictionary = _state(40)
	at_sea["supplies"]["food"] = 100.0
	at_sea["morale"] = 20.0
	at_sea["gold"] = 100000
	assert_eq(CrewLife.daily_tick(at_sea)["deserted"], 0)


# ---- wounded, surgeon, medicine ----------------------------------------------------------------

func test_surgeon_saves_a_third_of_the_fallen() -> void:
	var s: Dictionary = _state(20)
	s["roster"][0]["type"] = "surgeon"
	var r: Dictionary = CrewLife.casualties(s, 10)
	assert_eq(r["wounded"], 3)  # floor(35% of 10)
	assert_eq(r["dead"], 7)
	assert_eq(s["crew"], 13)
	assert_eq(CrewLife.fit_crew(s), 10)
	var master: Dictionary = _state(20)
	master["roster"][0] = {"name": "Doc", "type": "surgeon", "level": 5, "xp": 1000}
	assert_near(CrewEffects.compute(master["roster"])["wounded_fraction"], 0.55, 0.0001)


func test_no_surgeon_no_wounded() -> void:
	var s: Dictionary = _state(20)
	var r: Dictionary = CrewLife.casualties(s, 4)
	assert_eq(r["wounded"], 0)
	assert_eq(s["crew"], 16)
	assert_near(s["morale"], 70.0 - 4.0, 0.0001)  # 20% of the crew killed = -4


func test_medicine_heals_and_neglect_kills() -> void:
	var s: Dictionary = _state(30)
	s["supplies"]["food"] = 100.0
	s["gold"] = 100000
	s["wounded"] = 10
	s["supplies"]["medicine"] = 2.0
	CrewLife.daily_tick(s)  # 10 wounded need 2 units
	assert_eq(s["wounded"], 0)
	assert_near(s["supplies"]["medicine"], 0.0, 0.0001)
	var s2: Dictionary = _state(30)
	s2["supplies"]["food"] = 100.0
	s2["gold"] = 100000
	s2["wounded"] = 10
	CrewLife.daily_tick(s2)  # 10% of 10 = 1 dies
	assert_eq(s2["wounded"], 9)
	assert_eq(s2["crew"], 29)


# ---- levels, XP, effects, offers ---------------------------------------------------------------

func test_levels_and_xp() -> void:
	assert_eq(CrewTypes.level_for_xp(0), 1)
	assert_eq(CrewTypes.level_for_xp(99), 1)
	assert_eq(CrewTypes.level_for_xp(100), 2)
	assert_eq(CrewTypes.level_for_xp(250), 3)
	assert_eq(CrewTypes.level_for_xp(500), 4)
	assert_eq(CrewTypes.level_for_xp(1000), 5)
	assert_eq(CrewTypes.level_for_xp(9999), 5)
	var m: Dictionary = {"level": 1, "xp": 0}
	for i in 10:
		CrewTypes.add_xp(m, "battle")  # 10 each
	assert_eq(m["level"], 2)
	CrewTypes.add_xp(m, "tour")
	assert_eq(m["xp"], 150)
	assert_eq(CrewTypes.XP_GAIN["boarding"], 25)
	assert_eq(CrewTypes.XP_GAIN["storm"], 5)


func test_crew_type_table_matches_the_brief() -> void:
	var want: Dictionary = {"green": [40, 1], "seasoned": [120, 2], "gunner": [150, 3], "swordsman": [120, 2], "musketeer": [160, 3],
		"carpenter": [180, 3], "surgeon": [300, 5], "cook": [120, 2], "navigator": [350, 6], "bosun": [220, 4], "quartermaster": [400, 6]}
	for t: String in want:
		assert_eq(CrewTypes.TYPES[t]["hire"], want[t][0], t)
		assert_eq(CrewTypes.TYPES[t]["wage"], want[t][1], t)


func test_specialist_effects_do_not_stack() -> void:
	var r: Array = [{"type": "gunner", "level": 1, "xp": 0}, {"type": "gunner", "level": 3, "xp": 0}, {"type": "navigator", "level": 1, "xp": 0}, {"type": "bosun", "level": 1, "xp": 0}]
	var fx: Dictionary = CrewEffects.compute(r)
	assert_near(fx["reload_mult"], 0.88, 0.0001)
	assert_near(fx["spread_mult"], 0.90, 0.0001)
	assert_near(fx["speed_mult"], 1.04, 0.0001)
	assert_near(fx["sail_change_mult"], 0.80, 0.0001)
	assert_near(fx["fire_spread_mult"], 0.70, 0.0001)
	assert_near(fx["forecast_h"], 6.0, 0.0001)


func test_quality_follows_roster_strength() -> void:
	var r: Array = [{"type": "swordsman", "level": 1, "xp": 0}, {"type": "green", "level": 1, "xp": 0}]
	assert_near(CrewEffects.compute(r)["quality"], 1.3, 0.0001)


func test_tavern_offers_one_per_level_and_refresh() -> void:
	var a: Array[String] = CrewTypes.offers(1, 10, 2)
	assert_eq(a.size(), 2)
	assert_eq(CrewTypes.offers(1, 10, 2), CrewTypes.offers(1, 11, 2))  # same two-day window
	assert_true(a[0] != a[1])
	var s: Dictionary = _state()
	s["gold"] = 10000
	var offers: Array[String] = PortService.tavern_offers(s, "blackwater")
	assert_true(PortService.hire(s, offers[0], "blackwater"))
	assert_true(not PortService.tavern_offers(s, "blackwater").has(offers[0]))
	assert_true(not PortService.hire(s, offers[0], "blackwater"))
	assert_eq(s["roster"][0]["type"], offers[0])


# ---- mutiny ------------------------------------------------------------------------------------

func test_mutiny_options() -> void:
	var s: Dictionary = _state(10)
	s["gold"] = 1500
	s["morale"] = 5.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	assert_eq(Mutiny.pay_off_cost(s), 1000)
	assert_true(Mutiny.resolve(Mutiny.Option.PAY_OFF, s, rng)["ok"])
	assert_eq(s["gold"], 500)
	assert_near(s["morale"], 35.0, 0.0001)
	var poor: Dictionary = _state(10)
	poor["gold"] = 10
	assert_true(not Mutiny.resolve(Mutiny.Option.PAY_OFF, poor, rng)["ok"])
	var m: Dictionary = _state(10)
	Mutiny.resolve(Mutiny.Option.MAROON, m, rng)
	assert_eq(m["crew"], 6)
	assert_near(m["morale"], 35.0, 0.0001)


func test_mutiny_duel_is_seeded() -> void:
	var a: Dictionary = _state(10)
	var b: Dictionary = _state(10)
	var r1 := RandomNumberGenerator.new()
	r1.seed = 12
	var r2 := RandomNumberGenerator.new()
	r2.seed = 12
	assert_eq(Mutiny.resolve(Mutiny.Option.DUEL, a, r1)["ok"], Mutiny.resolve(Mutiny.Option.DUEL, b, r2)["ok"])
	assert_near(Mutiny.duel_win_chance(a), 0.47, 0.0001)
	a["melee"] = "cutlass"
	assert_near(Mutiny.duel_win_chance(a), 0.62, 0.0001)


func test_quartermaster_prevents_one_mutiny_a_week() -> void:
	var s: Dictionary = _state(5)
	s["roster"][0] = {"name": "Q", "type": "quartermaster", "level": 5, "xp": 1000}
	s["supplies"]["food"] = 0.0
	s["morale"] = 5.0
	s["gold"] = 100000
	var first: Dictionary = CrewLife.daily_tick(s, {"day": 10})
	assert_true(not first["mutiny"])
	s["morale"] = 5.0
	var second: Dictionary = CrewLife.daily_tick(s, {"day": 12})
	assert_true(second["mutiny"])
	s["morale"] = 5.0
	var third: Dictionary = CrewLife.daily_tick(s, {"day": 18})
	assert_true(not third["mutiny"])


# ---- carpenter ---------------------------------------------------------------------------------

func test_carpenter_repairs_fifteen_hp_a_minute_with_timber() -> void:
	var s: Dictionary = _state(2)
	s["roster"][0]["type"] = "carpenter"
	s["ship_class"] = "sloop"
	s["ship_hull"] = 0.5  # 600 of 1,200 HP missing
	s["supplies"]["timber"] = 5.0
	var hp: float = CrewLife.carpenter_repair(s, 4.0)
	assert_near(hp, 60.0, 0.0001)
	assert_near(s["ship_hull"], 0.55, 0.0001)
	assert_near(s["supplies"]["timber"], 5.0 - 1.5, 0.0001)  # 60 HP / 40 per timber
	var dry: Dictionary = _state(2)
	dry["roster"][0]["type"] = "carpenter"
	dry["ship_class"] = "sloop"
	dry["ship_hull"] = 0.5
	assert_near(CrewLife.carpenter_repair(dry, 10.0), 0.0, 0.0001)  # no timber, no sea repairs


func test_loot_cut_and_morale_through_prize_flow() -> void:
	var s: Dictionary = _state(4)
	var loot: Dictionary = {"gold": 800}
	var split: Dictionary = PrizeFlow.share_out(loot, s)
	assert_eq(loot["gold"], 200)  # captain keeps 25%
	assert_near(split["crew"], 600.0, 0.001)
	assert_near(s["morale"], 70.0 + 12.0, 0.001)


func test_navigator_adds_four_percent_speed() -> void:
	var s: Dictionary = _state(2)
	Session.state = s
	assert_near(Session.player_stats().max_speed_kn, 11.0, 0.0001)
	s["roster"][0]["type"] = "navigator"
	assert_near(Session.player_stats().max_speed_kn, 11.44, 0.0001)
	Session.state = {}
