extends TestCase


func _rng(s: int = 3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_reduced_mass_and_energy() -> void:
	assert_near(CollisionModel.reduced_mass(100.0, 100.0), 50.0, 0.001)
	assert_near(CollisionModel.reduced_mass(90000.0, 0.0), 90000.0, 0.001)  # land is infinite
	assert_near(CollisionModel.impact_energy(100.0, 100.0, 10.0), 2500.0, 0.001)
	assert_near(CollisionModel.impact_energy(90000.0, 0.0, 4.0), 720000.0, 0.001)


func test_material_factors() -> void:
	assert_near(CollisionModel.hull_damage(2000.0, "rock"), 1.0, 0.0001)
	assert_near(CollisionModel.hull_damage(2000.0, "reef"), 0.7, 0.0001)
	assert_near(CollisionModel.hull_damage(2000.0, "ship"), 0.8, 0.0001)
	assert_near(CollisionModel.hull_damage(2000.0, "dock"), 0.5, 0.0001)
	assert_near(CollisionModel.hull_damage(2000.0, "sand"), 0.15, 0.0001)
	assert_near(CollisionModel.hull_damage(2000.0, "ice"), 0.9, 0.0001)


func test_ram_upgrade_takes_less_and_deals_more() -> void:
	var base: float = CollisionModel.hull_damage(1.0e6, "ship")
	assert_near(CollisionModel.hull_damage(1.0e6, "ship", false, true), base * 0.7, 0.001)
	assert_near(CollisionModel.hull_damage(1.0e6, "ship", true, false), base * 1.5, 0.001)


func test_sloop_hitting_rock_at_10_knots_takes_the_formula_damage() -> void:
	var sloop: ShipStats = load("res://data/ships/sloop.tres")
	var v: float = 10.0 * 0.5144
	var energy: float = 0.5 * sloop.mass_kg * v * v
	var expect: float = energy / 2000.0 * 1.0
	var e: float = CollisionModel.impact_energy(sloop.mass_kg, 0.0, v)
	assert_near(CollisionModel.hull_damage(e, "rock"), expect, 0.01)
	assert_true(expect > sloop.hull_hp * 0.3, "a 10 kn rock hit is a serious blow, got %f of %f" % [expect, sloop.hull_hp])
	var dm := DamageModel.new(sloop, 5)
	var before: float = dm.hull_hp_total()
	dm.apply_impact(0, expect, CollisionModel.LEAK_T_PER_S, false)
	assert_near(before - dm.hull_hp_total(), minf(expect, before), 0.5)


func test_consequence_thresholds() -> void:
	var r: RandomNumberGenerator = _rng()
	var small: Dictionary = CollisionModel.consequences(50.0, 1000.0, 10, 40.0, r)  # 5%
	assert_true(not small["leak"] and not small["mast_breaks"] and small["overboard"] == 0 and small["crates"] == 0)
	var mid: Dictionary = CollisionModel.consequences(150.0, 1000.0, 10, 40.0, r)  # 15%: leak, no mast
	assert_true(mid["leak"] and not mid["mast_breaks"] and mid["overboard"] == 0)


func test_big_hits_break_masts_and_throw_crew_over_often_enough() -> void:
	var r: RandomNumberGenerator = _rng(11)
	var masts: int = 0
	var overboard: int = 0
	var crates: int = 0
	for i in 4000:
		var c: Dictionary = CollisionModel.consequences(400.0, 1000.0, 20, 40.0, r)
		masts += 1 if c["mast_breaks"] else 0
		overboard += int(c["overboard"])
		crates += int(c["crates"])
	assert_near(float(masts) / 4000.0, 0.30, 0.03)
	assert_near(float(overboard) / 4000.0, 20.0 * 0.02, 0.06)
	assert_near(float(crates) / 4000.0, 4.0 * 0.10, 0.05)  # 40 t = four 10 t lots at 10% each


func test_grounding_rules() -> void:
	assert_eq(CollisionModel.grounding("sand", 3.0), "stuck")
	assert_eq(CollisionModel.grounding("sand", 5.0), "slide")
	assert_eq(CollisionModel.grounding("rock", 7.0), "hole")
	assert_eq(CollisionModel.grounding("rock", 5.0), "bump")


func test_kedge_takes_30_seconds_of_holding() -> void:
	var g := Grounding.new()
	g.touch("sand", 2.0, 0.0, Vector2(0, 1))
	assert_true(g.stuck)
	for i in 29:
		assert_true(not g.kedge(1.0, true))
	assert_true(g.kedge(1.0, true))
	assert_true(not g.stuck)


func test_tide_and_dumping_also_free_the_ship() -> void:
	var g := Grounding.new()
	g.touch("sand", 2.0, 0.0, Vector2.ZERO)
	assert_true(not g.tide_check(0.3))
	assert_true(g.tide_check(0.7))
	g.touch("sand", 2.0, 0.0, Vector2.ZERO)
	var cargo: Dictionary = {"sugar": 20.0}
	var dumped: Dictionary = g.dump_cargo(cargo)
	assert_eq(dumped["sugar"], 10.0)
	assert_true(not g.stuck)


func test_docking_over_3_knots_hits_the_pier_and_fines() -> void:
	assert_true(not CollisionModel.dock_hit(2.5, 90000.0)["hit"])
	var h: Dictionary = CollisionModel.dock_hit(6.0, 90000.0)
	assert_true(h["hit"] and h["fine"] == 50 and h["dock_damage"] > 0.0)


func test_building_hp_table() -> void:
	assert_eq(DestructionData.hp_of("tower"), 1800.0)
	assert_eq(DestructionData.hp_of("gate"), 3000.0)
	assert_eq(DestructionData.hp_of("dock"), 400.0)
	assert_eq(DestructionData.hp_of("warehouse"), 800.0)
	assert_eq(DestructionData.hp_of("crane"), 300.0)
	assert_eq(DestructionData.hp_of("house"), 250.0)
	assert_eq(DestructionData.hp_of("lighthouse"), 1500.0)
	assert_eq(DestructionData.WALL_HP[0] / DestructionData.WALL_SEGMENTS[0], 500.0)
	for lvl in 3:
		var n: int = DestructionData.WALL_SEGMENTS[lvl]
		assert_true(n >= 8 and n <= 20)
		assert_near(DestructionData.segment_hp(lvl + 1) * n, float(DestructionData.WALL_HP[lvl]), 0.01)


func test_crack_stages_and_reputation_costs() -> void:
	assert_eq(DestructionData.crack_stage(1.0), 0)
	assert_eq(DestructionData.crack_stage(0.66), 1)
	assert_eq(DestructionData.crack_stage(0.33), 2)
	assert_eq(DestructionData.crack_stage(0.0), 3)
	assert_eq(DestructionData.rep_cost("house"), -5.0)
	assert_eq(DestructionData.rep_cost("wall"), -2.0)
	assert_eq(DestructionData.rep_cost("tower"), -2.0)


func test_frigate_breaches_a_level_1_wall_in_about_three_broadsides() -> void:
	var frigate: ShipStats = load("res://data/ships/frigate.tres")
	var total: int = 0
	for s in 200:
		total += DestructionData.broadsides_to_breach(1, frigate.guns_per_side, "12pdr", 150.0, 0.8, s + 1)
	var mean: float = float(total) / 200.0
	assert_true(mean >= 2.3 and mean <= 3.7, "mean broadsides to breach %f" % mean)
	# a level 3 wall takes clearly longer
	var t3: int = 0
	for s in 100:
		t3 += DestructionData.broadsides_to_breach(3, frigate.guns_per_side, "12pdr", 150.0, 0.8, s + 1)
	assert_true(float(t3) / 100.0 > mean + 0.8)


func test_chain_shot_barely_scratches_masonry() -> void:
	assert_true(DestructionData.shot_damage("12pdr", 100.0, "chain") < DestructionData.shot_damage("12pdr", 100.0, "round") * 0.1)


func test_debris_never_exceeds_300_bodies() -> void:
	var mgr := DebrisManager.new()
	for i in 450:
		mgr.spawn_plank(Vector3(float(i), 0, 0))
	assert_eq(mgr.count(), 300)
	var stats: ShipStats = load("res://data/ships/frigate.tres")
	var made: Dictionary = mgr.break_up(Vector3.ZERO, stats, {"sugar": 40.0})
	assert_true(made["piece"] >= 3 and made["piece"] <= 6)
	assert_true(made["crate"] >= 1)
	assert_true(mgr.count() <= 300)
	mgr.free()


func test_break_up_floats_30_to_60_percent_of_cargo() -> void:
	var mgr := DebrisManager.new()
	var stats: ShipStats = load("res://data/ships/sloop.tres")
	var made: Dictionary = mgr.break_up(Vector3.ZERO, stats, {"rum": 100.0})
	var floating: float = 0.0
	for n in mgr.pieces:
		var payload: Dictionary = n.get_meta("payload", {})
		if payload.has("cargo"):
			floating += float(payload["cargo"]["rum"]) if payload["cargo"].has("rum") else 0.0
	assert_true(floating >= 25.0 and floating <= 60.0, "floating %f of 100" % floating)
	assert_true(made["barrel"] == 4 and made["plank"] == 8)
	mgr.free()


func test_migration_from_v7_adds_wrecks_and_ruins() -> void:
	var s: Dictionary = SaveGame.new_state()
	s.erase("wrecks")
	s.erase("destroyed")
	s["version"] = 7
	var m: Dictionary = SaveGame.migrate(s)
	assert_eq(m["version"], SaveGame.VERSION)
	assert_true(m["wrecks"] is Array and m["destroyed"] is Dictionary)
