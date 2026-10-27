extends TestCase


func test_start_attitudes() -> void:
	var r := Reputation.new()
	assert_eq(r.rep["navy"], -30.0)
	assert_eq(r.rep["pirate"], 20.0)
	assert_eq(Reputation.tier(r.rep["navy"]), "hostile")


func test_reputation_deltas() -> void:
	var r := Reputation.new()
	r.sink_ship("navy")
	assert_near(r.rep["navy"], -34.0, 0.001)
	assert_near(r.rep["merchant"], -1.0, 0.001)
	assert_near(r.rep["pirate"], 22.0, 0.001)
	r.capture_ship("merchant")
	assert_near(r.rep["merchant"], -7.0, 0.001)
	r.plunder_city("merchant")
	assert_near(r.rep["merchant"], -22.0, 0.001)
	r.release_ship("merchant")
	assert_near(r.rep["merchant"], -19.0, 0.001)
	r.trade("merchant", 5000.0)
	assert_near(r.rep["merchant"], -18.0, 0.001)


func test_tiers_and_prices() -> void:
	assert_eq(Reputation.tier(-61.0), "hated")
	assert_eq(Reputation.tier(-21.0), "hostile")
	assert_eq(Reputation.tier(20.0), "neutral")
	assert_eq(Reputation.tier(21.0), "friendly")
	assert_eq(Reputation.tier(61.0), "allied")
	assert_near(Reputation.price_mult(-30.0), 1.5, 0.001)
	assert_near(Reputation.price_mult(30.0), 0.95, 0.001)
	assert_near(Reputation.price_mult(80.0), 0.9, 0.001)
	assert_true(not Reputation.port_access(-80.0))


func test_bounty_stars_spawn_right_hunters() -> void:
	assert_eq(Reputation.hunter_response(10.0)["stars"], 0)
	var one: Dictionary = Reputation.hunter_response(50.0)
	assert_eq(one["stars"], 1)
	assert_eq(one["ships"], 1)
	assert_eq(one["interval_h"], 8.0)
	assert_eq(Reputation.hunter_response(150.0)["ships"], 2)
	assert_eq(Reputation.hunter_response(300.0)["interval_h"], 4.0)
	var war: Dictionary = Reputation.hunter_response(450.0)
	assert_eq(war["stars"], 4)
	assert_true(war["ports_closed"])


func test_bounty_decay_and_pardon() -> void:
	var r := Reputation.new()
	r.add_bounty("merchant", 100.0)
	r.advance_days(5.0)
	assert_near(r.bounty["merchant"], 90.0, 0.001)
	r.advance_days(5.0, true)
	assert_near(r.bounty["merchant"], 90.0, 0.001)
	assert_near(r.pardon("merchant", 40.0, 5000.0), 3000.0, 0.001)
	assert_near(r.bounty["merchant"], 50.0, 0.001)
	assert_eq(r.pardon("navy", 10.0, 5000.0), -1.0)  # hostile governor refuses


func test_reputation_decays_toward_zero() -> void:
	var r := Reputation.new()
	r.advance_days(7.0)
	assert_near(r.rep["navy"], -29.0, 0.001)
	assert_near(r.rep["pirate"], 19.0, 0.001)


func test_letter_of_marque() -> void:
	var r := Reputation.new()
	assert_eq(r.buy_marque("pirate", 5000), -1)
	assert_eq(r.buy_marque("pirate", 12000), 2000)
	var before: float = r.bounty["pirate"]
	r.sink_ship("pirate")
	assert_near(r.bounty["pirate"], before, 0.001)
	assert_near(r.rep["navy"], -27.0, 0.001)  # +1 marque, +2 for hurting a navy rival
	r.attack("merchant")
	assert_eq(r.marque_faction, "")
	assert_true(r.bounty["merchant"] > 0.0)


func test_mission_generator_never_unwinnable_1000_seeds() -> void:
	var gen := WorldGen.new()
	var nav := SeaNav.new(gen)
	var rng := RandomNumberGenerator.new()
	var power: float = 100.0
	var bad: int = 0
	for s in 1000:
		rng.seed = s + 1
		var ctx := {"player_power": power, "player_speed_ms": 6.0, "port_pos": gen.pois[0]["pos"], "gen": gen, "nav": nav}
		var m: Dictionary = MissionGenerator.generate(rng, ctx)
		if not MissionGenerator.is_winnable(m, ctx):
			bad += 1
	assert_eq(bad, 0)


func test_boss_valcourt_runs_all_phases() -> void:
	var b := Boss.new("valcourt", 1)
	var landed: Array[String] = []
	var t: float = 0.0
	while not b.defeated and t < 600.0:
		for a in [b.tick(0.5)]:
			if a != "":
				landed.append(a)
		b.damage(60.0)  # 120 dps bot
		t += 0.5
	assert_true(b.defeated)
	assert_eq(b.phases_seen, [0, 1, 2] as Array[int])
	assert_true(landed.size() >= 3, "specials landed %d" % landed.size())
	assert_true(Boss.DEFS["valcourt"]["captain_hp"] == 600.0)


func test_ghost_admiral_untargetable_then_lantern() -> void:
	var b := Boss.new("ghost_admiral", 1)
	b.damage(5000.0)
	assert_near(b.hp, b.max_hp, 0.001)  # phase 1 untargetable
	b.damage(4200.0, true)  # weak point hits work and end the phase-out at 66%
	assert_eq(b.phase, 1)
	assert_true(not b.untargetable)
	b.damage(4300.0)
	assert_eq(b.phase, 2)
	var hp_before: float = b.hp
	b.damage(3000.0)
	assert_near(b.hp, hp_before, 0.001)  # lantern still lit
	b.damage(1.0, true)
	assert_true(b.lantern_destroyed)
	b.damage(9000.0)
	assert_true(b.defeated)
	assert_eq(b.phases_seen, [0, 1, 2] as Array[int])


func test_boss_difficulty_scaling_and_heal() -> void:
	assert_near(Boss.new("valcourt", 0).max_hp, 18000.0 * 0.8, 0.01)
	assert_near(Boss.new("valcourt", 3).max_hp, 18000.0 * 1.7, 0.01)
	var b := Boss.new("valcourt", 1)
	b.damage(9000.0)
	b.in_arena = false
	b.tick(60.0)
	assert_near(b.hp, 9000.0 + 18000.0 * 0.2, 1.0)


func test_boss_special_is_telegraphed_two_seconds() -> void:
	var b := Boss.new("valcourt", 1)
	var landed: String = ""
	var t: float = 0.0
	var telegraph_at: float = -1.0
	while landed == "" and t < 20.0:
		landed = b.tick(0.1)
		if telegraph_at < 0.0 and b.special_pending != "":
			telegraph_at = t
		t += 0.1
	assert_true(landed != "")
	assert_near(t - telegraph_at, 2.0, 0.25)


func test_campaign_acts_1_to_3_complete_in_order() -> void:
	var c := Campaign.new()
	assert_true(not c.complete("tutorial_sail"))  # out of order
	var guard: int = 0
	while not c.is_done() and guard < 50:
		assert_true(c.complete(c.current_beat()))
		guard += 1
	assert_eq(c.finished_acts, 3)
	assert_true(c.unlocked.has("act4"))
	assert_eq(c.done_beats.size(), 12)
