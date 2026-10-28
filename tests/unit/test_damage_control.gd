extends TestCase
## Crash damage and damage control: where a hull is struck, scraping, breaches, and the crew patching holes,
## pumping, rigging a jury mast and mending the hull from the ship's timber, canvas and tools.


func _sloop() -> ShipStats:
	return load("res://data/ships/sloop.tres")


func _supplies(timber: float, canvas: float, tools: float = 0.0) -> Dictionary:
	return {"timber": timber, "canvas": canvas, "tools": tools}


## Runs damage control for `seconds` with `hands` and returns the events.
func _run(dc: DamageControl, seconds: float, hands: float) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var t: float = 0.0
	while t < seconds:
		dc.damage.tick(0.1, hands)
		all.append_array(dc.tick(0.1, hands))
		t += 0.1
	return all


func test_the_stem_takes_a_blow_the_side_caves_in() -> void:
	assert_near(CollisionModel.angle_factor(Vector3(0, 0, -1)), CollisionModel.ANGLE_BOW, 0.001)
	assert_near(CollisionModel.angle_factor(Vector3(0, 0, 1)), CollisionModel.ANGLE_BOW, 0.001)
	assert_near(CollisionModel.angle_factor(Vector3(1, 0, 0)), CollisionModel.ANGLE_BEAM, 0.001)
	assert_near(CollisionModel.angle_factor(Vector3(-1, 0, 0)), CollisionModel.ANGLE_BEAM, 0.001)
	var diag: float = CollisionModel.angle_factor(Vector3(1, 0, -1))
	assert_true(diag > CollisionModel.ANGLE_BOW and diag < CollisionModel.ANGLE_BEAM, "45 degrees sits between, got %f" % diag)
	# a T-bone: the rammer's stem against the victim's side
	var e: float = CollisionModel.impact_energy(90000.0, 90000.0, 4.0)
	var rammer: float = CollisionModel.hull_damage(e, "ship") * CollisionModel.angle_factor(Vector3(0, 0, -1))
	var rammed: float = CollisionModel.hull_damage(e, "ship") * CollisionModel.angle_factor(Vector3(1, 0, 0))
	assert_true(rammed > rammer * 2.0, "the ship struck on the beam takes over twice the damage")


func test_head_on_and_glancing_contacts_split_differently() -> void:
	var head: Dictionary = CollisionModel.split_contact(Vector3(0, 0, -5), Vector3(0, 0, -1))
	assert_near(head["closing"], 5.0, 0.001)
	assert_near(head["slide"], 0.0, 0.001)
	var glance: Dictionary = CollisionModel.split_contact(Vector3(4, 0, -1), Vector3(0, 0, -1))
	assert_near(glance["closing"], 1.0, 0.001)
	assert_near(glance["slide"], 4.0, 0.001)
	assert_eq(CollisionModel.scrape_damage(90000.0, 90000.0, 0.5), 0.0)
	var slow: float = CollisionModel.scrape_damage(90000.0, 90000.0, 2.0)
	var fast: float = CollisionModel.scrape_damage(90000.0, 90000.0, 4.0)
	assert_near(fast, slow * 4.0, 0.01)  # energy goes with the square of the slide
	assert_true(fast < CollisionModel.hull_damage(CollisionModel.impact_energy(90000.0, 90000.0, 4.0), "ship"), "a scrape hurts less than a ram")


func test_breach_sizes_follow_the_share_of_hull() -> void:
	assert_eq(CollisionModel.breach_size(30.0, 1000.0), 0)
	assert_eq(CollisionModel.breach_size(70.0, 1000.0), 1)
	assert_eq(CollisionModel.breach_size(200.0, 1000.0), 2)
	assert_eq(CollisionModel.breach_size(400.0, 1000.0), 3)
	assert_true(CollisionModel.breach_leak(3) > CollisionModel.breach_leak(2) and CollisionModel.breach_leak(2) > CollisionModel.breach_leak(1))


func test_breaches_leak_merge_and_slow_when_worked() -> void:
	var d := DamageModel.new(_sloop(), 3)
	var b: int = d.open_breach(1, Vector3(-2.5, -0.3, 0.0), 1, CollisionModel.breach_leak(1))
	assert_near(d.leak_rate[1], CollisionModel.breach_leak(1), 0.0001)
	var b2: int = d.open_breach(1, Vector3(-2.5, -0.3, 0.8), 1, CollisionModel.breach_leak(1))
	assert_eq(b2, b, "a hit next to an open hole makes it bigger")
	assert_eq(d.breaches.size(), 1)
	assert_eq(int(d.breaches[0]["size"]), 2)
	var full: float = d.leak_rate[1]
	d.set_breach_state(b, "fothered")
	assert_near(d.leak_rate[1], full * 0.25, 0.0001)
	d.set_breach_state(b, "patched")
	assert_near(d.leak_rate[1], 0.0, 0.0001)
	assert_eq(d.open_breach_count(), 0)
	assert_eq(d.worst_breach(), -1)


