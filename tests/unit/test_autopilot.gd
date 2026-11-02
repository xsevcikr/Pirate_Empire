extends TestCase
## Auto drive logic: holding a heading, following a chart mark, steering round islands and ships, arriving.


func _pilot(islands: Array = []) -> Autopilot:
	return Autopilot.new(islands)


func test_engage_without_mark_holds_heading() -> void:
	var p := _pilot()
	p.engage(Vector2.ZERO, Vector2(1, 0))
	assert_eq(p.mode, Autopilot.Mode.HOLD)
	assert_true(p.is_on())
	assert_near(p.desired_dir(Vector2(500, 300)).x, 1.0, 0.001, "holds the heading it was given")


func test_engage_with_mark_follows_course() -> void:
	var p := _pilot()
	p.engage(Vector2.ZERO, Vector2(0, -1), [800.0, 0.0])
	assert_eq(p.mode, Autopilot.Mode.COURSE)
	assert_near(p.distance_left(Vector2.ZERO), 800.0, 0.5)
	assert_near(p.desired_dir(Vector2.ZERO).x, 1.0, 0.001, "points at the mark")


func test_disengage() -> void:
	var p := _pilot()
	p.engage(Vector2.ZERO, Vector2(0, -1))
	p.disengage()
	assert_true(not p.is_on())
	assert_eq(p.steer(Vector2.ZERO, Vector2(0, -1), 5.0)["rudder"], 0.0, "off: hands off the wheel")


func test_island_danger_only_on_the_line_ahead() -> void:
	var p := _pilot([{"pos": Vector2(0, -300), "radius": 100.0}])
	assert_true(p.island_danger(Vector2.ZERO, Vector2(0, -1), 400.0) > 0.25, "island dead ahead is dangerous")
	assert_eq(p.island_danger(Vector2.ZERO, Vector2(0, 1), 400.0), 0.0, "island astern is not")
	assert_eq(p.island_danger(Vector2.ZERO, Vector2(1, 0), 400.0), 0.0, "island abeam is not on the line")
	assert_eq(p.island_danger(Vector2.ZERO, Vector2(0, -1), 100.0), 0.0, "beyond the look-ahead is ignored")


func test_steers_round_an_island_ahead() -> void:
	var p := _pilot([{"pos": Vector2(0, -250), "radius": 100.0}])
	p.engage(Vector2.ZERO, Vector2(0, -1))
	var res: Dictionary = p.steer(Vector2.ZERO, Vector2(0, -1), 7.0)
	assert_true(absf(p.chosen.x) > 0.5, "turns well off the island's line (chose %s)" % p.chosen)
	assert_true(absf(float(res["rudder"])) > 0.5, "with real rudder")
	assert_true(not res["blocked"])


func test_open_water_keeps_straight() -> void:
	var p := _pilot([{"pos": Vector2(2000, 2000), "radius": 100.0}])
	p.engage(Vector2.ZERO, Vector2(0, -1))
	var res: Dictionary = p.steer(Vector2.ZERO, Vector2(0, -1), 7.0)
	assert_near(float(res["rudder"]), 0.0, 0.05)
	assert_eq(res["sail"], -1, "leaves the sails alone")


func test_gives_way_to_a_ship_ahead() -> void:
	var p := _pilot()
	p.engage(Vector2.ZERO, Vector2(0, -1))
	p.steer(Vector2.ZERO, Vector2(0, -1), 6.0, [Vector2(0, -50)])
	assert_true(p.chosen.dot(Vector2(0, -1)) < 0.9, "does not sail straight into a ship")


func test_slows_then_arrives() -> void:
	var p := _pilot()
	p.engage(Vector2.ZERO, Vector2(0, -1), [0.0, -1000.0])
	assert_eq(p.steer(Vector2(0, -800), Vector2(0, -1), 7.0)["sail"], 1, "half sail near the mark")
	var res: Dictionary = p.steer(Vector2(0, -950), Vector2(0, -1), 3.0)
	assert_true(res["arrived"])
	assert_eq(res["sail"], 0, "sails in on arrival")


func test_route_waypoints_advance() -> void:
	var p := _pilot()
	p.engage(Vector2.ZERO, Vector2(0, -1))
	p.mode = Autopilot.Mode.COURSE
	p.route = PackedVector2Array([Vector2(0, -500), Vector2(500, -500)])
	p.leg = 0
	assert_near(p.desired_dir(Vector2(0, -200)).y, -1.0, 0.01, "first leg north")
	assert_near(p.desired_dir(Vector2(0, -460)).x, 1.0, 0.01, "next leg once the first waypoint is reached")


func test_real_chart_route_avoids_islands() -> void:
	var gen: WorldGen = PortData.gen()
	var p := Autopilot.new(gen.islands)
	var isl: Dictionary = gen.islands[1]
	var c: Vector2 = isl["pos"]
	var r: float = float(isl["radius"])
	var a: Vector2 = c + Vector2(-(r + 400.0), 0)
	var b: Vector2 = c + Vector2(r + 400.0, 0)
	p.engage(a, Vector2(1, 0), [b.x, b.y])
	assert_true(p.route.size() >= 1)
	var at: Vector2 = a
	for w in p.route:
		for k in 21:
			var q: Vector2 = at.lerp(w, float(k) / 20.0)
			assert_true(q.distance_to(c) > r, "route leg stays off the island")
		at = w


func test_compass_words() -> void:
	assert_eq(Autopilot.compass_key(Vector2(0, -1)), "compass.n")
	assert_eq(Autopilot.compass_key(Vector2(1, 0)), "compass.e")
	assert_eq(Autopilot.compass_key(Vector2(0, 1)), "compass.s")
	assert_eq(Autopilot.compass_key(Vector2(-1, 0)), "compass.w")
	for k in ["compass.n", "compass.e", "compass.s", "compass.w", "autodrive.title", "autodrive.keys"]:
		assert_true(Loc.t(k) != k, "string %s exists" % k)
