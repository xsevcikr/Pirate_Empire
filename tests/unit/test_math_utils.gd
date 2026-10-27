extends TestCase


func test_knots_round_trip() -> void:
	assert_near(MathUtils.ms_to_knots(MathUtils.knots_to_ms(14.0)), 14.0, 0.0001)


func test_knot_value() -> void:
	assert_near(MathUtils.knots_to_ms(10.0), 5.14, 0.001)
