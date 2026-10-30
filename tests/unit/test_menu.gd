extends TestCase


func test_migration_from_v2_adds_world_position() -> void:
	var v2: String = '{"version": 2, "gold": 530, "hour": 8.0, "day": 4, "crew": 9}'
	var s: Dictionary = SaveGame.from_json(v2)
	assert_eq(s["version"], 3)
	assert_eq(s["gold"], 530)
	assert_true(s.has("pos") and s.has("yaw") and s.has("playtime") and s.has("captain"))


func test_every_string_has_czech() -> void:
	Loc.load_table()
	var f := FileAccess.open(Loc.PATH, FileAccess.READ)
	var header: PackedStringArray = f.get_csv_line()
	assert_eq(header.size(), 3)
	var missing: Array[String] = []
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		if row.size() < 3 or row[1] == "" or row[2] == "":
			missing.append(row[0])
	assert_true(missing.is_empty(), "strings missing a translation: %s" % str(missing))


func test_czech_locale_translates_menu() -> void:
	var old: String = Loc.locale
	Loc.locale = "cs"
	assert_eq(Loc.t("menu.new_game"), "Nová hra")
	Loc.locale = "en"
	assert_eq(Loc.t("menu.new_game"), "New Game")
	Loc.locale = old


func test_begin_new_sets_difficulty_and_name() -> void:
	Session.begin_new("Anne", 9, 42)
	assert_eq(Session.state["difficulty"], 3)
	assert_eq(Session.state["captain"], "Anne")
	assert_eq(Session.state["seed"], 42)
	Session.state = {}


func test_empty_slot_summary() -> void:
	assert_eq(Session.summary(98), Loc.t("menu.empty_slot"))


func test_slot_round_trip_keeps_position() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["pos"] = [123.5, -456.25]
	s["saved_at"] = 1000
	assert_true(SaveGame.write(s, 97))
	var back: Dictionary = SaveGame.read(97)
	assert_near(back["pos"][0], 123.5, 0.001)
	assert_near(back["pos"][1], -456.25, 0.001)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % 97))


func test_pause_action_has_keyboard_and_gamepad() -> void:
	GameInput.register()
	var key := false
	var pad := false
	for ev in InputMap.action_get_events("pause"):
		key = key or ev is InputEventKey
		pad = pad or ev is InputEventJoypadButton
	assert_true(key and pad)


func test_register_does_not_duplicate_rebound_keys() -> void:
	GameInput.register()
	Rebind.rebind("camera_mode", KEY_Y)
	GameInput.register()
	assert_eq(InputMap.action_get_events("camera_mode").size(), 1)
	Rebind.reset_defaults()
