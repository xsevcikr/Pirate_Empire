extends TestCase


func test_building_table_values() -> void:
	assert_eq(BuildingData.cost("shipyard", 2), 18000)
	assert_eq(BuildingData.days("tavern", 3), 6)
	assert_eq(BuildingData.income("market", 3), 480)
	assert_eq(BuildingData.upkeep("fort_walls", 3), 250)
	assert_eq(BuildingData.levels("cannon_tower"), 2)
	assert_eq(BuildingData.DATA["fort_walls"]["wall_hp"][2], 20000)


func test_build_takes_listed_days_and_costs_gold() -> void:
	var b := Base.new("Haven")
	var gold: int = b.build("tavern", 5000)
	assert_eq(gold, 3800)
	b.advance_days(1.9)
	assert_eq(b.level_of("tavern"), 0)
	b.advance_days(0.2)
	assert_eq(b.level_of("tavern"), 1)
	assert_eq(b.build("tavern", 100), -1)
	assert_eq(b.build("tavern", 4000), 0)


func test_plot_limit() -> void:
	var b := Base.new()
	var gold: int = 999999
	for t in ["shipyard", "shipyard", "market", "market"]:
		gold = b.build(t, gold)
		assert_true(gold >= 0 or t == "shipyard")
	var used: int = b.plots_used()
	assert_true(used <= 12)


func test_income_accrual_capped_at_seven_days() -> void:
	var b := Base.new()
	b.buildings.append({"type": "plantation", "level": 1, "damaged": false})
	b.advance_days(30.0)
	assert_near(b.gold_stored, 300.0 * 7.0, 1.0)
	assert_eq(b.collect(), 2100)
	assert_near(b.gold_stored, 0.0, 0.001)


func test_net_income_subtracts_upkeep() -> void:
	var b := Base.new()
	b.buildings.append({"type": "market", "level": 1, "damaged": false})
	b.buildings.append({"type": "dock", "level": 1, "damaged": false})
	assert_near(b.net_daily(), 80.0 - 10.0, 0.001)


func test_rush_cost() -> void:
	var b := Base.new()
	b.build("tavern", 5000)
	assert_near(b.rush_cost("tavern"), 2.0 * 24.0 * 40.0, 0.001)


func test_fleet_trade_route_pays_within_15_percent_of_prediction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var total: float = 0.0
	var trips: int = 400
	for i in trips:
		total += FleetOrders.simulate_trip(300.0, 6.0, 7, rng)
	var predicted: float = FleetOrders.predicted_trip(300.0, 6.0, 7)
	assert_true(absf(total / trips / predicted - 1.0) < 0.15, "mean %.0f vs %.0f" % [total / trips, predicted])


func test_dishonest_captain_skims() -> void:
	assert_true(FleetOrders.predicted_trip(100.0, 5.0, 2) < FleetOrders.predicted_trip(100.0, 5.0, 8))


func test_fort_siege_capture_flow() -> void:
	var s := Siege.new(4, 20000.0)
	assert_eq(s.phase, Siege.Phase.NAVAL)
	s.hit_boom(5000.0)  # too early
	assert_near(s.boom_hp, Siege.BOOM_HP, 0.001)
	for i in 4:
		s.hit_tower(i, 1800.0)
	assert_eq(s.phase, Siege.Phase.BOOM)
	s.hit_boom(3000.0)
	assert_eq(s.phase, Siege.Phase.LAND)
	s.tick_land(120.0)
	for o in Siege.LAND_OBJECTIVES:
		s.take_objective(o)
	assert_eq(s.phase, Siege.Phase.CHOICE)
	var r: Dictionary = s.choose(Siege.Fate.OCCUPY)
	assert_true(r["captured"] and r["base"])
	assert_near(r["income_mult"], 0.8, 0.0001)
	assert_eq(s.phase, Siege.Phase.DONE)


func test_land_assault_times_out_after_six_minutes() -> void:
	var s := Siege.new(1)
	s.hit_tower(0, 5000.0)
	s.hit_boom(5000.0)
	s.tick_land(361.0)
	assert_true(not s.result["captured"])


func test_siege_fates() -> void:
	for f in [Siege.Fate.PLUNDER, Siege.Fate.RANSOM]:
		var s := Siege.new(1, 40000.0)
		s.hit_tower(0, 2000.0)
		s.hit_boom(3000.0)
		for o in Siege.LAND_OBJECTIVES:
			s.take_objective(o)
		var r: Dictionary = s.choose(f, 2)
		if f == Siege.Fate.PLUNDER:
			assert_near(r["gold"], 40000.0, 0.01)
			assert_near(r["reputation"], -4.0, 0.001)
		else:
			assert_near(r["gold"], 20000.0, 0.01)
			assert_true(r["tribute"] > 0.0)


func test_base_attack_falls_in_four_minutes_without_defence() -> void:
	var b := Base.new()
	b.stored_goods = 1000.0
	b.buildings.append({"type": "market", "level": 1, "damaged": false})
	var atk := BaseAttack.new(b, 300.0)
	assert_true(BaseAttack.will_attack(b, 300.0))
	var rng := RandomNumberGenerator.new()
	var t: float = 0.0
	while not atk.resolved and t < 1000.0:
		atk.tick(1.0, rng)
		t += 1.0
	assert_true(atk.base_fell)
	assert_true(atk.warned)
	assert_near(t - BaseAttack.WARNING_S, 240.0, 1.0)
	assert_near(b.stored_goods, 700.0, 0.01)
	assert_true(b.buildings[0]["damaged"])


func test_base_holds_with_defence() -> void:
	var b := Base.new()
	b.tier = "stronghold"
	b.buildings.append({"type": "cannon_tower", "level": 2, "damaged": false})
	b.buildings.append({"type": "fort_walls", "level": 2, "damaged": false})
	b.garrison = 50
	b.station_ships.append({"broadside_power": 80.0})
	var threat: float = 300.0
	assert_true(b.defence_rating() > threat, "defence %.0f" % b.defence_rating())
	var atk := BaseAttack.new(b, threat)
	var rng := RandomNumberGenerator.new()
	for i in 600:
		atk.tick(1.0, rng)
	assert_true(atk.defended and not atk.base_fell and not b.fallen)
