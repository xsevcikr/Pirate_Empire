extends TestCase
## The Kenney-style HUD pieces that have rules: the key-cap prompt parser, the quest banner, nameplate sides and
## fading, key names, crew cards, and that no wind is left in the game's rules.


func test_prompt_parts_split_keys_from_words() -> void:
	var parts: Array = GameOverlay.prompt_parts("Space: Dock   F: Tie up the ship")
	assert_eq(parts.size(), 2)
	assert_eq(parts[0], ["Space", "Dock"])
	assert_eq(parts[1], ["F", "Tie up the ship"])
	assert_eq(GameOverlay.prompt_parts(""), [])
	var plain: Array = GameOverlay.prompt_parts("Nothing to press here: just words that go on and on")
	assert_eq(plain[0][0], "", "a long text before a colon is not a key")


func test_every_prompt_string_has_a_key() -> void:
	for key: String in ["hud.dock_hint", "lagoon.hint", "hud.land_hint"]:
		for part: Array in GameOverlay.prompt_parts(Loc.t(key)):
			assert_true(str(part[0]) != "", "%s shows a key cap" % key)


func test_quest_banner_shows_the_job_you_took() -> void:
	var st: Dictionary = SaveGame.new_state()
	st["quests"] = []
	assert_eq(GameOverlay.quest_hint(st), "")
	st["quests"] = ["gallows_raid"]
	assert_eq(GameOverlay.quest_hint(st), Loc.t(QuestData.JOBS["gallows_raid"]["title"]))
	assert_eq(GameOverlay.quest_hint({}), "")


func test_nameplate_sides_and_icons() -> void:
	assert_eq(WorldMarkers.side_of("player", "player"), "friend")
	assert_eq(WorldMarkers.side_of("player", "merchant"), "neutral")
	assert_eq(WorldMarkers.side_of("player", "navy"), "foe")
	for side: String in ["friend", "foe", "neutral"]:
		assert_true(UiKit.icon_texture(WorldMarkers.side_icon(side)) != null, "%s has an icon, not only a colour" % side)
	assert_true(WorldMarkers.side_color("friend") != WorldMarkers.side_color("foe"))


func test_nameplates_only_when_close() -> void:
	assert_eq(WorldMarkers.plate_alpha(50.0), 1.0)
	assert_true(WorldMarkers.plate_alpha(190.0) > 0.0 and WorldMarkers.plate_alpha(190.0) < 1.0)
	assert_eq(WorldMarkers.plate_alpha(WorldMarkers.NAMEPLATE_RANGE_M + 1.0), 0.0)


func test_key_names_are_short() -> void:
	assert_eq(UiKit.key_label("Slash"), "/")
	assert_eq(UiKit.key_label("F"), "F")
	assert_eq(UiKit.key_label("Escape"), "Esc")


func test_skin_and_font_are_there() -> void:
	for n: String in ["panel_wood", "panel_paper", "panel_dark", "button_normal", "bar_back", "bar_fill", "keycap", "fx_puff", "fx_ring", "fx_drop", "fx_foam"]:
		assert_true(UiKit.tex(n) != null, n)
	assert_true(UiKit.font(false) != null and UiKit.font(true) != null)
	assert_true(Look.ui_theme().default_font_size >= 22, "text is big enough to read")


func test_crew_cards() -> void:
	var m: Dictionary = {"name": "Anne Bonny", "type": "bosun", "level": 1, "xp": 50}
	assert_eq(CrewScreen.portrait_of(m), CrewScreen.portrait_of(m.duplicate()), "same sailor, same face")
	assert_near(CrewScreen.level_progress(m), 0.5, 0.001)
	m["level"] = CrewTypes.MAX_LEVEL
	assert_eq(CrewScreen.level_progress(m), 1.0)
	assert_true(UiKit.icon_texture(CrewScreen.portrait_of(m)) != null, "portrait rendered")


func test_no_wind_left_in_the_rules() -> void:
	assert_eq(float(SeaEventData.EVENTS["becalmed"]["chance"]), 0.0, "nothing can becalm the ship")
	for a: String in ["wind_cw", "wind_ccw", "wind_stronger", "wind_weaker"]:
		assert_true(not GameInput.ACTIONS.has(a), a)
	assert_true(Loc.t("hud.card_sail").find("%.0f") < 0, "no wind speed on the ship card")
