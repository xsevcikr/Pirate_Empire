extends TestCase


func test_angle_into_wind_is_zero() -> void:
	var w := WindModel.new()
	w.direction = Vector2(0, 1)  # blows toward +z, so it comes from -z
	assert_near(w.angle_off_wind_deg(Vector2(0, -1)), 0.0, 0.01)


func test_angle_running_is_180() -> void:
	var w := WindModel.new()
	w.direction = Vector2(0, 1)
	assert_near(w.angle_off_wind_deg(Vector2(0, 1)), 180.0, 0.01)


func test_beam_wind_is_90() -> void:
	var w := WindModel.new()
	w.direction = Vector2(-1, 0)
	assert_near(w.angle_off_wind_deg(Vector2(0, -1)), 90.0, 0.01)


func test_sea_state_from_wind_matches_table() -> void:
	var w := WindModel.new()
	w.speed_kn = 13.5
	assert_near(w.sea_state(), 4.0, 0.01)
	w.speed_kn = 24.5
	assert_near(w.sea_state(), 6.0, 0.01)
	w.speed_kn = 60.0
	assert_near(w.sea_state(), 9.0, 0.01)


func test_gusts_stay_within_20_percent() -> void:
	var w := WindModel.new()
	for i in 2000:
		w.update(0.1)
		assert_true(absf(w.gust) <= 0.2001)