func test_crew_plank_a_hole_with_timber() -> void:
	var d := DamageModel.new(_sloop(), 3)
	var dc := DamageControl.new(d)
	dc.supplies = _supplies(5.0, 0.0)
	d.open_breach(0, Vector3(0, -0.3, -9.0), 1, CollisionModel.breach_leak(1))
	var need: float = DamageControl.PATCH_WORK[1]
	# 6 hands, most on the hole (auto puts patching ahead of the pumps)
	_run(dc, need / 6.0 * 0.4, 6.0)
	assert_eq(str(d.breaches[0]["state"]), "open", "not done halfway")
	_run(dc, need / 6.0 * 1.6, 6.0)
	assert_eq(str(d.breaches[0]["state"]), "patched")
	assert_near(float(dc.supplies["timber"]), 5.0 - DamageControl.PATCH_TIMBER[1], 0.001)
	assert_near(d.leak_total(), 0.0, 0.0001)


func test_without_timber_the_crew_fother_then_stuff() -> void:
	var d := DamageModel.new(_sloop(), 3)
	var dc := DamageControl.new(d)
	dc.supplies = _supplies(0.0, 1.0)
	d.open_breach(1, Vector3(-2.5, -0.3, 0.0), 2, CollisionModel.breach_leak(2))
	d.open_breach(2, Vector3(2.5, -0.3, 0.0), 2, CollisionModel.breach_leak(2))
	_run(dc, 60.0, 8.0)
	var states: Array[String] = []
	for br in d.breaches:
		states.append(str(br["state"]))
	states.sort()
	assert_eq(states, ["fothered", "stuffed"] as Array[String], "one bolt of canvas for the first, oakum for the second")
	assert_near(float(dc.supplies["canvas"]), 0.0, 0.001)
	assert_true(d.leak_total() < CollisionModel.breach_leak(2) * 2.0 * 0.5, "the leak is well down")
	# timber comes aboard (a floating crate): the carpenters plank both properly
	dc.supplies["timber"] = 10.0
	_run(dc, 120.0, 8.0)
	assert_eq(d.open_breach_count(), 0)


func test_carpenters_and_tools_speed_the_work() -> void:
	var times: Array[float] = []
	for setup in [[0, 0.0], [1, 0.0], [1, 2.0]]:
		var d := DamageModel.new(_sloop(), 3)
		var dc := DamageControl.new(d)
		dc.supplies = _supplies(10.0, 0.0, setup[1])
		dc.carpenters = setup[0]
		d.open_breach(0, Vector3(0, -0.3, -9.0), 3, CollisionModel.breach_leak(3))
		var t: float = 0.0
		while d.open_breach_count() > 0 and t < 300.0:
			dc.tick(0.1, 4.0)
			t += 0.1
		times.append(t)
	assert_true(times[1] < times[0] * 0.55, "a carpenter doubles the speed: %s" % str(times))
	assert_true(times[2] < times[1] * 0.75, "a tool chest adds half again: %s" % str(times))
	assert_eq(DamageControl.new(DamageModel.new(_sloop())).skill_mult(), 1.0)
	var many := DamageControl.new(DamageModel.new(_sloop()))
	many.carpenters = 9
	assert_eq(many.skill_mult(), DamageControl.CARPENTER_MAX)


func test_pumps_win_against_a_small_hole_but_not_a_big_one() -> void:
	for size in [1, 3]:
		var d := DamageModel.new(_sloop(), 3)
		var dc := DamageControl.new(d)
		dc.supplies = _supplies(0.0, 0.0)
		dc.auto = false
		for j in DamageControl.JOBS:
			dc.weights[j] = 0
		dc.weights["pump"] = 5
		d.open_breach(1, Vector3(-2.5, -0.3, 0.0), size, CollisionModel.breach_leak(size))
		_run(dc, 60.0, 12.0)
		if size == 1:
			assert_true(d.water_total() < 0.5, "12 hands keep up with a small hole, water %f" % d.water_total())
		else:
			assert_true(d.water_total() > 5.0, "a gaping hole beats the pumps, water %f" % d.water_total())


func test_a_jury_mast_goes_up_with_timber_and_canvas() -> void:
	var d := DamageModel.new(load("res://data/ships/brigantine.tres"), 3)
	var dc := DamageControl.new(d)
	dc.supplies = _supplies(3.0, 2.0)
	d.apply_impact(1, 10.0, 0.0, true)
	assert_true(d.mast_down.has(true))
	var ev: Array[Dictionary] = _run(dc, DamageControl.RIG_WORK / 6.0 + 1.0, 6.0)
	assert_true(not d.mast_down.has(true), "the jury mast is up")
	var kinds: Array = ev.map(func(e: Dictionary) -> String: return e["kind"])
	assert_true(kinds.has("jury_mast"))
	assert_near(float(dc.supplies["timber"]), 0.0, 0.001)
	assert_near(float(dc.supplies["canvas"]), 0.0, 0.001)
	assert_true(d.sail_health() < 1.0, "a jury mast carries less sail")


