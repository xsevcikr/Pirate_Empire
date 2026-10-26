extends TestCase


func test_in_irons_has_no_drive() -> void:
	assert_near(SailModel.speed_factor(0.0, false), 0.0, 0.001)
	assert_near(SailModel.speed_factor(25.0, false), 0.0, 0.001)
	assert_near(SailModel.speed_factor(30.0, true), 0.0, 0.001)


func test_beam_reach_is_full_speed() -> void:
	assert_near(SailModel.speed_factor(90.0, false), 1.0, 0.001)
	assert_near(SailModel.speed_factor(100.0, true), 1.0, 0.001)


func test_square_rig_peaks_on_broad_reach() -> void:
	assert_near(SailModel.speed_factor(130.0, true), 1.05, 0.001)
	assert_true(SailModel.speed_factor(130.0, true) > SailModel.speed_factor(130.0, false))


func test_running_is_slower_than_beam_reach() -> void:
	assert_true(SailModel.speed_factor(180.0, false) < 1.0)


func test_curve_is_monotonic_up_to_beam_reach() -> void:
	var prev: float = 0.0
	for a in range(0, 91, 3):
		var f: float = SailModel.speed_factor(float(a), false)
		assert_true(f >= prev - 0.0001, "monotonic at %d" % a)
		prev = f


func test_point_of_sail_names() -> void:
	assert_eq(SailModel.point_of_sail(10.0, false), "In irons")
	assert_eq(SailModel.point_of_sail(90.0, false), "Beam reach")
	assert_eq(SailModel.point_of_sail(170.0, false), "Running")
