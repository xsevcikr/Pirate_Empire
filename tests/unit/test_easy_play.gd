extends TestCase
## The kid-friendly layer: goals and stars, the collection book, hidden treasure, the parrot's hints, Easy aiming,
## the second chance and the save migration. Also checks the wind no longer matters to sailing.


func _s(difficulty: int = 1) -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["difficulty"] = difficulty
	s["tutorial"] = "done"
	return s


# ---- goals ------------------------------------------------------------------------------------------------

func test_goal_list_is_well_formed() -> void:
	var seen: Dictionary = {}
	for g in GoalData.LIST:
		assert_true(not seen.has(g["id"]), "goal ids are unique: %s" % g["id"])
		seen[g["id"]] = true
		assert_true(int(g["stars"]) >= 1 and int(g["stars"]) <= 3, "1-3 stars")
		assert_true(Loc.t("goal." + str(g["id"])) != "goal." + str(g["id"]), "goal %s has text" % g["id"])
		assert_true(Loc.t("goal.%s.hint" % g["id"]) != "goal.%s.hint" % g["id"], "goal %s has a parrot hint" % g["id"])
	assert_true(GoalData.total_stars() >= 30, "enough stars to reach the golden parrot")
	assert_true(not EasyPlay.goal_text("parrot_find").contains("%"), "the parrot's name is filled in")


func test_goals_pay_stars_and_gold_once() -> void:
	var s: Dictionary = _s()
	assert_eq(EasyPlay.active(s).size(), GoalData.ACTIVE_SHOWN)
	assert_eq(str(EasyPlay.active(s)[0]["id"]), "first_sail")
	Achievements.record(s, "distance_km", 1.2)
	var gold: int = int(s["gold"])
	var fresh: Array[Dictionary] = EasyPlay.check(s)
	assert_eq(fresh.size(), 1)
	assert_eq(EasyPlay.stars(s), 1)
	assert_eq(int(s["gold"]), gold + GoalData.GOLD_PER_STAR)
	assert_true(EasyPlay.check(s).is_empty(), "a goal pays only once")
	assert_eq(str(EasyPlay.active(s)[0]["id"]), "find_islands", "the card moves on to the next goal")


func test_treasure_map_goal_counts_map_pieces() -> void:
	var s: Dictionary = _s()
	s["map_fragments"] = ["a", "b"]
	assert_near(EasyPlay.value(s, "maps_found"), 2.0, 0.001)
	s["map_fragments"].append("c")
	EasyPlay.check(s)
	assert_true(EasyPlay.is_done(s, "treasure_maps"))


func test_parrot_colour_follows_stars() -> void:
	var s: Dictionary = _s()
	assert_eq(str(EasyPlay.parrot_colour(s)["id"]), "green")
	EasyPlay.store(s)["stars"] = 6
	assert_eq(str(EasyPlay.parrot_colour(s)["id"]), "blue")
	EasyPlay.store(s)["stars"] = 40
	assert_eq(str(EasyPlay.parrot_colour(s)["id"]), "golden")


# ---- collection -------------------------------------------------------------------------------------------

func test_collection_cards_and_flags() -> void:
	var s: Dictionary = _s()
	assert_true(EasyPlay.add_ship_card(s, "sloop"))
	assert_true(not EasyPlay.add_ship_card(s, "sloop"), "a card is new only once")
	assert_true(not EasyPlay.add_ship_card(s, "no_such_ship"))
	assert_eq(EasyPlay.rare_cards(s), 0)
	EasyPlay.add_ship_card(s, "leviathan")
	assert_eq(EasyPlay.rare_cards(s), 1, "the giants are the rare cards")
	assert_eq(EasyPlay.add_faction_flag(s, "navy"), "flag_navy")
	assert_eq(EasyPlay.add_faction_flag(s, "navy"), "", "one flag per faction")
	assert_eq(EasyPlay.add_faction_flag(s, ""), "")
	assert_near(EasyPlay.value(s, "flags"), 1.0, 0.001)
	assert_near(EasyPlay.value(s, "ship_cards"), 2.0, 0.001)
	assert_eq(CollectionData.ids_of("ships").size(), PortData.CLASS_ORDER.size())
	assert_eq(CollectionData.ids_of("flags").size(), 8)
	assert_eq(CollectionData.ids_of("shells").size(), 6)


func test_every_collectable_has_a_name_and_a_picture() -> void:
	for kind in CollectionData.KINDS:
		for id in CollectionData.ids_of(kind):
			assert_true(CollectionData.display_name(id) != "coll." + id, "%s has a name" % id)
			assert_true(ResourceLoader.exists(CatalogueIcons.path_of(CollectionData.icon(id))), "%s has a picture" % id)