func test_the_bosun_fights_fire_first_and_idle_jobs_hand_over() -> void:
	var d := DamageModel.new(_sloop(), 3)
	var dc := DamageControl.new(d)
	dc.supplies = _supplies(5.0, 2.0)
	d.ignite(1)
	d.open_breach(1, Vector3(-2.5, -0.3, 0.0), 1, CollisionModel.breach_leak(1))
	var w: Dictionary = dc.auto_weights()
	assert_true(int(w["fire"]) >= int(w["patch"]) and int(w["patch"]) > int(w.get("hull", 0)))
	var s: Dictionary = dc.split(10.0)
	assert_near(float(s["pump"]), 0.0, 0.001)  # no water yet
	assert_near(float(s["fire"]) + float(s["patch"]) + float(s["hull"]), 10.0, 0.001)
	# manual orders on a job with nothing to do give the men to the rest
	dc.auto = false
	for j in DamageControl.JOBS:
		dc.weights[j] = 0
	dc.weights["rig"] = 5
	dc.weights["patch"] = 1
	s = dc.split(10.0)
	assert_near(float(s["patch"]), 10.0, 0.001)


func test_damage_survives_a_save_and_the_shipyard_clears_it() -> void:
	var d := DamageModel.new(_sloop(), 3)
	d.open_breach(1, Vector3(-2.5, -0.3, 1.0), 2, CollisionModel.breach_leak(2))
	d.open_breach(0, Vector3(0, -0.3, -9.0), 1, CollisionModel.breach_leak(1))
	d.set_breach_state(1, "patched")
	d.water_t[1] = 3.5
	d.apply_impact(1, 1.0, 0.0, true)
	var json: String = JSON.stringify(d.to_save())
	var back := DamageModel.new(_sloop(), 4)
	back.load_save(JSON.parse_string(json))
	assert_eq(back.breaches.size(), 2)
	assert_eq(str(back.breaches[1]["state"]), "patched")
	assert_near((back.breaches[0]["pos"] as Vector3).z, 1.0, 0.001)
	assert_near(back.leak_total(), d.leak_total(), 0.0001)
	assert_near(back.water_t[1], 3.5, 0.001)
	assert_true(back.mast_down[0])
	back.reset_all()
	assert_eq(back.breaches.size(), 0)
	assert_near(back.water_total(), 0.0, 0.001)
	assert_true(not back.mast_down.has(true))
	var st: Dictionary = SaveGame.new_state()
	st["ship_hull"] = 0.5
	st["gold"] = 99999
	assert_true(PortService.repair(st))
	assert_true(bool(st["ship_damage"].get("repaired", false)))


func test_old_saves_gain_canvas_tools_and_ship_damage() -> void:
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 12
	old["supplies"].erase("canvas")
	old["supplies"].erase("tools")
	old.erase("ship_damage")
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(int(m["version"]), 13)
	assert_near(float(m["supplies"]["canvas"]), 0.0, 0.001)
	assert_near(float(m["supplies"]["tools"]), 0.0, 0.001)
	assert_eq(m["ship_damage"], {})
	assert_true(PortData.SUPPLIES.has("canvas") and PortData.SUPPLIES.has("tools"))


func test_section_names_cover_both_hull_layouts() -> void:
	var small := DamageModel.new(_sloop())
	assert_eq(DamageControl.section_key(small, 0), "dmg.sec.bow")
	assert_eq(DamageControl.section_key(small, 2), "dmg.sec.starboard")
	var big := DamageModel.new(load("res://data/ships/frigate.tres"))
	if big.section_count == 8:
		assert_eq(DamageControl.section_key(big, 1), "dmg.sec.fore_port")
		assert_eq(DamageControl.section_key(big, 4), "dmg.sec.mid_starboard")
		assert_eq(DamageControl.section_key(big, 7), "dmg.sec.stern")
	for i in big.section_count:
		assert_true(Loc.t(DamageControl.section_key(big, i)) != DamageControl.section_key(big, i), "section %d has a name" % i)


func test_ai_ships_still_patch_holes_by_the_old_rule() -> void:
	var d := DamageModel.new(_sloop(), 3)
	d.open_breach(1, Vector3(-2.5, -0.3, 0.0), 2, CollisionModel.breach_leak(2))
	for i in 130:
		d.tick(0.1, 6.0)
	assert_eq(d.open_breach_count(), 0, "after 12 s the AI crew plug it")
	assert_near(d.leak_rate[1], 0.0, 0.0001)
