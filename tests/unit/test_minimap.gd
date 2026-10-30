extends TestCase
## The corner minimap's maths (MinimapMath): north-up mapping around the ship, rim pinning and the home marker.


func test_north_up_mapping() -> void:
	var c := Vector2(1000, 1000)
	assert_eq(MinimapMath.to_map(c, c, 3000.0, 110.0), Vector2.ZERO)
	var east: Vector2 = MinimapMath.to_map(c + Vector2(3000, 0), c, 3000.0, 110.0)
	assert_near(east.x, 110.0, 0.001)
	var north: Vector2 = MinimapMath.to_map(c + Vector2(0, -1500), c, 3000.0, 110.0)
	assert_near(north.y, -55.0, 0.001, "north (-z) is up")


func test_far_markers_pin_to_rim_keeping_bearing() -> void:
	var near := Vector2(20, -30)
	assert_eq(MinimapMath.pin_to_rim(near, 110.0, 8.0), near)
	var far := Vector2(500, 500)
	var p: Vector2 = MinimapMath.pin_to_rim(far, 110.0, 8.0)
	assert_near(p.length(), 102.0, 0.001)
	assert_near(p.angle(), far.angle(), 0.0001)


func test_touches_includes_islands_overlapping_the_rim() -> void:
	assert_true(MinimapMath.touches(Vector2(120, 0), 15.0, 110.0))
	assert_true(not MinimapMath.touches(Vector2(130, 0), 15.0, 110.0))


func test_ranges_cycle() -> void:
	var i: int = 0
	for k in MinimapMath.RANGES_M.size():
		i = MinimapMath.next_range(i)
	assert_eq(i, 0)


func test_home_is_the_lagoon_harbour_on_skull_atoll() -> void:
	var g: WorldGen = PortData.gen()
	var isl: Dictionary = g.islands[g.index_of(LagoonData.ISLAND)]
	var home: Vector2 = MinimapMath.home_pos()
	assert_true(home.distance_to(isl["pos"]) < float(isl["radius"]) + 300.0, "home sits at Skull Atoll")


func test_bearing_text() -> void:
	assert_eq(MinimapMath.bearing_text(Vector2.ZERO, Vector2(0, -2000)), "2.0 km N")
	assert_eq(MinimapMath.bearing_text(Vector2.ZERO, Vector2(1500, 1500)), "2.1 km SE")
	assert_eq(MinimapMath.bearing_text(Vector2.ZERO, Vector2(-3000, 0)), "3.0 km W")


func test_ship_colours() -> void:
	assert_true(MinimapMath.ship_colour("navy") != MinimapMath.ship_colour("pirate"))
	assert_eq(MinimapMath.ship_colour("some_rival_crew"), MinimapMath.OTHER_SHIP)
