extends TestCase


func test_equal_supply_demand_gives_base_price() -> void:
	var m := Market.new()
	for g in Goods.ids():
		assert_near(m.mid_price(g), Goods.base_price(g), Goods.base_price(g) * 0.01, g)


func test_selling_ten_percent_drops_price_about_six() -> void:
	var m := Market.new(100.0)
	m.stock["rum"] = 110.0
	var drop: float = 1.0 - m.mid_price("rum") / 28.0
	assert_true(drop > 0.05 and drop < 0.07, "drop %.3f" % drop)


func test_prices_stay_bounded_over_1000_days() -> void:
	var m := Market.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	m.role["rum"] = "producer"
	m.role["fish"] = "consumer"
	var lo: float = INF
	var hi: float = 0.0
	var evs: Array = Goods.EVENT_MULT.keys()
	for day in 1000:
		if rng.randf() < 0.05:
			m.events[evs[rng.randi() % evs.size()]] = rng.randf_range(72.0, 240.0)
		for i in 3:
			var g: String = Goods.ids()[rng.randi() % 12]
			if rng.randf() < 0.5:
				m.player_sell(g, rng.randf_range(1.0, 40.0))
			else:
				m.player_buy(g, rng.randf_range(1.0, 40.0), 1e9)
		m.advance(24.0)
		for g in Goods.ids():
			var r: float = m.mid_price(g) / Goods.base_price(g)
			lo = minf(lo, r)
			hi = maxf(hi, r)
	assert_true(lo >= 0.2 and hi <= 5.0, "ratio range %.2f .. %.2f" % [lo, hi])


func test_arbitrage_margin() -> void:
	var a := Market.new()
	var b := Market.new()
	a.role["rum"] = "producer"
	a.stock["rum"] = 140.0  # distillery: cheap
	b.stock["rum"] = 60.0  # pirate port: dear
	var cost: float = a.player_buy("rum", 10.0, 1e9)
	var gain: float = b.player_sell("rum", 10.0)
	var expect_buy: float = 28.0 * pow(1.4, -0.6) * 1.05 * 10.0
	var expect_sell: float = 28.0 * pow(0.6, -0.6) * 0.95 * 10.0
	assert_true(absf(cost / expect_buy - 1.0) < 0.1, "buy %.1f vs %.1f" % [cost, expect_buy])
	assert_true(absf(gain / expect_sell - 1.0) < 0.1, "sell %.1f vs %.1f" % [gain, expect_sell])
	assert_true(gain > cost)


func test_buy_refused_without_gold_or_stock() -> void:
	var m := Market.new()
	assert_eq(m.player_buy("gems", 5.0, 10.0), -1.0)
	assert_eq(m.player_buy("gems", 5000.0, 1e9), -1.0)
	assert_near(m.stock["gems"], 100.0, 0.001)


func test_events_and_reputation_move_prices() -> void:
	var m := Market.new()
	m.events["war"] = 100.0
	assert_near(m.mid_price("gunpowder"), 63.0, 0.01)
	assert_near(m.mid_price("rum"), 28.0, 0.01)
	var plain: float = Market.new().buy_price("rum")
	m.rep_mod = -0.15
	assert_true(m.buy_price("rum") > plain)
	m.events.clear()
	m.advance(1.0)


func test_upgrade_cost_is_table_times_multiplier() -> void:
	assert_eq(Upgrades.cost("hull", 3, "frigate"), 8000)
	assert_eq(Upgrades.cost("cannons", 1, "sloop"), 600)
	assert_eq(Upgrades.cost("sails", 2, "man_o_war"), 6400)
	var mow: int = Upgrades.total_cost("man_o_war")
	# The spec text says about 880,000 but its own table sums to 161,750 x 8; the table is authoritative.
	assert_eq(mow, 161750 * 8)


func test_purchase_rules() -> void:
	var owned := {}
	assert_eq(Upgrades.purchase(owned, "hull", "sloop", 1000), 600)
	assert_eq(owned["hull"], 1)
	assert_eq(Upgrades.purchase(owned, "hull", "sloop", 100), -1)
	owned["hull"] = 4
	assert_eq(Upgrades.purchase(owned, "hull", "sloop", 99999, 2), -1)
	assert_eq(Upgrades.purchase(owned, "hull", "sloop", 99999, 3), 89999)
	assert_eq(Upgrades.refund("hull", 3, "sloop"), 800)


func test_morale_events_exact() -> void:
	var c := CrewManager.new()
	c.morale = 50.0
	c.apply_event("victory")
	assert_near(c.morale, 54.0, 0.0001)
	c.apply_event("unpaid_day", 3)
	assert_near(c.morale, 48.0, 0.0001)
	c.apply_event("officer_death")
	assert_near(c.morale, 38.0, 0.0001)
	c.apply_event("atrocity")
	assert_near(c.morale, 30.0, 0.0001)


func test_morale_bands_and_efficiency() -> void:
	assert_eq(CrewManager.band(10.0), "mutinous")
	assert_eq(CrewManager.band(39.0), "unhappy")
	assert_eq(CrewManager.band(69.0), "content")
	assert_eq(CrewManager.band(70.0), "spirited")
	assert_eq(CrewManager.band(95.0), "fervent")
	assert_near(CrewManager.efficiency_mult(20.0), 0.8, 0.0001)
	assert_near(CrewManager.efficiency_mult(95.0), 1.15, 0.0001)


func test_hiring_blocked_without_funds() -> void:
	var c := CrewManager.new()
	c.gold = 100
	assert_true(not c.hire(3, "green", 1, 10, 30))
	assert_eq(c.gold, 100)
	assert_true(c.hire(2, "green", 1, 10, 30))
	assert_eq(c.gold, 20)
	c.gold = 5000
	assert_true(not c.hire(1, "seasoned", 1, 10, 30))
	assert_true(c.hire(1, "seasoned", 2, 10, 30))
	assert_true(not c.hire(50, "green", 1, 10, 30))


func test_tavern_party_and_payoff() -> void:
	var c := CrewManager.new()
	c.gold = 3000
	c.morale = 50.0
	assert_true(c.tavern_party(2000))
	assert_near(c.morale, 70.0, 0.0001)
	assert_true(not c.pay_off_mutiny(20))


func test_officer_passives_scale_with_level() -> void:
	var o := Officer.new("Mara Voss", "gunner", 5)
	assert_near(o.passive("reload_time"), -0.15, 0.0001)
	assert_near(o.passive("aim_error"), -0.20, 0.0001)
	assert_near(o.passive("ship_speed"), 0.0, 0.0001)


func test_officer_hiring_and_loyalty() -> void:
	var roster: Array = []
	var gold: int = 10000
	for i in 6:
		gold = Officer.hire(roster, Officer.new("O%d" % i, "navigator", 1, 1200), gold)
	assert_eq(gold, 2800)
	assert_eq(Officer.hire(roster, Officer.new("X"), gold), -1)
	var o: Officer = roster[0]
	o.add_loyalty(-60.0)
	assert_true(o.has_left())
	o.add_loyalty(200.0)
	assert_true(o.unlocks_variant())
