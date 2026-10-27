extends TestCase


func _sloop() -> ShipStats:
	return load("res://data/ships/sloop.tres")


func _hit(ammo: String, local: Vector3, below: bool) -> HitInfo:
	var h := HitInfo.new()
	h.local_position = local
	h.local_normal = Vector3.RIGHT
	h.direction = Vector3.LEFT  # straight into the starboard side
	h.damage = 40.0
	h.ammo_id = ammo
	h.below_waterline = below
	return h


func test_hull_hit_uses_armor_and_waterline_multiplier() -> void:
	var d := DamageModel.new(_sloop(), 1)
	var r: Dictionary = d.apply_hit(_hit("round", Vector3(2.5, -0.5, 0.0), true))
	assert_near(r["hull"], 40.0 * 1.5 * 100.0 / 110.0, 0.01)
	assert_true(r["leak"] > 0.0)


func test_hundred_hits_reduce_section_by_formula() -> void:
	var d := DamageModel.new(_sloop(), 2)
	var section: int = d.section_for(Vector3(2.5, -0.5, 0.0))
	var before: float = d.section_hp[section]
	var applied: float = 0.0
	for i in 100:
		var r: Dictionary = d.apply_hit(_hit("round", Vector3(2.5, -0.5, 0.0), true))
		applied += r["hull"]
	var lost: float = before - d.section_hp[section]
	assert_near(lost, minf(applied, before), 0.01 * before + 0.01)


func test_grazing_shot_ricochets() -> void:
	var d := DamageModel.new(_sloop(), 3)
	var h: HitInfo = _hit("round", Vector3(2.5, -0.5, 0.0), true)
	h.direction = Vector3(-0.1, 0, -1.0).normalized()  # almost parallel to the hull
	var r: Dictionary = d.apply_hit(h)
	assert_true(r["ricochet"])
	assert_near(r["hull"], 40.0 * 1.5 * 100.0 / 110.0 * 0.2, 0.01)


func test_chain_shot_sail_damage_is_eight_times_round() -> void:
	var a := DamageModel.new(_sloop(), 4)
	var b := DamageModel.new(_sloop(), 4)
	var ra: Dictionary = {}
	var rb: Dictionary = {}
	for i in 400:
		var x: Dictionary = a.apply_hit(_hit("chain", Vector3(0, 2.5, 0), false))
		if x["rigging"]:
			ra = x
			break
	for i in 400:
		var y: Dictionary = b.apply_hit(_hit("round", Vector3(0, 2.5, 0), false))
		if y["rigging"]:
			rb = y
			break
	assert_true(not ra.is_empty() and not rb.is_empty(), "rigging hits happened")
	assert_near(ra["sail"] / rb["sail"], 8.0, 0.01)


func test_mast_falls_at_zero_hp() -> void:
	var d := DamageModel.new(_sloop(), 5)
	var fell: Array = [false]
	d.mast_fell.connect(func(_i: int) -> void: fell[0] = true)
	for i in 2000:
		d.apply_hit(_hit("chain", Vector3(0, 2.5, 0), false))
		if fell[0]:
			break
	assert_true(fell[0], "mast fell")
	assert_true(d.mast_down[0])
	assert_near(d.sail_health(), 0.0, 0.001)


func test_ten_leaks_sink_a_sloop_in_predicted_time() -> void:
	var d := DamageModel.new(_sloop(), 6)
	for i in 10:
		d.leak_rate[i % d.section_count] += DamageModel.LEAK_BASE_T_PER_S
	var predicted: float = d.displacement_t() * DamageModel.FLOOD_CAPACITY_SHARE / (10.0 * DamageModel.LEAK_BASE_T_PER_S)
	var t: float = 0.0
	while not d.sunk and t < 1000.0:
		d.tick(0.1, 0.0)
		t += 0.1
	assert_true(d.sunk)
	assert_near(t, predicted, predicted * 0.1, "sink time")


func test_bailing_can_outpace_a_small_leak() -> void:
	var d := DamageModel.new(_sloop(), 7)
	d.leak_rate[0] = 0.04
	for i in 6000:
		d.tick(0.1, 20.0)  # 20 repair crew bail 0.25 t/s
	assert_true(d.water_total() < 1.0)
	assert_true(not d.sunk)


func test_fire_is_reproducible_with_same_seed() -> void:
	var a := DamageModel.new(load("res://data/ships/frigate.tres"), 99)
	var b := DamageModel.new(load("res://data/ships/frigate.tres"), 99)
	a.ignite(3)
	b.ignite(3)
	for i in 600:
		a.tick(0.1, 0.0)
		b.tick(0.1, 0.0)
	assert_eq(a.fire_level, b.fire_level)
	assert_true(a.fires_burning() >= 1)
	assert_true(a.hull_fraction() < 1.0)


func test_rain_slows_spread() -> void:
	var dry: int = 0
	var wet: int = 0
	for seed_value in range(1, 41):
		var a := DamageModel.new(load("res://data/ships/frigate.tres"), seed_value)
		var b := DamageModel.new(load("res://data/ships/frigate.tres"), seed_value)
		b.rain = true
		a.ignite(3)
		b.ignite(3)
		for i in 300:
			a.tick(0.1, 0.0)
			b.tick(0.1, 0.0)
		dry += a.fires_burning()
		wet += b.fires_burning()
	assert_true(wet < dry, "rain: %d vs dry: %d" % [wet, dry])


func test_crew_firefighting_extinguishes() -> void:
	var d := DamageModel.new(_sloop(), 8)
	d.ignite(1)
	for i in 1200:
		d.tick(0.1, 12.0)
	assert_eq(d.fires_burning(), 0)


func test_magazine_hit_is_rare_but_possible() -> void:
	var d := DamageModel.new(_sloop(), 9)
	var boom: Array = [false]
	d.magazine_exploded.connect(func() -> void: boom[0] = true)
	for i in 20000:
		d.apply_hit(_hit("round", Vector3(2.5, -0.5, 0.0), true))
		if boom[0] or d.sunk:
			break
	assert_true(boom[0] or d.sunk)


func test_understaffed_crew_slows_reload() -> void:
	var c := CrewState.new(_sloop())
	c.count = c.crew_min
	assert_near(c.understaffed_multiplier(), 1.0, 0.001)
	c.count = c.crew_min / 2
	assert_near(c.understaffed_multiplier(), 2.0, 0.001)
	c.count = 1
	assert_near(c.understaffed_multiplier(), 3.0, 0.001, "capped at 3x")
