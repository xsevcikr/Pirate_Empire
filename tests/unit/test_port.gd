extends TestCase


func _fresh() -> Dictionary:
	return SaveGame.new_state()


func test_starting_state_matches_brief() -> void:
	var s: Dictionary = _fresh()
	assert_eq(s["gold"], 100)
	assert_eq(s["ship_class"], "cutter")
	assert_eq(s["ship_name"], "The Driftwood")
	assert_near(s["ship_hull"], 0.7, 0.0001)
	assert_eq(s["crew"], 0)
	assert_near(s["supplies"]["food"], 4.0, 0.0001)
	assert_near(s["supplies"]["water"], 4.0, 0.0001)
	assert_near(s["supplies"]["rum"], 1.0, 0.0001)
	assert_eq(s["ammo"]["round"], 40)
	assert_eq(s["pistol_shots"], 10)
	assert_eq(s["captain_hp"], 200.0)
	assert_eq(s["melee"], "rusty_cutlass")
	assert_eq(s["docked_at"], "blackwater")
	assert_near(s["rep"]["navy"], -30.0, 0.0001)
	assert_near(s["rep"]["pirate"], 20.0, 0.0001)


func test_cutter_stats_match_class_table() -> void:
	var c: ShipStats = PortService.ship_stats("cutter")
	assert_near(c.max_speed_kn, 11.0, 0.001)
	assert_near(c.turn_rate_deg_s, 18.0, 0.001)
	assert_near(c.hull_hp, 450.0, 0.001)
	assert_eq(c.crew_max, 6)
	assert_near(c.cargo_t, 8.0, 0.001)
	assert_eq(c.guns_per_side, 1)  # one swivel per side: two swivels in all
	assert_eq(c.price, 600)
	assert_eq(c.gun_id, "swivel")


func test_swivel_gun_numbers() -> void:
	var g: Dictionary = GunData.GUNS["swivel"]
	assert_near(g["damage"], 15.0, 0.001)
	assert_near(g["velocity"], 300.0, 0.001)
	assert_near(g["effective"], 120.0, 0.001)
	assert_near(g["max"], 250.0, 0.001)
	assert_near(g["reload"], 4.0, 0.001)
	assert_near(g["spread"], 2.2, 0.001)
	assert_near(g["weight"], 0.1, 0.001)
	assert_eq(g["price"], 80)


func test_port_dock_matches_world_gen() -> void:
	var gen := WorldGen.new()
	var p: Vector2 = PortData.PORTS["blackwater"]["dock"]
	assert_near(gen.pois[0]["pos"].x, p.x, 0.01)
	assert_near(gen.pois[0]["pos"].y, p.y, 0.01)


func test_screen_prices_are_market_prices() -> void:
	var s: Dictionary = _fresh()
	var m: Market = PortData.build_market("blackwater")
	for g in Goods.ids():
		assert_near(PortService.good_buy_price(s, m, g), m.buy_price(g), 0.0001)
		assert_near(PortService.good_sell_price(m, g), m.sell_price(g), 0.0001)
	assert_near(PortService.supply_price(s, m, "food"), m.buy_price("fish"), 0.0001)
	assert_near(PortService.supply_price(s, m, "water"), 2.0, 0.0001)
	assert_near(PortService.supply_price(s, m, "medicine"), 40.0, 0.0001)


func test_deckhand_difficulty_cuts_prices_ten_percent() -> void:
	var s: Dictionary = _fresh()
	var m: Market = PortData.build_market("blackwater")
	s["difficulty"] = 0
	assert_near(PortService.supply_price(s, m, "water"), 1.8, 0.0001)
	s["difficulty"] = 2
	assert_eq(PortService.ammo_price_per_10(s, "round"), 24)  # Corsair: ammo +20%


func test_sell_fish_then_buy_food() -> void:
	var s: Dictionary = _fresh()
	var m: Market = PortData.build_market("blackwater")
	s["cargo"]["fish"] = 10.0
	var before: int = s["gold"]
	var gain: int = PortService.sell_good(s, m, "fish", 10)
	assert_true(gain >= 70 and gain <= 80, "10 fish should fetch about 76 gold, got %d" % gain)
	assert_eq(s["gold"], before + gain)
	assert_true(not s["cargo"].has("fish"))
	var gold: int = s["gold"]
	assert_true(PortService.buy_supply(s, m, "food", 4))
	assert_near(s["supplies"]["food"], 8.0, 0.0001)
	assert_true(s["gold"] < gold)


func test_cannot_overfill_the_hold() -> void:
	var s: Dictionary = _fresh()
	s["gold"] = 100000
	var m: Market = PortData.build_market("blackwater")
	assert_true(not PortService.buy_good(s, m, "iron", 200))  # 20 t into an 8 t hold
	assert_true(PortService.buy_good(s, m, "iron", 10))


func test_hire_four_deckhands_and_cap() -> void:
	var s: Dictionary = _fresh()
	s["gold"] = 400
	for i in 4:
		assert_true(PortService.hire(s, "green", "blackwater"))
	assert_eq(s["crew"], 4)
	assert_eq(s["roster"].size(), 4)
	assert_eq(s["gold"], 400 - 160)
	assert_true(PortService.hire(s, "seasoned", "blackwater"))
	assert_true(PortService.hire(s, "green", "blackwater"))
	assert_true(not PortService.hire(s, "green", "blackwater"))  # cutter holds six


