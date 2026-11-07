extends TestCase
## Audio: every file the tables name exists, every game action makes a sound, every sound call in the code is in the
## table, the music follows the situation, the crossfade is equal-power and the ambience follows the sea state.


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".ogg"):
			out.append(f.get_basename())
	return out


func test_every_table_sound_has_a_file() -> void:
	for id: String in AudioData.SFX:
		assert_true(FileAccess.file_exists(AudioData.sfx_path(id)), "sfx file for " + id)
	for id: String in AudioData.AMBIENCE:
		assert_true(FileAccess.file_exists(AudioData.ambience_path(id)), "ambience file for " + id)
	for layer: String in AudioData.LAYERS:
		assert_true(FileAccess.file_exists(AudioData.music_path(AudioData.LAYERS[layer])), "layer " + layer)
	for r: String in AudioData.REGION_THEMES:
		assert_true(FileAccess.file_exists(AudioData.music_path("region_" + r)), "region theme " + r)
	for b: String in AudioData.BOSS_THEMES:
		assert_true(FileAccess.file_exists(AudioData.music_path("boss_" + b)), "boss theme " + b)
	for s: String in AudioData.SHANTIES:
		assert_true(FileAccess.file_exists(AudioData.music_path("shanty_" + s)), "shanty " + s)
	assert_true(FileAccess.file_exists(AudioData.music_path(AudioData.TAVERN_TRACK)), "tavern band")
	for group: String in AudioData.VOICE_FILES:
		for v: String in AudioData.VOICE_FILES[group]:
			assert_true(FileAccess.file_exists(AudioData.voice_path(v)), "voice " + v)


func test_no_orphan_files() -> void:
	var known: Dictionary = {}
	for id: String in AudioData.SFX:
		known[id] = true
	for f in _files("res://audio/sfx"):
		assert_true(known.has(f), "sfx file %s is in the table" % f)


func test_every_action_makes_a_sound() -> void:
	for action: String in AudioData.ACTION_SFX:
		assert_true(AudioData.SFX.has(AudioData.ACTION_SFX[action]), "%s -> %s" % [action, AudioData.ACTION_SFX[action]])
	for gun: String in GunData.GUNS:
		assert_true(AudioData.SFX.has(AudioData.cannon_sfx(gun)), "gun %s has a report" % gun)
	for boss: String in AudioData.ROAR_OF:
		assert_true(AudioData.SFX.has(AudioData.ROAR_OF[boss]), "roar of " + boss)


func test_code_only_plays_known_sounds() -> void:
	var rx := RegEx.new()
	rx.compile("Sfx\\.play\\(\"([a-z0-9_]+)\"[,)]")
	var rx2 := RegEx.new()
	rx2.compile("Sfx\\.bark\\(\"([a-z0-9_]+)\"[,)]")
	for dir in ["res://src", "res://scenes"]:
		var stack: Array[String] = [dir]
		while not stack.is_empty():
			var d: String = stack.pop_back()
			for sub in DirAccess.get_directories_at(d):
				stack.append(d + "/" + sub)
			for f in DirAccess.get_files_at(d):
				if not f.ends_with(".gd"):
					continue
				var text: String = FileAccess.get_file_as_string(d + "/" + f)
				for m in rx.search_all(text):
					assert_true(AudioData.SFX.has(m.get_string(1)), "%s/%s plays %s" % [d, f, m.get_string(1)])
				for m in rx2.search_all(text):
					assert_true(AudioData.BARKS.has(m.get_string(1)), "%s/%s barks %s" % [d, f, m.get_string(1)])


func test_barks_are_translated_in_both_languages() -> void:
	var saved: String = Loc.locale
	for loc in ["en", "cs"]:
		Loc.locale = loc
		for sit: String in AudioData.BARKS:
			for key: String in AudioData.BARKS[sit]["lines"]:
				assert_true(Loc.t(key) != key, "%s in %s" % [key, loc])
		for k in ["menu.vol_music", "menu.vol_sfx", "menu.vol_voice", "menu.vol_ambience", "tavern.shanty"]:
			assert_true(Loc.t(k) != k, "%s in %s" % [k, loc])
	Loc.locale = saved


func test_each_music_layer_plays_in_its_situation() -> void:
	assert_eq(AudioData.track_for({}), "layer_explore")
	assert_eq(AudioData.track_for({"hostile_dist": 900.0}), "layer_tension")
	assert_eq(AudioData.track_for({"enemy_in_combat": true}), "layer_combat")
	assert_eq(AudioData.track_for({"boarding": true}), "layer_boarding")
	assert_eq(AudioData.track_for({"boss": true}), "layer_boss")
	assert_eq(AudioData.track_for({"in_port": true}), "layer_port")
	assert_eq(AudioData.track_for({"weather": "storm"}), "layer_storm")


func test_region_and_boss_themes() -> void:
	for r: String in AudioData.REGION_THEMES:
		assert_eq(AudioData.track_for({"region": r}), "region_" + r)
	assert_eq(AudioData.track_for({"region": "coral_isles", "enemy_in_combat": true}), "layer_combat")
	assert_eq(AudioData.track_for({"boss": true, "boss_id": "kraken"}), "boss_kraken")
	assert_eq(AudioData.track_for({"boss": true, "boss_id": "unknown"}), "layer_boss")


func test_crossfade_is_equal_power_over_two_seconds() -> void:
	assert_eq(AudioData.CROSSFADE_S, 2.0)
	var g: Array[float] = AudioData.crossfade_gains(0.0)
	assert_near(g[0], 1.0, 0.001)
	assert_near(g[1], 0.0, 0.001)
	g = AudioData.crossfade_gains(2.0)
	assert_near(g[0], 0.0, 0.001)
	assert_near(g[1], 1.0, 0.001)
	for i in 21:
		var h: Array[float] = AudioData.crossfade_gains(float(i) * 0.1)
		assert_near(h[0] * h[0] + h[1] * h[1], 1.0, 0.001)


func test_ambience_follows_sea_state() -> void:
	var calm: Dictionary = AudioData.ambience_mix(0.5, 3.0)
	var storm: Dictionary = AudioData.ambience_mix(7.0, 35.0)
	assert_true(calm["waves_calm"] > storm["waves_calm"])
	assert_true(storm["waves_rough"] > calm["waves_rough"])
	assert_true(storm["rain"] > 0.9 and calm["rain"] == 0.0)
	assert_true(storm["wind"] > calm["wind"])


func test_mixer_plays_and_ducks() -> void:
	var mixer: Node = load("res://src/audio/audio_mixer.gd").new()
	mixer.muted = true
	mixer._ready()
	assert_true(mixer.play_sfx("coin"))
	assert_true(not mixer.play_sfx("coin"), "the cooldown stops machine-gunning")
	assert_true(not mixer.play_sfx("nope"), "unknown ids are ignored")
	assert_true(mixer.bark("sail_ho"))
	assert_true(mixer.ducked(), "a bark ducks the music")
	assert_true(not mixer.bark("sail_ho"), "barks have a cooldown")
	mixer.set_music("layer_combat")
	assert_eq(mixer.current_track(), "layer_combat")
	mixer.set_override("tavern_band")
	assert_eq(mixer.current_track(), "tavern_band")
	mixer.set_override("")
	assert_eq(mixer.current_track(), "layer_combat")
	mixer.free()


func test_shanty_needs_loyal_morale() -> void:
	assert_true(AudioData.SHANTY_MIN_MORALE >= 70.0 and AudioData.SHANTIES.size() == 5)
