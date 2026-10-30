extends TestCase


func _random_state(rng: RandomNumberGenerator) -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = rng.randi_range(0, 500000)
	s["hour"] = snappedf(rng.randf_range(0.0, 24.0), 0.01)
	s["day"] = rng.randi_range(0, 500)
	s["crew"] = rng.randi_range(5, 300)
	s["morale"] = snappedf(rng.randf_range(0.0, 100.0), 0.1)
	s["act"] = rng.randi_range(0, 4)
	s["beat"] = rng.randi_range(0, 3)
	s["seed"] = rng.randi_range(1, 99999)
	s["upgrades"] = {"hull": rng.randi_range(0, 5), "sails": rng.randi_range(0, 5)}
	s["cargo"] = {"rum": rng.randi_range(0, 50), "gems": rng.randi_range(0, 9)}
	var d := Discovery.new()
	d.reveal_around(Vector2(rng.randf_range(-7000, 7000), rng.randf_range(-7000, 7000)))
	s["discovery"] = SaveGame.capture_discovery(d)
	s["fleet"] = [{"class_id": "sloop", "hull": 0.5, "crew": rng.randi_range(1, 20), "name": "Prize"}]
	return s


func test_save_round_trip_100_random_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 100:
		var s: Dictionary = _random_state(rng)
		var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
		assert_eq(back["gold"], s["gold"])
		assert_eq(back["crew"], s["crew"])
		assert_near(back["hour"], s["hour"], 0.0001)
		assert_eq(back["discovery"], s["discovery"])
		assert_eq(back["upgrades"].size(), 2)
		assert_eq(int(back["upgrades"]["hull"]), int(s["upgrades"]["hull"]))
		assert_eq(SaveGame.restore_discovery(back["discovery"]).count(), SaveGame.restore_discovery(s["discovery"]).count())
		assert_eq(back["version"], SaveGame.VERSION)


func test_save_file_write_read() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 777
	assert_true(SaveGame.write(s, 99))
	assert_eq(SaveGame.read(99)["gold"], 777)


func test_migration_from_v1_fixture() -> void:
	var v1: String = '{"version": 1, "money": 4200, "reputation": -12, "hour": 9.5, "crew": 18}'
	var s: Dictionary = SaveGame.from_json(v1)
	assert_eq(s["version"], SaveGame.VERSION)
	assert_eq(s["gold"], 4200)
	assert_near(s["rep"]["navy"], -12.0, 0.001)
	assert_near(s["rep"]["pirate"], 20.0, 0.001)
	assert_eq(s["crew"], 18)
	assert_true(s.has("fleet") and s.has("bases"))
	assert_true(not s.has("money"))


func test_bad_save_returns_empty() -> void:
	assert_eq(SaveGame.from_json("not json"), {})


func test_all_controls_rebind() -> void:
	GameInput.register()
	var next_key: int = KEY_F1
	for action in GameInput.ACTIONS.keys():
		assert_true(Rebind.rebind(action, next_key), "rebind " + action)
		assert_eq(Rebind.key_of(action), next_key, action)
		next_key += 1
	Rebind.reset_defaults()
	assert_eq(Rebind.key_of("fire_port"), KEY_Q)


func test_rebind_refuses_conflicts_and_persists() -> void:
	Rebind.reset_defaults()
	assert_true(not Rebind.rebind("fire_port", KEY_E))
	assert_eq(Rebind.conflict("fire_port", KEY_E), "fire_starboard")
	assert_true(Rebind.rebind("fire_port", KEY_SEMICOLON))
	Rebind.save("user://test_input.cfg")
	Rebind.reset_defaults()
	assert_eq(Rebind.key_of("fire_port"), KEY_Q)
	Rebind.load_file("user://test_input.cfg")
	assert_eq(Rebind.key_of("fire_port"), KEY_SEMICOLON)
	Rebind.reset_defaults()


func test_graphics_presets_apply_without_error() -> void:
	for preset in GraphicsPresets.TABLE.keys():
		var env := Environment.new()
		assert_true(GraphicsPresets.apply(preset, env), preset)
		assert_true(GraphicsPresets.sun_shadow_size(preset) >= 1024)
	assert_true(not GraphicsPresets.apply("nonsense", Environment.new()))
	assert_true(GraphicsPresets.TABLE["low"]["particles"] < GraphicsPresets.TABLE["ultra"]["particles"])


func test_accessibility_ranges() -> void:
	var a := Accessibility.new()
	a.set_fov(500.0)
	assert_eq(a.fov, 100.0)
	a.set_fov(10.0)
	assert_eq(a.fov, 50.0)
	assert_near(a.shake_degrees(10000.0), 0.6, 0.0001)
	a.set_camera_shake(0.0)
	assert_eq(a.shake_degrees(10000.0), 0.0)


func test_audio_director_priority() -> void:
	assert_eq(AudioDirector.pick({"boss": true, "boarding": true}), AudioDirector.Music.BOSS)
	assert_eq(AudioDirector.pick({"enemy_in_combat": true}), AudioDirector.Music.COMBAT)
	assert_eq(AudioDirector.pick({"hostile_dist": 800.0}), AudioDirector.Music.TENSION)
	assert_eq(AudioDirector.pick({}), AudioDirector.Music.EXPLORE)


func test_full_campaign_bot_completes_all_five_acts() -> void:
	var c := Campaign.new()
	var bosses: Array[String] = []
	var guard: int = 0
	while not c.is_done() and guard < 100:
		var beat: String = c.current_beat()
		if beat.begins_with("defeat_"):
			var id: String = {"defeat_valcourt": "valcourt", "defeat_ghost_admiral": "ghost_admiral", "defeat_kraken": "kraken", "defeat_black_ibrahim": "black_ibrahim"}.get(beat, "")
			if id != "":
				var b := Boss.new(id, 1)
				var t: float = 0.0
				while not b.defeated and t < 900.0:
					b.tick(0.5)
					b.damage(100.0, true)
					t += 0.5
				assert_true(b.defeated, id)
				bosses.append(id)
		assert_true(c.complete(beat), beat)
		guard += 1
	assert_eq(c.finished_acts, 5)
	assert_eq(bosses, ["valcourt", "ghost_admiral", "kraken", "black_ibrahim"] as Array[String])
	assert_true(c.unlocked.has("new_game_plus"))