func test_cannot_hire_without_gold() -> void:
	var s: Dictionary = _fresh()
	s["gold"] = 30
	assert_true(not PortService.hire(s, "green", "blackwater"))


func test_sloop_with_cutter_trade_in_costs_1400() -> void:
	var s: Dictionary = _fresh()
	assert_eq(PortService.ship_cost(s, "sloop"), 1400)
	s["gold"] = 1400
	assert_true(PortService.buy_ship(s, "sloop", "blackwater"))
	assert_eq(s["gold"], 0)
	assert_eq(s["ship_class"], "sloop")
	assert_near(s["ship_hull"], 1.0, 0.0001)


func test_trade_in_without_starter_deal_uses_condition() -> void:
	var s: Dictionary = _fresh()
	s["starter_exchange"] = false
	assert_eq(PortService.trade_in_value(s, "sloop"), 210)  # 50% x 600 x 0.7
	assert_eq(PortService.ship_cost(s, "sloop"), 1790)


func test_shipyard_tiers_and_fame() -> void:
	assert_true(PortData.can_sell_class("blackwater", "man_o_war"))
	assert_true(PortData.can_sell_class("blackwater", "cutter"))
	var s: Dictionary = _fresh()
	s["gold"] = 1000000
	s["ship_class"] = "sloop"
	s["starter_exchange"] = false
	assert_true(not PortService.buy_ship(s, "frigate", "blackwater"))  # needs fame 2,000
	s["fame"] = 2000
	assert_true(PortService.buy_ship(s, "frigate", "blackwater"))


func test_repair_cost_uses_class_multiplier() -> void:
	var s: Dictionary = _fresh()
	assert_eq(PortService.repair_cost(s), 108)  # 135 HP x 2 gold x 0.4 (cutter)
	s["gold"] = 500
	assert_true(PortService.repair(s))
	assert_near(s["ship_hull"], 1.0, 0.0001)
	assert_eq(s["gold"], 392)


func test_weapons_and_ammo_purchases() -> void:
	var s: Dictionary = _fresh()
	s["gold"] = 1000
	assert_true(PortService.buy_weapon(s, "cutlass"))
	assert_eq(s["melee"], "cutlass")
	assert_eq(s["gold"], 750)
	assert_true(not PortService.buy_weapon(s, "cutlass"))
	assert_true(PortService.buy_ammo(s, "round", 2))
	assert_eq(s["ammo"]["round"], 60)
	assert_eq(s["gold"], 710)
	s["supplies"]["small_arms"] = 2.0
	PortService.load_small_arms(s)
	assert_eq(s["pistol_shots"], 50)


func test_food_days() -> void:
	var s: Dictionary = _fresh()
	assert_near(PortService.food_days(s), 16.0, 0.001)  # 4 units feed 4 mouths... captain alone: 16 days
	s["crew"] = 3
	assert_near(PortService.food_days(s), 4.0, 0.001)


func test_upgrade_effects_scale_stats() -> void:
	var base: ShipStats = PortService.ship_stats("sloop")
	var up: ShipStats = UpgradeEffects.apply(base, {"hull": 2, "sails": 1})
	assert_near(up.hull_hp, base.hull_hp * 1.2, 0.01)
	assert_near(up.max_speed_kn, base.max_speed_kn * 1.04, 0.001)
	assert_near(base.hull_hp, 1200.0, 0.01)  # the shared resource is untouched


func test_market_persists_through_state() -> void:
	var s: Dictionary = _fresh()
	var m: Market = PortService.market_of(s, "blackwater")
	m.stock["sugar"] = 10.0
	PortService.store_market(s, "blackwater", m)
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_near(PortService.market_of(back, "blackwater").stock["sugar"], 10.0, 0.001)


func test_tutorial_steps_run_in_order() -> void:
	var step: String = "leave_dock"
	for ev in ["steered", "left_dock", "steered", "timer", "docked", "finn_talked", "lugger_looted", "docked", "sold_fish", "hired_crew", "bought_food", "quest_taken"]:
		step = TutorialData.advance(step, ev)
	assert_eq(step, "done")
	assert_eq(TutorialData.advance("leave_dock", "docked"), "leave_dock")  # other events change nothing


func test_loot_is_deterministic_and_in_range() -> void:
	var s: Dictionary = _fresh()
	var ship := Ship.new()
	ship.set_meta("loot", {"gold": [60, 90], "supplies": {"food": 6}, "cargo": {"fish": 10}})
	ship.set_meta("loot_seed", 11)
	var a: Dictionary = PrizeFlow.roll_loot(ship, s)
	var b: Dictionary = PrizeFlow.roll_loot(ship, s)
	assert_eq(a["gold"], b["gold"])
	assert_true(a["gold"] >= 60 and a["gold"] <= 90)
	PrizeFlow.apply_loot(a, s)
	assert_near(s["supplies"]["food"], 10.0, 0.001)
	assert_near(s["cargo"]["fish"], 10.0, 0.001)
	ship.free()
