extends TestCase

const ClockScript := preload("res://src/core/game_clock.gd")


func test_full_day_cycle_is_48_minutes() -> void:
	var c: Node = ClockScript.new()
	c.day = 1
	c.hour = 0.0
	c.advance(2880.0)
	assert_eq(c.day, 2)
	assert_near(c.hour, 0.0, 0.001)
	c.free()


func test_one_hour_is_two_minutes() -> void:
	var c: Node = ClockScript.new()
	c.hour = 0.0
	c.advance(120.0)
	assert_near(c.hour, 1.0, 0.001)
	c.free()


func test_paused_clock_does_not_advance() -> void:
	var c: Node = ClockScript.new()
	c.hour = 5.0
	c.paused = true
	c.advance(600.0)
	assert_near(c.hour, 5.0, 0.0001)
	c.free()
