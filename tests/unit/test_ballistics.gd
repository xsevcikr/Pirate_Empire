extends TestCase


func test_six_pounder_range_matches_analytic_without_drag() -> void:
	var g: float = GunData.shot_gravity("6pdr")
	var v: float = 330.0
	var theta: float = deg_to_rad(4.0)
	var vel := Vector3(cos(theta), sin(theta), 0.0) * v
	var land: Vector3 = Ballistics.landing_point(Vector3.ZERO, vel, g, 0.0, 0.0)
	var analytic: float = v * v * sin(2.0 * theta) / g
	assert_near(land.x, analytic, analytic * 0.05, "range within 5%%")


func test_max_range_at_twelve_degrees() -> void:
	for id: String in GunData.GUNS:
		var g: float = GunData.shot_gravity(id)
		var v: float = GunData.GUNS[id]["velocity"]
		var theta: float = deg_to_rad(12.0)
		var land: Vector3 = Ballistics.landing_point(Vector3.ZERO, Vector3(cos(theta), sin(theta), 0) * v, g, 0.0, 0.0)
		assert_near(land.x, GunData.GUNS[id]["max"], GunData.GUNS[id]["max"] * 0.03, id + " max range")


func test_drag_shortens_range() -> void:
	var g: float = GunData.shot_gravity("12pdr")
	var vel := Vector3(0.97, 0.2, 0.0) * 320.0
	var a: Vector3 = Ballistics.landing_point(Vector3.ZERO, vel, g, 0.0, 0.0)
	var b: Vector3 = Ballistics.landing_point(Vector3.ZERO, vel, g, 0.0)
	assert_true(b.x < a.x)
