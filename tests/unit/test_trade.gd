extends TestCase


func _rng(seed_v: int = 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


func _sugar_convoy(s: Dictionary, ships: int) -> Dictionary:
	var c: Dictionary = {"id": 1, "good": "sugar", "from": "meridian", "to": "blackwater", "ships": ships, "ships_start": ships,
		"escorts": 0, "units": float(ships) * TradeData.UNITS_PER_SHIP, "depart_h": 0.0, "eta_h": 10.0, "status": TradeNetwork.Status.SAILING}
	s["convoys"].append(c)
	return c


func test_sunk_convoy_raises_destination_price_by_20_percent() -> void:
	var arrived: Dictionary = SaveGame.new_state()
	var sunk: Dictionary = SaveGame.new_state()
	_sugar_convoy(arrived, 5)
	_sugar_convoy(sunk, 5)
	TradeNetwork.lose_ships(sunk, 1, 5)
	TradeNetwork.advance(arrived, 12.0)
	TradeNetwork.advance(sunk, 12.0)
	PortService.advance_markets(arrived, 1.0)
	PortService.advance_markets(sunk, 1.0)
	var pa: float = PortService.market_of(arrived, "blackwater").mid_price("sugar")
	var ps: float = PortService.market_of(sunk, "blackwater").mid_price("sugar")
	assert_true(ps >= pa * 1.2, "sunk %f vs arrived %f" % [ps, pa])
	assert_eq(sunk["convoys_lost"], 1)


func test_partial_loss_delivers_the_rest() -> void:
	var s: Dictionary = SaveGame.new_state()
	_sugar_convoy(s, 4)
	var gone: float = TradeNetwork.lose_ships(s, 1, 1)
	assert_near(gone, TradeData.UNITS_PER_SHIP, 0.001)
	assert_near(float(TradeNetwork.find(s, 1)["units"]), 3.0 * TradeData.UNITS_PER_SHIP, 0.001)


func test_convoys_spawn_every_twelve_hours() -> void:
	var s: Dictionary = SaveGame.new_state()
	TradeNetwork.spawn_due(s, 100.0, _rng())
	assert_eq(s["convoys"].size(), 0)
	var made: Array = TradeNetwork.spawn_due(s, 100.0 + 12.0, _rng())
	assert_true(made.size() >= 3, "each producer port sends one")
	for c: Dictionary in made:
		assert_true(c["ships"] >= 2 and c["ships"] <= 5)
		assert_true(c["escorts"] >= 0 and c["escorts"] <= 2)


func test_inspection_formula() -> void:
	assert_near(Smuggling.inspection_chance(0, false, false), 0.10, 0.0001)
	assert_near(Smuggling.inspection_chance(3, false, false), 0.25, 0.0001)
	assert_near(Smuggling.inspection_chance(3, true, false), 0.20, 0.0001)
	assert_near(Smuggling.inspection_chance(3, false, true), 0.125, 0.0001)


func test_inspection_odds_match_over_10000_rolls() -> void:
	var r: RandomNumberGenerator = _rng(12345)
	var s: Dictionary = SaveGame.new_state()
	s["cargo"] = {"gunpowder": 5.0}
	s["hour"] = 12.0
	var hits: int = 0
	for i in 10000:
		if Smuggling.rolled(s, "meridian", r):
			hits += 1
	var want: float = Smuggling.inspection_chance(Smuggling.bounty_stars(s, PortData.PORTS["meridian"]["faction"]), false, false)
	assert_near(float(hits) / 10000.0, want, 0.015)


func test_fence_and_black_market_prices() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["cargo"] = {"gunpowder": 10.0}
	var g0: int = s["gold"]
	assert_eq(Smuggling.sell_illegal(s, "blackwater", "gunpowder", 4), 180)  # 1.0 x 45 x 4
	assert_eq(Smuggling.sell_illegal(s, "meridian", "gunpowder", 2), 135)  # 1.5 x 45 x 2
	assert_eq(Smuggling.sell_illegal(s, "albion", "gunpowder", 2), 0)
	assert_eq(s["gold"], g0 + 315)


func test_pay_fine_takes_cargo_and_rep() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["cargo"] = {"gunpowder": 10.0}
	s["gold"] = 100000
	var f: String = PortData.PORTS["albion"]["faction"]
	var rep0: float = s["rep"][f]
	var value: float = Smuggling.illegal_value(s, "albion")
	var out: Dictionary = Smuggling.resolve(s, "albion", Smuggling.Choice.PAY_FINE, _rng())
	assert_eq(out["gold"], -ceili(value * 2.0))
	assert_true(s["cargo"].is_empty())
	assert_near(s["rep"][f], rep0 - 5.0, 0.001)


func test_bribe_odds() -> void:
	assert_near(Smuggling.bribe_chance(0), 0.6, 0.0001)
	assert_near(Smuggling.bribe_chance(3), 0.75, 0.0001)
	var wins: int = 0
	var r: RandomNumberGenerator = _rng(99)
	for i in 2000:
		var s: Dictionary = SaveGame.new_state()
		s["cargo"] = {"gunpowder": 10.0}
		s["gold"] = 100000
		if Smuggling.resolve(s, "albion", Smuggling.Choice.BRIBE, r)["kept_cargo"]:
			wins += 1
	assert_near(float(wins) / 2000.0, 0.6, 0.04)


func test_blockade_fires_after_24_hours() -> void:
	var s: Dictionary = SaveGame.new_state()
	var f: String = PortData.PORTS["albion"]["faction"]
	var rep0: float = s["rep"][f]
	for h in 23:
		assert_true(not Blockade.tick(s, "albion", 2))
	assert_true(Blockade.tick(s, "albion", 2))
	assert_near(s["rep"][f], rep0 - 10.0, 0.001)
	assert_true(PortService.market_of(s, "albion").events.has("blockade"))
	# leaving resets the clock
	Blockade.tick(s, "albion", 1)
	Blockade.tick(s, "albion", 0)
	assert_near(s["blockade"]["albion"], 0.0, 0.001)


func test_blockade_radius() -> void:
	var dock: Vector2 = PortData.PORTS["albion"]["dock"]
	var ps: Array[Vector2] = [dock + Vector2(1400, 0), dock + Vector2(1600, 0)]
	assert_eq(Blockade.armed_near("albion", ps), 1)


func test_bank_interest_and_safety() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 1000
	assert_true(Finance.deposit(s, 600))
	assert_true(not Finance.deposit(s, 900))
	assert_eq(Finance.accrue(s, 7.0), 6)
	assert_eq(s["bank"], 606)
	Finance.defeat(s, Vector2.ZERO)
	assert_eq(s["bank"], 606)
	assert_eq(s["gold"], 200)  # half of the 400 carried


func test_defeat_uninsured_vs_insured() -> void:
	var a: Dictionary = SaveGame.new_state()
	a["ship_class"] = "sloop"
	var b: Dictionary = a.duplicate(true)
	b["gold"] = 10000
	assert_true(Finance.buy_insurance(b))
	var ra: Dictionary = Finance.defeat(a, Vector2.ZERO)
	var rb: Dictionary = Finance.defeat(b, Vector2.ZERO)
	assert_eq(a["ship_class"], "cutter")
	assert_true(not ra["ship_kept"])
	assert_eq(b["ship_class"], "sloop")
	assert_true(rb["ship_kept"])
	assert_true(not b["insured"])
	assert_eq(a["docked_at"], ra["port"])


func test_rep_modifies_sell_price() -> void:
	var m: Market = PortData.build_market("blackwater")
	var base: float = m.sell_price("sugar")
	m.rep_mod = 0.10
	assert_near(m.sell_price("sugar"), base * 1.10, 0.001)


func test_migration_from_v5() -> void:
	var s: Dictionary = SaveGame.new_state()
	for k in ["convoys", "convoy_clock_h", "convoy_seq", "convoys_lost", "bank", "insured", "blockade", "port_damage"]:
		s.erase(k)
	s["version"] = 5
	var m: Dictionary = SaveGame.migrate(s)
	assert_eq(m["version"], SaveGame.VERSION)
	assert_eq(m["bank"], 0)
	assert_true(m["convoys"] is Array)