# ---- hidden treasure --------------------------------------------------------------------------------------

func test_hidden_spots_ring_every_island_in_open_water() -> void:
	var spots: Array[Dictionary] = HiddenLoot.spots()
	assert_eq(spots.size(), PortData.gen().islands.size() * HiddenLoot.PER_ISLAND)
	var again: Array[Dictionary] = HiddenLoot.spots()
	assert_eq(spots[3]["pos"], again[3]["pos"], "spots are the same every game")
	for sp in spots:
		for isl: Dictionary in PortData.gen().islands:
			assert_true((sp["pos"] as Vector2).distance_to(isl["pos"]) > float(isl["radius"]) + 40.0, "spot %s is off the shore" % sp["id"])


func test_taking_treasure_and_refill() -> void:
	var s: Dictionary = _s()
	var sp: Dictionary = HiddenLoot.spots()[0]
	var id: String = str(sp["id"])
	var near: Array[Dictionary] = HiddenLoot.near(s, sp["pos"] + Vector2(50, 0))
	assert_true(not near.is_empty() and near[0]["id"] == id, "the nearest full spot comes first")
	var roll_a: Dictionary = HiddenLoot.roll(s, id)
	assert_eq(roll_a, HiddenLoot.roll(s, id), "the same treasure every time it is looked at")
	var gold: int = int(s["gold"])
	var got: Dictionary = HiddenLoot.take(s, id)
	assert_true(int(got["gold"]) >= HiddenLoot.GOLD[0])
	assert_eq(int(s["gold"]), gold + int(got["gold"]))
	assert_near(EasyPlay.value(s, "parrot_finds"), 1.0, 0.001)
	assert_true(HiddenLoot.take(s, id).is_empty(), "an emptied spot has nothing more")
	assert_true(not HiddenLoot.is_full(s, id))
	s["day"] = int(s["day"]) + HiddenLoot.REFILL_DAYS
	assert_true(HiddenLoot.is_full(s, id), "the treasure comes back after a week")


func test_treasure_fills_the_shell_page() -> void:
	var s: Dictionary = _s()
	var items: Dictionary = {}
	for sp in HiddenLoot.spots():
		var got: Dictionary = HiddenLoot.take(s, str(sp["id"]))
		if str(got.get("item", "")) != "":
			items[got["item"]] = true
	assert_true(EasyPlay.kinds_owned(s, "shells") >= 3, "a lap of the islands finds several kinds of shell")
	assert_true(EasyPlay.total_of(s, "shells") > 10)


func test_easy_treasure_pays_more() -> void:
	var e: Dictionary = _s(0)
	var n: Dictionary = _s(1)
	var id: String = str(HiddenLoot.spots()[5]["id"])
	assert_true(int(HiddenLoot.roll(e, id)["gold"]) > int(HiddenLoot.roll(n, id)["gold"]))


func test_compass_words() -> void:
	assert_eq(HiddenLoot.compass(Vector2.ZERO, Vector2(0, -100)), "north")
	assert_eq(HiddenLoot.compass(Vector2.ZERO, Vector2(100, 0)), "east")
	assert_eq(HiddenLoot.compass(Vector2.ZERO, Vector2(-70, 70)), "south_west")


# ---- parrot -----------------------------------------------------------------------------------------------

func test_parrot_hints_put_urgent_things_first() -> void:
	var s: Dictionary = _s()
	s["crew"] = 5
	var far := Vector2(99999, 99999)
	assert_eq(str(ParrotHints.pick(s, {"hull": 0.2, "pos": far})["key"]), "parrot.hint_repair")
	s["supplies"]["food"] = 0.5
	assert_eq(str(ParrotHints.pick(s, {"hull": 1.0, "pos": far})["key"]), "parrot.hint_food")
	s["supplies"]["food"] = 10.0
	var sp: Dictionary = HiddenLoot.spots()[0]
	assert_eq(str(ParrotHints.pick(s, {"hull": 1.0, "pos": sp["pos"] + Vector2(300, 0)})["key"]), "parrot.hint_loot")
	assert_eq(str(ParrotHints.pick(s, {"hull": 1.0, "pos": far})["key"]), "goal.first_sail.hint")
	assert_true(ParrotHints.say(s, {"hull": 1.0, "pos": far}).begins_with(Loc.t("parrot.name")))


# ---- easy aiming ------------------------------------------------------------------------------------------

