extends TestCase


func test_regions_and_chunks() -> void:
	assert_eq(WorldMap.region_at(Vector2(0, 0)), "haven_waters")
	assert_eq(WorldMap.region_at(Vector2(-6000, 6000)), "albion_shallows")
	assert_eq(WorldMap.region_at(Vector2(6000, 6000)), "iron_marches")
	assert_eq(WorldMap.region_at(Vector2(0, -6000)), "dead_reach")
	assert_eq(WorldMap.chunk_of(Vector2(-8000, -8000)), Vector2i(0, 0))
	assert_eq(WorldMap.chunk_of(Vector2(8000, 8000)), Vector2i(15, 15))
	assert_eq(WorldMap.chunk_of(Vector2(0, 0)), Vector2i(8, 8))


func test_streamer_caps_loaded_chunks_across_map() -> void:
	var s := ChunkStreamer.new()
	var worst_ms: float = 0.0
	var p := Vector2(-8000, -8000)
	while p.x < 8000.0:
		var t0: int = Time.get_ticks_usec()
		s.update(p)
		worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		p += Vector2(7.2, 7.2)  # about 14 knots per second
	assert_true(s.peak_loaded <= 25, "peak %d" % s.peak_loaded)
	assert_true(worst_ms < 50.0, "slowest update %.2f ms" % worst_ms)
	assert_true(s.loads > 16, "streamed %d loads" % s.loads)
	assert_eq(s.loads - s.unloads, s.loaded.size())


func test_discovery_round_trip() -> void:
	var d := Discovery.new()
	d.reveal_around(Vector2(0, 0))
	d.reveal(Vector2i(15, 15))
	assert_true(d.is_revealed(Vector2i(8, 8)))
	assert_true(d.is_revealed(Vector2i(15, 15)))
	assert_true(not d.is_revealed(Vector2i(0, 0)))
	var copy: Discovery = Discovery.from_bytes(d.to_bytes())
	assert_eq(copy.count(), d.count())
	assert_eq(copy.bits, d.bits)


func test_weather_visits_all_states_in_30_days() -> void:
	var w := WeatherChain.new(5)
	var tendency: Dictionary = {"clear": 0.3, "overcast": 0.2, "rain": 0.2, "storm": 0.15, "fog": 0.15}
	for i in int(30 * 24 / WeatherChain.STEP_HOURS):
		w.step(tendency)
	for s in WeatherChain.STATES:
		assert_true(w.visited.has(s), "never visited " + s)


func test_region_weather_tendency_respected() -> void:
	var w := WeatherChain.new(9)
	var storms: int = 0
	for i in 2000:
		if w.step(WorldMap.REGIONS["dead_reach"]["weather"]) in ["storm", "fog"]:
			storms += 1
	assert_true(storms > 1600, "dead reach storm/fog steps %d / 2000" % storms)


func test_layout_counts() -> void:
	var g := WorldGen.new()
	assert_eq(g.islands.size(), 24)
	for type in WorldGen.POI_COUNTS.keys():
		assert_eq(g.count_of(type), WorldGen.POI_COUNTS[type], type)
	for i in g.islands:
		assert_true(WorldMap.in_bounds(i["pos"]))


func test_layout_deterministic() -> void:
	var a := WorldGen.new()
	var b := WorldGen.new()
	assert_eq(a.pois.size(), b.pois.size())
	assert_eq(a.pois[5]["pos"], b.pois[5]["pos"])


func test_every_poi_reachable_from_haven_rock() -> void:
	var g := WorldGen.new()
	var nav := SeaNav.new(g)
	var start: Vector2 = g.pois[0]["pos"]
	assert_true(not g.is_land(start))
	for p in g.pois:
		if p["type"] == "whirlpool":
			continue
		var path: PackedVector2Array = nav.find_path(start, p["pos"])
		assert_true(path.size() > 0, "%s at %s unreachable" % [p["type"], p["pos"]])


func test_encounter_table_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var counts := {}
	for i in 6600:
		var k: String = Encounters.pick(rng)
		counts[k] = counts.get(k, 0) + 1
	assert_true(counts["merchant_convoy"] > counts["navy_patrol"])
	assert_true(counts["navy_patrol"] > counts["rival_pirate"])
	assert_true(Encounters.can_spawn(11) and not Encounters.can_spawn(12))
	assert_near(Encounters.sector_target(true), 0.25, 0.0001)
