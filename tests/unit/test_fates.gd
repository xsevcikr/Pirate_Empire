extends TestCase


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["ship_class"] = "sloop"
	s["crew"] = 20
	for i in 20:
		s["roster"].append({"name": "Hand", "type": "green", "level": 1, "xp": 0})
	return s


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	return r


func test_prize_crew_needs_surplus_hands() -> void:
	var s: Dictionary = _state()
	assert_eq(FateEffects.prize_crew_available(s), 2)  # (20 - 8) / 6
	s["crew"] = 10
	assert_eq(FateEffects.prize_crew_available(s), 0)


func test_sell_pays_half_the_hull() -> void:
	var s: Dictionary = _state()
	var info: Dictionary = FateEffects.fate_info(s, 2000.0, 10, false)
	var fx: Dictionary = CaptureFate.resolve(CaptureFate.Fate.SELL, info, _rng())
	var applied: Dictionary = FateEffects.apply(s, fx, "sloop", "Prize")
	assert_eq(applied["gold"], 1000)
	assert_eq(s["gold"], 1100)


func test_capture_adds_ship_and_takes_prize_crew() -> void:
	var s: Dictionary = _state()
	var fx: Dictionary = CaptureFate.resolve(CaptureFate.Fate.CAPTURE, FateEffects.fate_info(s, 2000.0, 10, false), _rng())
	var applied: Dictionary = FateEffects.apply(s, fx, "lugger", "Prize")
	assert_true(applied["ship_added"])
	assert_eq(s["fleet"].size(), 1)
	assert_eq(s["crew"], 14)
	assert_eq(s["roster"].size(), 14)


func test_capture_refused_without_hands() -> void:
	var s: Dictionary = _state()
	s["crew"] = 9
	var fx: Dictionary = CaptureFate.resolve(CaptureFate.Fate.CAPTURE, FateEffects.fate_info(s, 2000.0, 10, false), _rng())
	assert_true(not fx["ok"])


func test_press_gang_recruits_a_quarter_and_costs_morale() -> void:
	var s: Dictionary = _state()
	s["crew"] = 12
	s["roster"].resize(12)
	s["morale"] = 70.0
	var fx: Dictionary = CaptureFate.resolve(CaptureFate.Fate.PRESS_CREW, FateEffects.fate_info(s, 2000.0, 12, false), _rng())
	var applied: Dictionary = FateEffects.apply(s, fx, "sloop", "Prize")
	assert_eq(applied["recruits"], 3)
	assert_eq(s["crew"], 15)
	assert_near(s["morale"], 60.0, 0.001)


func test_strip_and_sink_raises_fame() -> void:
	var s: Dictionary = _state()
	var fx: Dictionary = CaptureFate.resolve(CaptureFate.Fate.STRIP_AND_SINK, FateEffects.fate_info(s, 2000.0, 10, false), _rng())
	FateEffects.apply(s, fx, "sloop", "Prize")
	assert_eq(s["fame"], 5)
	assert_eq(s["gold"], 100 + 150)  # 30% of the 25% equipment value


func test_release_of_kindly_crew_lifts_morale() -> void:
	var s: Dictionary = _state()
	s["morale"] = 60.0
	var fx: Dictionary = CaptureFate.resolve(CaptureFate.Fate.RELEASE, FateEffects.fate_info(s, 2000.0, 10, true), _rng())
	FateEffects.apply(s, fx, "sloop", "Prize")
	assert_near(s["morale"], 70.0, 0.001)


func test_enemy_roster_for_each_faction() -> void:
	var navy: Dictionary = DeckBridge.enemy_roster("navy", 30)
	assert_eq(navy["fighters"].size(), 12)
	assert_eq(navy["reserve"], 18)
	assert_eq(navy["fighters"][0], "officer")
	var small: Dictionary = DeckBridge.enemy_roster("pirate", 6)
	assert_eq(small["fighters"].size(), 6)
	assert_eq(small["fighters"][0], "officer")  # too small a crew for a captain
	var big: Dictionary = DeckBridge.enemy_roster("pirate", 24)
	assert_eq(big["fighters"][0], "captain")
	assert_eq(big["fighters"].count("captain"), 1)


func test_build_twelve_v_twelve_from_state() -> void:
	var s: Dictionary = _state()
	var c: DeckCombat = DeckBridge.build(12, 1.0, 70.0, "navy", 12, 1.0, 70.0, s, 5)
	assert_eq(c.standing_on_screen(0), 12)
	assert_eq(c.standing_on_screen(1), 12)
	assert_eq(c.reserve_of(0), 0)
