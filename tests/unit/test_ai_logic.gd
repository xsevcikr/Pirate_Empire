extends TestCase

func _ctx(over: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"hull_frac": 1.0, "crew_frac": 1.0, "hostile_seen": false, "hostile_dist": 2000.0,
		"is_merchant": false, "ratio": 1.0, "personality": "disciplined", "lost_s": 0.0}
	c.merge(over, true)
	return c


func test_strength_scales_with_hull_and_crew() -> void:
	var full: float = AiLogic.strength(1.0, 6, 10.0, 1.0, 0.0)
	var half: float = AiLogic.strength(0.5, 6, 10.0, 1.0, 0.0)
	assert_true(half < full)
	assert_near(half, full * 0.5, 0.001)


func test_engage_when_hostile_seen_and_strong() -> void:
	assert_eq(AiLogic.next_state(AiLogic.State.PATROL, _ctx({"hostile_seen": true, "hostile_dist": 400.0})), AiLogic.State.ENGAGE)


func test_flee_when_outmatched() -> void:
	assert_eq(AiLogic.next_state(AiLogic.State.ENGAGE, _ctx({"hostile_seen": true, "ratio": 0.1})), AiLogic.State.FLEE)


func test_surrender_when_broken() -> void:
	assert_eq(AiLogic.next_state(AiLogic.State.FLEE, _ctx({"hull_frac": 0.05, "crew_frac": 0.2})), AiLogic.State.SURRENDER)
	assert_eq(AiLogic.next_state(AiLogic.State.SURRENDER, _ctx()), AiLogic.State.SURRENDER)


func test_merchant_flees_then_trades() -> void:
	assert_eq(AiLogic.next_state(AiLogic.State.TRADE, _ctx({"is_merchant": true, "hostile_seen": true, "hostile_dist": 500.0})), AiLogic.State.FLEE)
	assert_eq(AiLogic.next_state(AiLogic.State.TRADE, _ctx({"is_merchant": true})), AiLogic.State.TRADE)


func test_lead_point_ahead_of_moving_target() -> void:
	var p: Vector2 = AiLogic.lead_point(Vector2.ZERO, Vector2(100, 0), Vector2(0, 10), 100.0)
	assert_near(p.y, 10.0, 0.001)


func test_should_fire_rules() -> void:
	assert_true(AiLogic.should_fire(1.0, 100.0, 300.0, 6, 6))
	assert_true(not AiLogic.should_fire(20.0, 100.0, 300.0, 6, 6))
	assert_true(not AiLogic.should_fire(0.0, 500.0, 300.0, 6, 6))
	assert_true(not AiLogic.should_fire(0.0, 100.0, 300.0, 1, 6))


func test_steer_avoids_no_go_zone() -> void:
	var wind_from := Vector2(1, 0)
	var d: Vector2 = AiLogic.steer_direction(Vector2(1, 0), wind_from, 40.0, [])
	assert_true(rad_to_deg(acos(clampf(d.dot(wind_from), -1.0, 1.0))) >= 40.0)


func test_steer_avoids_close_ship() -> void:
	var d: Vector2 = AiLogic.steer_direction(Vector2(1, 0), Vector2(-1, 0), 0.0, [{"rel": Vector2(30, 0), "dist": 30.0}])
	assert_true(absf(d.y) > 0.1)


func test_rudder_sign() -> void:
	assert_true(AiLogic.rudder_for(Vector2(1, 0), Vector2(0, 1)) != 0.0)
	assert_eq(AiLogic.rudder_for(Vector2(1, 0), Vector2(1, 0)), 0.0)
