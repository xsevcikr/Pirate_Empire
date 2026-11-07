extends TestCase
## The status panel beside the chart (StatusMath) and the chart's island outlines (IslandShape).


func _ship(extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"hull": 1.0, "crew": 20, "crew_min": 8, "crew_max": 30, "ammo": 300, "guns": 6}
	d.merge(extra, true)
	return d


func test_hearts_are_fifty_hp_each() -> void:
	var full: Dictionary = StatusMath.hearts(DeckData.FIGHTER_HP)
	assert_eq(full["total"], 4)
	assert_eq(full["halves"], 8)
	assert_eq(full["level"], StatusMath.OK)
	assert_eq(StatusMath.hearts(125.0)["halves"], 5, "2.5 hearts")
	assert_eq(StatusMath.hearts(26.0)["halves"], 2, "a scratch over half a heart rounds up")
	assert_eq(StatusMath.hearts(90.0)["level"], StatusMath.LOW)
	assert_eq(StatusMath.hearts(40.0)["level"], StatusMath.DANGER)


func test_a_fresh_game_is_all_green_but_short_supplies() -> void:
	var st: Dictionary = SaveGame.new_state()
	var rows: Dictionary = StatusMath.rows(st, _ship())
	for id in StatusMath.ROWS:
		assert_true(rows.has(id), id)
		var f: float = float(rows[id]["frac"])
		assert_true(f >= 0.0 and f <= 1.0, "bar share in range: " + id)
	assert_eq(rows["hull"]["level"], StatusMath.OK)
	assert_eq(rows["hull"]["text"], "100%")
	assert_eq(rows["crew"]["text"], "20/30")
	assert_eq(rows["ammo"]["level"], StatusMath.OK)


func test_bars_turn_yellow_then_red() -> void:
	var st: Dictionary = SaveGame.new_state()
	assert_eq(StatusMath.rows(st, _ship({"hull": 0.4}))["hull"]["level"], StatusMath.LOW)
	assert_eq(StatusMath.rows(st, _ship({"hull": 0.2}))["hull"]["level"], StatusMath.DANGER)
	assert_eq(StatusMath.rows(st, _ship({"crew": 12}))["crew"]["level"], StatusMath.LOW)
	assert_eq(StatusMath.rows(st, _ship({"crew": 5}))["crew"]["level"], StatusMath.DANGER, "under the minimum to sail")
	assert_eq(StatusMath.rows(st, _ship({"ammo": 30}))["ammo"]["level"], StatusMath.LOW, "5 broadsides left")
	assert_eq(StatusMath.rows(st, _ship({"ammo": 12}))["ammo"]["level"], StatusMath.DANGER, "2 broadsides left")
	st["supplies"]["rum"] = 0.0
	assert_eq(StatusMath.rows(st, _ship())["rum"]["level"], StatusMath.DANGER)
	assert_eq(StatusMath.rows(st, _ship())["rum"]["text"], "0")
	st["supplies"]["rum"] = DeckData.RUM_SUPPLY_PER_DRINK * 2.0
	assert_eq(StatusMath.rows(st, _ship())["rum"]["level"], StatusMath.LOW)
	st["supplies"]["food"] = 0.0
	assert_eq(StatusMath.rows(st, _ship())["food"]["level"], StatusMath.DANGER)
	st["supplies"]["water"] = 1000.0
	var water: Dictionary = StatusMath.rows(st, _ship())["water"]
	assert_eq(water["level"], StatusMath.OK)
	assert_near(float(water["frac"]), 1.0, 0.0001, "a full cask fills the bar and no more")


func test_colours_differ_by_level() -> void:
	assert_true(StatusMath.colour(StatusMath.OK) != StatusMath.colour(StatusMath.LOW))
	assert_true(StatusMath.colour(StatusMath.LOW) != StatusMath.colour(StatusMath.DANGER))


func test_panel_icons_exist() -> void:
	for id in StatusPanel.ICONS:
		assert_true(ResourceLoader.exists(CatalogueIcons.path_of(StatusPanel.ICONS[id])), "icon for " + id)


func test_half_heart_is_the_left_half() -> void:
	for p in StatusPanel.heart_points(Vector2.ZERO, 1.0, true):
		assert_true(p.x <= 0.001, "left of the middle")


func test_island_outlines_follow_the_real_coast() -> void:
	var g: WorldGen = PortData.gen()
	for i in [0, g.index_of(LagoonData.ISLAND)]:
		var isl: Dictionary = g.islands[i]
		var s: Dictionary = IslandShape.of(i, isl)
		assert_eq((s["coast"] as PackedVector2Array).size(), IslandShape.SEGMENTS)
		var r: float = float(isl["radius"])
		var c: Vector2 = isl["pos"]
		var spread: float = 0.0
		for k in IslandShape.SEGMENTS:
			var coast: float = (s["coast"][k] as Vector2).distance_to(c)
			assert_true(coast > r * 0.25 and coast < r * 1.35, "coast near the island's size")
			assert_true((s["land"][k] as Vector2).distance_to(c) <= coast + 0.01, "green land inside the beach")
			spread = maxf(spread, absf(coast - r))
		assert_true(spread > r * 0.02, "a real coastline, not a circle")
	assert_true(IslandShape.of(0, g.islands[0]) == IslandShape.of(0, g.islands[0]), "cached")