func test_aim_assist_only_on_easy() -> void:
	assert_true(AimAssist.enabled(_s(0)))
	for d in [1, 2, 3]:
		assert_true(not AimAssist.enabled(_s(d)))
	assert_true(not AimAssist.enabled({}))


func test_deck_aim_snaps_onto_a_foe_in_front() -> void:
	var foes: Array = [Vector2(5, 1.5), Vector2(-4, 0)]
	var a: Vector2 = AimAssist.deck_aim(Vector2.ZERO, Vector2.RIGHT, foes, 20.0)
	assert_near(a.angle_to(Vector2(5, 1.5)), 0.0, 0.001)
	var behind: Vector2 = AimAssist.deck_aim(Vector2.ZERO, Vector2.UP, [Vector2(0, -5)], 20.0)
	assert_near(behind.angle_to(Vector2.UP), 0.0, 0.001, "a foe behind is not snapped to")


func test_easy_deck_fight_has_the_aim_help() -> void:
	var easy: DeckCombat = DeckBridge.build(10, 1.0, 70.0, "merchant", 8, 1.0, 70.0, _s(0), 3)
	var normal: DeckCombat = DeckBridge.build(10, 1.0, 70.0, "merchant", 8, 1.0, 70.0, _s(1), 3)
	assert_true(easy.aim_assist)
	assert_true(not normal.aim_assist)
	# the captain fires well off to the side of the nearest foe: on Easy the shot still swings onto him
	var foe: FighterState = easy.nearest_enemy(easy.player)
	var to: Vector2 = (foe.pos - easy.player.pos).normalized()
	var hits: Array = []
	easy.ranged_fired.connect(func(_id: int, _a: Vector2, b: Vector2) -> void: hits.append(b))
	easy.player.reload_left = 0.0
	if easy.fire_ranged(easy.player, to.rotated(deg_to_rad(20.0))):
		assert_true(absf(rad_to_deg(easy.player.dir.angle_to(to))) < 1.0, "the pistol swung onto the foe")


# ---- second chance ----------------------------------------------------------------------------------------

func test_second_chance_on_easy_and_normal() -> void:
	for d in [0, 1]:
		var s: Dictionary = _s(d)
		s["ship_class"] = "brigantine"
		s["gold"] = 1000
		s["crew"] = 20
		s["cargo"] = {"sugar": 5.0}
		var r: Dictionary = Finance.defeat(s, Vector2.ZERO)
		assert_true(bool(r["second_chance"]))
		assert_true(bool(r["ship_kept"]))
		assert_eq(s["ship_class"], "brigantine", "the ship is kept")
		assert_eq(int(s["crew"]), 20, "nobody is lost")
		assert_eq(int(s["gold"]), 900 if d == 0 else 800, "only a little gold is lost")
		assert_true((s["cargo"] as Dictionary).has("sugar"))
		assert_near(float(s["ship_hull"]), TradeData.SECOND_CHANCE_HULL, 0.001)


func test_hard_keeps_the_full_defeat() -> void:
	var s: Dictionary = _s(2)
	s["ship_class"] = "brigantine"
	s["gold"] = 1000
	var r: Dictionary = Finance.defeat(s, Vector2.ZERO)
	assert_true(not bool(r["second_chance"]))
	assert_eq(s["ship_class"], TradeData.DEFEAT_START_CLASS)
	assert_eq(int(s["gold"]), 500)


# ---- save ----------------------------------------------------------------------------------------------------

func test_save_round_trip_and_migration() -> void:
	var s: Dictionary = _s()
	EasyPlay.collect(s, "shell_conch")
	EasyPlay.store(s)["stars"] = 4
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(EasyPlay.count_of(back, "shell_conch"), 1)
	assert_eq(EasyPlay.stars(back), 4)
	var old: Dictionary = SaveGame.new_state()
	old.erase("easy_play")
	old["version"] = 17
	old["tutorial"] = "into_wind"
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(int(m["version"]), SaveGame.VERSION)
	assert_true(m["easy_play"] is Dictionary)
	assert_eq(str(m["tutorial"]), "steer", "the old face-the-wind step becomes the steering step")
	assert_eq(TutorialData.index_of("into_wind"), TutorialData.STEPS.size() - 1, "no wind step in the tutorial")


# ---- no wind ------------------------------------------------------------------------------------------------

func test_no_wind_controls_or_events() -> void:
	for a in ["wind_cw", "wind_ccw", "wind_stronger", "wind_weaker"]:
		assert_true(not GameInput.ACTIONS.has(a), "%s is gone" % a)
	assert_true(not SeaEventData.EVENTS.has("becalmed"))
