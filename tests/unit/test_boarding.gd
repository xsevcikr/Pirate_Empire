extends TestCase


func _trial(a: int, d: int, seeds: int) -> Dictionary:
	var attacker_wins: int = 0
	var max_t: float = 0.0
	for s in seeds:
		var sim := BoardingSim.new(BoardingSide.new(a), BoardingSide.new(d), s + 1)
		while sim.tick(0.5) == BoardingSim.Outcome.ONGOING:
			pass
		if sim.outcome == BoardingSim.Outcome.ATTACKER_WINS:
			attacker_wins += 1
		max_t = maxf(max_t, sim.time_s)
	return {"wins": attacker_wins, "max_t": max_t}


func test_larger_crew_wins_about_95_of_100_within_120s() -> void:
	var r: Dictionary = _trial(35, 30, 100)
	assert_true(r["wins"] >= 91 and r["wins"] <= 99, "larger side won %d of 100" % r["wins"])
	assert_true(r["max_t"] <= 120.0, "longest fight %.0f s" % r["max_t"])


func test_smaller_crew_wins_rarely() -> void:
	var r: Dictionary = _trial(30, 35, 100)
	var small_wins: int = r["wins"]
	assert_true(small_wins >= 1 and small_wins <= 9, "smaller side won %d of 100" % small_wins)


func test_same_seed_same_result() -> void:
	assert_eq(_trial(35, 30, 5)["wins"], _trial(35, 30, 5)["wins"])


func test_player_kills_shrink_enemy_pool() -> void:
	var sim := BoardingSim.new(BoardingSide.new(30), BoardingSide.new(30))
	sim.player_kill(4)
	assert_near(sim.defender.pool, 18.0, 0.001)


func test_captain_defeat_halves_morale() -> void:
	var sim := BoardingSim.new(BoardingSide.new(30), BoardingSide.new(30))
	var before: float = sim.defender.morale
	sim.captain_defeated()
	assert_near(sim.defender.morale, before * 0.5, 0.001)


func test_grapple_needs_three_lines_and_pulls_in() -> void:
	var g := Grapple.new()
	assert_true(Grapple.can_grapple(30.0, 3.0, 10.0))
	assert_true(not Grapple.can_grapple(50.0, 3.0, 10.0))
	assert_true(not Grapple.can_grapple(30.0, 8.0, 10.0))
	assert_true(not Grapple.can_grapple(30.0, 3.0, 80.0))
	var thrown: bool = false
	for i in 20:
		thrown = g.hold(0.1) or thrown
	assert_true(thrown)
	assert_eq(g.lines.size(), 3)
	for i in 50:
		g.tick(0.1)
	assert_true(g.is_locked())
	assert_near(g.gap(30.0), 6.0, 0.001)


func test_cut_line_prevents_lock() -> void:
	var g := Grapple.new()
	g.hold(2.0)
	g.damage_line(0, 200.0)
	for i in 100:
		g.tick(0.1)
	assert_true(not g.is_locked())


func test_fate_values() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var info := {"ship_value": 1000.0, "cargo_value": 400.0, "equipment_value": 200.0, "survivors": 20, "prize_crew_available": 3, "kindly_crew": true}
	assert_near(CaptureFate.resolve(CaptureFate.Fate.SELL, info, rng)["gold"], 900.0, 0.001)
	assert_near(CaptureFate.resolve(CaptureFate.Fate.RANSOM, info, rng)["gold"], 200.0, 0.001)
	assert_near(CaptureFate.resolve(CaptureFate.Fate.STRIP_AND_SINK, info, rng)["gold"], 460.0, 0.001)
	var rel: Dictionary = CaptureFate.resolve(CaptureFate.Fate.RELEASE, info, rng)
	assert_true(rel["reputation"] > 0.0)
	assert_near(rel["morale"], 10.0, 0.001)
	assert_eq(CaptureFate.resolve(CaptureFate.Fate.PRESS_CREW, info, rng)["recruits"], 5)
	assert_true(CaptureFate.resolve(CaptureFate.Fate.CAPTURE, info, rng)["ship_added"])
	info["prize_crew_available"] = 0
	assert_true(not CaptureFate.resolve(CaptureFate.Fate.CAPTURE, info, rng)["ok"])


func test_ransom_rescue_rate_about_one_in_five() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hits: int = 0
	for i in 1000:
		if CaptureFate.resolve(CaptureFate.Fate.RANSOM, {"ship_value": 100.0}, rng)["rescue_fleet"]:
			hits += 1
	assert_true(hits > 160 and hits < 240, "rescues %d / 1000" % hits)


func test_loot_rules() -> void:
	assert_near(Loot.sinking_barrels(1000.0), 250.0, 0.001)
	assert_near(Loot.boarding_loot(400.0, 100.0, "greedy", false), 250.0, 0.001)
	assert_near(Loot.boarding_loot(400.0, 100.0, "greedy", true), 500.0, 0.001)
	assert_near(Loot.captain_share(100.0, 5), 60.0, 0.001)


func test_captured_ship_joins_fleet() -> void:
	var f := Fleet.new()
	f.add_captured("brigantine", 0.4, 6, "Sea Wolf")
	assert_eq(f.size(), 1)
	assert_true(f.has_ship("Sea Wolf"))
