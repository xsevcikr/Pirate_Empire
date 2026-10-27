extends TestCase


func test_all_24_islands_named_with_biome_and_unique_names() -> void:
	var g := WorldGen.new()
	assert_eq(g.islands.size(), 24)
	var seen: Dictionary = {}
	for isl in g.islands:
		assert_true(isl["name"] != "" and not seen.has(isl["name"]), "name %s" % isl["name"])
		seen[isl["name"]] = true
		assert_true(IslandData.BIOMES.has(isl["biome"]), "biome of " + isl["name"])
		assert_true(WorldMap.REGIONS[isl["region"]]["rect"].has_point(isl["pos"]) or isl["region"] == "haven_waters", "inside region")
	assert_eq(g.islands[0]["name"], "Haven Rock")
	assert_eq(g.islands[0]["city"], "Blackwater Town")


func test_four_islands_per_region() -> void:
	var g := WorldGen.new()
	var per: Dictionary = {}
	for isl in g.islands:
		per[isl["region"]] = int(per.get(isl["region"], 0)) + 1
	for r in WorldMap.REGIONS:
		assert_eq(per[r], 4, r)


func test_every_city_is_a_port_with_economy_and_faction_of_its_region() -> void:
	var g := WorldGen.new()
	assert_eq(PortData.PORTS.size(), 16)
	for idx in g.city_islands():
		var isl: Dictionary = g.islands[idx]
		var id: String = IslandData.port_id_of(isl["city"])
		assert_true(PortData.PORTS.has(id), id)
		var p: Dictionary = PortData.PORTS[id]
		assert_eq(p["faction"], WorldMap.REGIONS[isl["region"]]["faction"], id)
		assert_eq(p["name"], isl["city"])
		assert_true(not g.is_land(p["dock"]), id + " dock in water")
	assert_eq(PortData.PORTS["blackwater"]["dock"].round(), Vector2(0, 360))


func test_capitals_have_banks_and_pirate_ports_black_markets() -> void:
	for id in PortData.PORTS:
		var p: Dictionary = PortData.PORTS[id]
		if p["tier"] == "capital":
			assert_true(Finance.has_bank(id), id)
		if p["faction"] == "pirate":
			assert_true(p.get("black_market", false), id)
			assert_true(not p["lawful"])


func test_every_good_is_made_and_wanted_somewhere() -> void:
	for g in Goods.ids():
		var made: bool = false
		var wanted: bool = false
		for id in PortData.PORTS:
			made = made or PortData.PORTS[id]["producer"].has(g)
			wanted = wanted or PortData.PORTS[id]["consumer"].has(g)
		assert_true(made or g in ["gems", "contraband"], "nobody makes " + g)
		assert_true(wanted or g in ["gems", "contraband"], "nobody wants " + g)


func test_port_near_finds_dock_zone() -> void:
	var d: Vector2 = PortData.PORTS["albion"]["dock"]
	assert_eq(PortData.port_near(d + Vector2(30, 0)), "albion")
	assert_eq(PortData.port_near(d + Vector2(400, 0)), "")


func test_currents_between_half_and_two_knots() -> void:
	for s in OceanCurrent.STREAMS:
		assert_true(s["kn"] >= 0.5 and s["kn"] <= 2.0, s["id"])
	var mid: Vector2 = (OceanCurrent.STREAMS[0]["from"] as Vector2).lerp(OceanCurrent.STREAMS[0]["to"], 0.5)
	var v: Vector2 = OceanCurrent.velocity_at(mid, 0.0)
	assert_true(v.y > 0.4 * OceanCurrent.KN_TO_MS, "south-flowing stream pushes south")
	assert_near(OceanCurrent.speed_kn(Vector2(7000, 0), 0.0), 0.0, 0.001)  # open water: no current
	for h in 25:
		assert_true(OceanCurrent.speed_kn(mid, float(h)) <= OceanCurrent.MAX_KN + 0.001)


func test_tide_has_a_twelve_hour_cycle() -> void:
	assert_near(OceanCurrent.tide_m(0.0), 0.0, 0.001)
	assert_near(OceanCurrent.tide_m(OceanCurrent.TIDE_PERIOD_H / 4.0), OceanCurrent.TIDE_RANGE_M, 0.001)
	assert_true(OceanCurrent.tide_rising(1.0) and not OceanCurrent.tide_rising(OceanCurrent.TIDE_PERIOD_H * 0.75))
	assert_true(OceanCurrent.tide_factor(OceanCurrent.TIDE_PERIOD_H / 4.0) > OceanCurrent.tide_factor(OceanCurrent.TIDE_PERIOD_H * 0.75))


func test_chart_mapping_round_trip_and_eta() -> void:
	var rect := Rect2(Vector2(100, 50), Vector2(800, 800))
	var p := Vector2(-1234.0, 4321.0)
	assert_near(Chart.to_world(Chart.to_screen(p, rect), rect).distance_to(p), 0.0, 0.01)
	# 12 km at 70% of 14 kn
	assert_near(Chart.eta_hours(12000.0, 14.0), 12000.0 / (14.0 * 0.7 * 0.5144) / 3600.0, 0.0001)
	assert_eq(Chart.eta_text(1.5), "1 h 30 min")


func test_route_goes_around_an_island() -> void:
	var chart := Chart.new()
	var isl: Dictionary = chart.gen.islands[1]
	var a: Vector2 = isl["pos"] + Vector2(-(isl["radius"] + 400.0), 0)
	var b: Vector2 = isl["pos"] + Vector2(isl["radius"] + 400.0, 0)
	var r: PackedVector2Array = chart.route(a, b)
	assert_true(r.size() >= 1)
	var at: Vector2 = a
	for w in r:
		assert_true(chart.line_clear(at, w), "leg stays off the islands")
		at = w
	assert_true(Chart.length_m(a, r) >= a.distance_to(b))


func test_migration_from_v6_adds_chart_state() -> void:
	var s: Dictionary = SaveGame.new_state()
	s.erase("streams_known")
	s.erase("course")
	s["version"] = 6
	var m: Dictionary = SaveGame.migrate(s)
	assert_eq(m["version"], 7)
	assert_true(m["streams_known"] is Array and m["course"] is Array)


func test_island_biomes_change_the_look() -> void:
	var ice: Dictionary = IslandData.biome("ice")
	var trop: Dictionary = IslandData.biome("tropical")
	assert_true(not ice["palms"] and trop["palms"])
	assert_true((ice["sand"] as Color).v > (IslandData.biome("volcanic")["sand"] as Color).v)
