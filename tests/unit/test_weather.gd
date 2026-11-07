extends TestCase


func _sloop_dm() -> DamageModel:
	return DamageModel.new(load("res://data/ships/sloop.tres"), 3)


func test_every_weather_has_every_number() -> void:
	for id: String in WeatherChain.STATES:
		assert_true(WeatherRules.PROFILES.has(id), "profile for " + id)
		for k: String in WeatherRules.PROFILES["clear"]:
			assert_true((WeatherRules.PROFILES[id] as Dictionary).has(k), "%s has %s" % [id, k])


func test_blend_runs_from_one_weather_to_the_next() -> void:
	var a: Dictionary = WeatherRules.blend("clear", "storm", 0.0)
	var b: Dictionary = WeatherRules.blend("clear", "storm", 1.0)
	var mid: Dictionary = WeatherRules.blend("clear", "storm", 0.5)
	assert_near(float(a["wind"]), 14.0, 0.001)
	assert_near(float(b["storm"]), 1.0, 0.001)
	assert_near(float(mid["rain"]), 0.5, 0.001)
	assert_true(float(b["wind"]) >= 25.0, "a storm wind counts as a storm for the sea events")


func test_night_from_the_hour() -> void:
	assert_near(WeatherRules.night_amount(12.0), 0.0, 0.001)
	assert_near(WeatherRules.night_amount(0.0), 1.0, 0.001)
	assert_true(WeatherRules.is_night(22.0) and WeatherRules.is_night(3.0))
	assert_true(not WeatherRules.is_night(8.0) and not WeatherRules.is_night(16.0))


func test_lookouts_see_less_at_night_and_in_fog() -> void:
	var clear: Dictionary = WeatherRules.PROFILES["clear"]
	assert_near(WeatherRules.sight(clear, 12.0), 1.0, 0.001)
	assert_near(WeatherRules.sight(clear, 0.0), WeatherRules.NIGHT_SIGHT, 0.001)
	assert_true(WeatherRules.sight(WeatherRules.PROFILES["fog"], 12.0) < 0.5)
	assert_true(WeatherRules.sight(WeatherRules.PROFILES["storm"], 0.0) < WeatherRules.sight(clear, 0.0))


func test_lightning_hits_mast_and_sail_but_never_the_hull() -> void:
	var dm: DamageModel = _sloop_dm()
	var hull: float = dm.hull_hp_total()
	var mast: int = WeatherRules.strike_mast(dm)
	var r: Dictionary = WeatherRules.lightning_strike(dm, mast, 3, 1.0, 1.0)
	assert_near(dm.hull_hp_total(), hull, 0.001)
	assert_near(float(r["sail"]), dm.sail_max * WeatherRules.LIGHTNING_SAIL_SHARE, 0.01)
	assert_near(dm.mast_hp[mast], dm.mast_max * (1.0 - WeatherRules.LIGHTNING_MAST_SHARE), 0.01)
	assert_true(not dm.sunk)


func test_furled_sails_and_frost_sails_take_less() -> void:
	var a: DamageModel = _sloop_dm()
	var b: DamageModel = _sloop_dm()
	var full: Dictionary = WeatherRules.lightning_strike(a, 0, 3, 1.0, 1.0)
	var furled: Dictionary = WeatherRules.lightning_strike(b, 0, 0, 1.0, 0.0)
	assert_near(float(furled["sail"]), float(full["sail"]) * 0.25, 0.01)
	assert_near(float(furled["mast_dmg"]), 0.0, 0.001)


func test_three_strikes_bring_a_mast_down() -> void:
	var dm: DamageModel = _sloop_dm()
	var fell: Array = []
	dm.mast_fell.connect(func(i: int) -> void: fell.append(i))
	for i in 3:
		WeatherRules.lightning_strike(dm, 0, 3, 1.0, 1.0)
	assert_true(dm.mast_down[0])
	assert_eq(fell, [0])
	assert_eq(WeatherRules.strike_mast(dm), -1, "no standing mast left on a sloop")


func test_big_sea_hurts_most_on_the_beam() -> void:
	var north := Vector2(0, -1)
	assert_near(WeatherRules.wave_exposure(north, Vector2(1, 0)), 1.0, 0.001)
	assert_near(WeatherRules.wave_exposure(north, Vector2(0, 1)), WeatherRules.WAVE_HEAD_ON, 0.001)
	assert_near(WeatherRules.wave_exposure(north, Vector2(0, -1)), WeatherRules.WAVE_HEAD_ON, 0.001)
	assert_eq(WeatherRules.wave_side(north, Vector2(-1, 0)), "starboard")  # running to port: it came from starboard
	assert_eq(WeatherRules.wave_side(north, Vector2(1, 0)), "port")
	assert_eq(WeatherRules.wave_side(north, Vector2(0, 1)), "bow")


func test_big_sea_breaks_on_the_side_it_comes_from() -> void:
	var dm: DamageModel = _sloop_dm()
	var north := Vector2(0, -1)
	assert_true(dm.section_is_starboard(WeatherRules.wave_section(dm, north, Vector2(-1, 0))))
	assert_true(not dm.section_is_starboard(WeatherRules.wave_section(dm, north, Vector2(1, 0))))


func test_storms_alone_can_never_sink_a_ship() -> void:
	var dm: DamageModel = _sloop_dm()
	var sunk: Array = [false]
	dm.sank.connect(func() -> void: sunk[0] = true)
	for i in 200:
		WeatherRules.storm_hull_hit(dm, i % dm.section_count, WeatherRules.wave_damage(dm.stats.hull_hp, 1.0, 1.0))
		WeatherRules.lightning_strike(dm, WeatherRules.strike_mast(dm), 3, 1.0, 1.0)
		dm.tick(1.0, 0.0)
	assert_true(not sunk[0] and not dm.sunk)
	assert_near(dm.hull_fraction(), WeatherRules.STORM_HULL_FLOOR, 0.02)
	assert_near(dm.water_total(), 0.0, 0.001, "no breach, no water")
	assert_eq(WeatherRules.storm_hull_hit(dm, 0, 500.0), 0.0, "nothing more to take at the floor")


func test_storm_day_is_read_once() -> void:
	var st: Dictionary = {"weather": {"storm_day": true}}
	assert_true(WeatherSystem.take_storm_day(st))
	assert_true(not WeatherSystem.take_storm_day(st))
	assert_true(not WeatherSystem.take_storm_day({}))


func test_weather_steps_by_region_and_saves() -> void:
	var ws := WeatherSystem.new()
	ws.state = {"seed": 5}
	var seen: Dictionary = {}
	for i in 60:
		seen[ws.step("dead_reach")] = true
	assert_true(seen.has("storm"), "the Dead Reach brews storms")
	assert_true(not seen.has("clear") or seen.size() > 1)
	var w: Dictionary = ws.state["weather"]
	assert_eq(int(w["steps"]), 60)
	assert_true(WeatherRules.PROFILES.has(str(w["now"])))
	ws.set_now("fog")
	assert_eq(ws.now(), "fog")
	assert_near(float(ws.current["fog"]), 35.0, 0.001)
	ws.free()


func test_strings_exist() -> void:
	for id: String in WeatherChain.STATES:
		assert_true(Loc.t("weather." + id) != "weather." + id, id)
	for s: String in ["port", "starboard", "bow", "stern"]:
		assert_true(Loc.t("weather.side." + s) != "weather.side." + s, s)
