extends TestCase


func test_hand_counts_follow_crew_and_caps() -> void:
	assert_eq(DeckCrew.hands_for(0, true), 0)
	assert_eq(DeckCrew.hands_for(1, true), 1)
	assert_eq(DeckCrew.hands_for(12, true), 6)
	assert_eq(DeckCrew.hands_for(200, true), DeckCrew.MAX_PLAYER_HANDS)
	assert_eq(DeckCrew.hands_for(8, false), 2)
	assert_eq(DeckCrew.hands_for(400, false), DeckCrew.MAX_AI_HANDS)


func test_enemy_crews_dress_by_faction() -> void:
	assert_eq(DeckCrew.ai_kind("navy", 0), "marine")
	assert_eq(DeckCrew.ai_kind("pirate", 2), "brute")
	assert_eq(DeckCrew.ai_kind("iron", 0), DeckCrew.ai_kind("pirate", 0), "unknown flags crew like pirates")
	for k: String in ["navy", "merchant", "pirate"]:
		for i in 6:
			assert_true(DeckData.ENEMIES.has(DeckCrew.ai_kind(k, i)))


func test_stations_stay_on_the_deck() -> void:
	for i in DeckCrew.MAX_PLAYER_HANDS:
		var p: Vector2 = DeckCrew.station(i, 20.0, 2.0)
		assert_true(absf(p.x) <= 2.0 * 0.6, "inside the rails")
		assert_true(absf(p.y) <= 20.0 * 0.35, "between bow and stern")


func test_status_line_is_short_until_something_matters() -> void:
	var st: Dictionary = SaveGame.new_state()
	st["morale"] = 70.0
	var calm: String = GameOverlay.status_text(st)
	assert_true(calm.find("%") < 0, "no hold or morale while all is well")
	st["morale"] = 20.0
	assert_true(GameOverlay.status_text(st).length() > calm.length(), "unhappy men show up")
