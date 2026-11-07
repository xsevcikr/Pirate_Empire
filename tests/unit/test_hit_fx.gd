extends TestCase
## Sound and hit effects: far cannons fade to a rumble, waves slap more often in a rough sea and at speed, the
## hit shake stays subtle and fades with distance, and the sparks switch is saved with the settings.


func test_new_sounds_are_in_the_table() -> void:
	for id in ["cannon_far", "splash_near", "ricochet", "hit_thud", "wave_slap"]:
		assert_true(AudioData.SFX.has(id), id)
		assert_true(FileAccess.file_exists(AudioData.sfx_path(id)), "file for " + id)


func test_far_cannons_fade_and_stop() -> void:
	assert_true(AudioData.is_cannon("cannon_24pdr"))
	assert_true(not AudioData.is_cannon("cannon_far"))
	assert_near(AudioData.far_cannon_db(AudioData.CANNON_FAR_M), 0.0, 0.001)
	assert_near(AudioData.far_cannon_db(AudioData.CANNON_FAR_M * 2.0), -14.0, 0.001, "one doubling")
	assert_true(AudioData.far_cannon_db(1500.0) < AudioData.far_cannon_db(800.0))
	assert_eq(AudioData.far_cannon_db(AudioData.CANNON_FAR_MAX_M), -80.0)


func test_wave_slaps_come_faster_in_rough_seas_and_at_speed() -> void:
	var calm: float = AudioData.slap_interval(0.0, 0.0)
	assert_near(calm, AudioData.SLAP_CALM_S, 0.001)
	assert_true(AudioData.slap_interval(4.0, 0.0) < calm)
	assert_true(AudioData.slap_interval(2.0, 8.0) < AudioData.slap_interval(2.0, 0.0))
	assert_near(AudioData.slap_interval(9.0, 30.0), AudioData.SLAP_MIN_S, 0.001, "never faster than the minimum")


func test_hit_shake_is_subtle_and_fades_with_distance() -> void:
	assert_near(HitFx.hit_shake(0.0, 1000.0), HitFx.SHAKE_HIT_MIN, 0.001)
	assert_near(HitFx.hit_shake(99999.0, 1000.0), HitFx.SHAKE_HIT_MAX, 0.001)
	assert_true(HitFx.hit_shake(60.0, 400.0) > HitFx.hit_shake(60.0, 4000.0), "small hulls rattle more")
	assert_true(HitFx.SHAKE_HIT_MAX <= 0.5 and HitFx.SHAKE_FIRE <= 0.1, "kept subtle")
	assert_near(HitFx.falloff(0.0), 1.0, 0.001)
	assert_near(HitFx.falloff(HitFx.FALLOFF_M * 0.5), 0.5, 0.001)
	assert_eq(HitFx.falloff(HitFx.FALLOFF_M * 2.0), 0.0)


func test_hit_effects_switch_defaults_on() -> void:
	var a := Accessibility.new()
	assert_true(a.hit_effects)
	for loc in ["en", "cs"]:
		var saved: String = Loc.locale
		Loc.locale = loc
		assert_true(Loc.t("menu.hit_effects") != "menu.hit_effects", "menu.hit_effects in " + loc)
		Loc.locale = saved
