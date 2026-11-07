extends TestCase
## Sail levels. There are no wind mechanics, so the level alone sets the speed.


func test_levels_rise_from_furled_to_full() -> void:
	assert_eq(SailModel.LEVELS.size(), 4)
	assert_near(SailModel.LEVELS[0], 0.0, 0.001)
	assert_near(SailModel.LEVELS[3], 1.0, 0.001)
	for i in range(1, 4):
		assert_true(SailModel.LEVELS[i] > SailModel.LEVELS[i - 1])
	assert_eq(SailModel.LEVEL_NAMES.size(), 4)
