extends TestCase


func test_localization_fallback() -> void:
	Loc.locale = "en"
	assert_eq(Loc.t("ui.play"), "Play")
	Loc.locale = "cs"
	assert_eq(Loc.t("ui.play"), "Hrát")
	Loc.locale = "de"
	assert_eq(Loc.t("ui.play"), "Play")  # falls back to English
	assert_eq(Loc.t("missing.key"), "missing.key")
	Loc.locale = "en"
	assert_true(Loc.locales().has("cs"))


func test_every_english_string_has_a_czech_one() -> void:
	Loc.load_table()
	for k in Loc._table["en"].keys():
		assert_true(Loc._table["cs"].has(k) and Loc._table["cs"][k] != "", k)


func test_crash_marker_detects_unclean_exit() -> void:
	var m: String = "user://test_session.lock"
	CrashLog.end(m)
	assert_true(not CrashLog.begin(m))
	assert_true(CrashLog.begin(m))  # never ended: crashed
	CrashLog.end(m)
	assert_true(not CrashLog.begin(m))
	CrashLog.end(m)


func test_log_is_bounded() -> void:
	for i in CrashLog.MAX_LINES + 100:
		CrashLog.log_line("line %d" % i)
	assert_eq(CrashLog.line_count(), CrashLog.MAX_LINES)
	CrashLog.flush("user://test_last.log")
	assert_true(FileAccess.file_exists("user://test_last.log"))


func test_credits_present() -> void:
	assert_true(Credits.text().contains("PIRATE EMPIRE"))


func test_export_presets_cover_three_platforms() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var names: Array = []
	for s in cfg.get_sections():
		if cfg.has_section_key(s, "name"):
			names.append(cfg.get_value(s, "platform"))
	assert_true(names.has("Windows Desktop") and names.has("Linux") and names.has("macOS"))
