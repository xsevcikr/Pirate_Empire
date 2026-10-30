extends TestCase
## M23: the rival pirate crews' rules (PirateCrews, CrewData) and their deck fighters (CrewDeck).


func _rng(s: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 10000
	return s


func test_four_crews_start_with_ships_and_their_home_waters() -> void:
	var s: Dictionary = _state()
	assert_eq(CrewData.ORDER.size(), 4)
	for id: String in CrewData.ORDER:
		var c: Dictionary = PirateCrews.get_crew(s, id)
		assert_true(int(c["fleet"]) >= 5, id + " has a fleet")
		assert_eq(PirateCrews.owner_of(s, CrewData.def(id)["home"]), id, id + " holds its home region")
		assert_true(not bool(c["lagoon_known"]), id + " lagoon starts hidden")


func test_every_lagoon_is_open_water_inside_its_home_region() -> void:
	for id: String in CrewData.ORDER:
		var p: Vector2 = CrewData.lagoon_pos(id)
		assert_eq(WorldMap.region_at(p), CrewData.def(id)["home"], id + " lagoon region")
		for isl: Dictionary in PortData.gen().islands:
			assert_true(p.distance_to(isl["pos"]) >= float(isl["radius"]) + CrewData.LAGOON_CLEARANCE_M - 1.0, "%s lagoon clear of %s" % [id, isl["name"]])


func test_sixty_days_of_crews_make_news_and_stay_in_bounds() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(7)
	var news: int = 0
	for d in 60:
		s["day"] = d
		news += PirateCrews.day_tick(s, r).size()
	assert_true(news >= 60 * 3, "every crew acts most days (%d news)" % news)
	for id: String in CrewData.ORDER:
		var c: Dictionary = PirateCrews.get_crew(s, id)
		assert_true(int(c["fleet"]) >= 1 and int(c["fleet"]) <= CrewData.FLEET_MAX, id + " fleet in bounds")
		for reg: String in c["influence"]:
			assert_true(float(c["influence"][reg]) <= CrewData.INFLUENCE_MAX, id + " influence capped")
	assert_true(PirateCrews.root(s)["news"].size() <= CrewData.NEWS_KEEP, "news is trimmed")


func test_the_same_seed_plays_the_same_sixty_days() -> void:
	var a: Dictionary = _state()
	var b: Dictionary = _state()
	var ra: RandomNumberGenerator = _rng(3)
	var rb: RandomNumberGenerator = _rng(3)
	for d in 60:
		a["day"] = d
		b["day"] = d
		PirateCrews.day_tick(a, ra)
		PirateCrews.day_tick(b, rb)
	assert_eq(JSON.stringify(a["crews"]), JSON.stringify(b["crews"]), "deterministic")


func test_raids_claims_expansion_and_hunts() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(2)
	var c: Dictionary = PirateCrews.get_crew(s, "red_hand")
	var g0: int = int(c["gold"])
	var n: Dictionary = PirateCrews.act(s, "red_hand", "raid_trade", r)
	assert_eq(n["key"], "pcrew.news.raid_trade")
	assert_true(int(c["gold"]) > g0 and int(c["raids"]) == 1, "a trade raid pays")
	n = PirateCrews.act(s, "bone_tide", "raid_port", r)
	assert_eq(n["key"], "pcrew.news.raid_port")
	assert_true((s["port_damage"] as Dictionary).has(n["args"][1]), "the raided port is damaged")
	n = PirateCrews.act(s, "black_gulls", "claim_island", r)
	assert_eq(n["key"], "pcrew.news.claim")
	var isl: String = n["args"][1]
	assert_eq(PirateCrews.root(s)["claims"][isl]["crew"], "black_gulls")
	var idx: int = PortData.gen().index_of(isl)
	assert_eq(str(PortData.gen().islands[idx]["city"]), "", "only islands without a town are claimed")
	var inf0: float = 0.0
	for reg: String in PirateCrews.get_crew(s, "sea_wolves")["influence"]:
		inf0 += PirateCrews.influence(s, "sea_wolves", reg)
	PirateCrews.act(s, "sea_wolves", "expand", r)
	var inf1: float = 0.0
	for reg: String in PirateCrews.get_crew(s, "sea_wolves")["influence"]:
		inf1 += PirateCrews.influence(s, "sea_wolves", reg)
	assert_true(inf1 > inf0, "expansion grows the crew's hold")
	var gr: float = float(PirateCrews.get_crew(s, "sea_wolves")["grudge"])
	PirateCrews.act(s, "sea_wolves", "hunt", r)
	assert_near(float(PirateCrews.get_crew(s, "sea_wolves")["grudge"]), gr + CrewData.GRUDGE_HUNT, 0.01)


func test_a_crew_holds_at_most_three_islands() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(4)
	for i in 10:
		PirateCrews.act(s, "black_gulls", "claim_island", r)
	var mine: int = 0
	for isl in PirateCrews.root(s)["claims"]:
		if PirateCrews.root(s)["claims"][isl]["crew"] == "black_gulls":
			mine += 1
	assert_eq(mine, CrewData.CLAIMS_PER_CREW)


func test_warbands_come_only_where_the_crew_holds_water_and_hunters_come_more() -> void:
	var s: Dictionary = _state()
	assert_eq(PirateCrews.warband_chance(s, "red_hand", "coral_isles"), 0.0, "no Red Hand in the Coral Isles")
	var home: float = PirateCrews.warband_chance(s, "red_hand", "merchants_reach")
	assert_true(home > 0.0, "the Red Hand sails its home waters")
	PirateCrews.get_crew(s, "red_hand")["grudge"] = 100.0
	assert_true(PirateCrews.warband_chance(s, "red_hand", "merchants_reach") > home, "a grudge brings them more often")
	var c: Dictionary = PirateCrews.get_crew(s, "red_hand")
	var wolves: Dictionary = PirateCrews.get_crew(s, "sea_wolves")
	wolves["grudge"] = c["grudge"]
	wolves["influence"]["merchants_reach"] = c["influence"]["merchants_reach"]
	assert_true(PirateCrews.warband_chance(s, "sea_wolves", "merchants_reach") > PirateCrews.warband_chance(s, "red_hand", "merchants_reach"), "hunters come more")
	assert_eq(PirateCrews.warband_size(s, "red_hand"), 3)
	c["fleet"] = 1
	assert_eq(PirateCrews.warband_size(s, "red_hand"), 1, "never more ships than the fleet")


func test_beating_their_ships_weakens_them_and_the_flagship_ends_them() -> void:
	var s: Dictionary = _state()
	var c: Dictionary = PirateCrews.get_crew(s, "bone_tide")
	var f0: int = int(c["fleet"])
	var inf0: float = PirateCrews.influence(s, "bone_tide", "iron_marches")
	var out: Dictionary = PirateCrews.ship_beaten(s, "bone_tide", "iron_marches")
	assert_true(not bool(out["eliminated"]))
	assert_eq(int(c["fleet"]), f0 - 1)
	assert_true(PirateCrews.influence(s, "bone_tide", "iron_marches") < inf0, "they lose their hold")
	assert_true(bool(c["lagoon_known"]), "a prisoner gives away the lagoon")
	assert_eq(int(PirateCrews.root(s)["player_renown"]), CrewData.WIN_RENOWN)
	var g0: int = int(s["gold"])
	out = PirateCrews.ship_beaten(s, "bone_tide", "iron_marches", true)
	assert_true(bool(out["eliminated"]), "the flagship ends the crew")
	assert_true(int(s["gold"]) - g0 >= CrewData.ELIMINATE_GOLD, "their chest is paid")
	assert_true(not PirateCrews.alive_ids(s).has("bone_tide"))
	assert_eq(PirateCrews.warband_chance(s, "bone_tide", "iron_marches"), 0.0, "a finished crew sends nobody")
	assert_eq(PirateCrews.owner_of(s, "iron_marches"), "", "their water is free")


func test_a_crew_that_beats_you_takes_gold_and_treasure_hunters_take_a_map() -> void:
	var s: Dictionary = _state()
	s["map_fragments"] = ["drowned_purse_1", "drowned_purse_2"]
	var out: Dictionary = PirateCrews.beat_player(s, "red_hand")
	assert_eq(int(out["gold"]), 2500)
	assert_eq(int(s["gold"]), 7500)
	assert_eq(out["fragment"], "", "raiders leave the maps")
	out = PirateCrews.beat_player(s, "black_gulls")
	assert_eq(out["fragment"], "drowned_purse_2", "the Gulls take a map")
	assert_eq((s["map_fragments"] as Array).size(), 1)
	assert_eq(PirateCrews.take_back_map(s, "black_gulls"), "drowned_purse_2", "beating them brings it back")
	assert_eq((s["map_fragments"] as Array).size(), 2)
	s["gold"] = 1000000
	assert_eq(int(PirateCrews.beat_player(s, "sea_wolves")["gold"]), CrewData.PLUNDER_GOLD_CAP, "the take is capped")


func test_eliminating_the_gulls_returns_every_stolen_map() -> void:
	var s: Dictionary = _state()
	s["map_fragments"] = ["drowned_purse_1"]
	PirateCrews.beat_player(s, "black_gulls")
	assert_true((s["map_fragments"] as Array).is_empty())
	PirateCrews.eliminate(s, "black_gulls")
	assert_true((s["map_fragments"] as Array).has("drowned_purse_1"))


func test_raiders_sail_for_the_players_lagoon_and_take_a_share() -> void:
	var s: Dictionary = _state()
	s["lagoon"] = {"name": "Skull Cove", "pos": [100.0, 200.0], "gold": 1000}
	assert_eq(PirateCrews.holdings(s).size(), 1)
	var plain: Dictionary = _state()
	assert_true(PirateCrews.holdings(plain).is_empty(), "no lagoon, nothing to raid")
	plain["lagoon"] = {"rank": 1}
	var hs: Array[Dictionary] = PirateCrews.holdings(plain)
	assert_eq(hs.size(), 1, "a claimed lagoon without a position is on Skull Atoll")
	assert_true((hs[0]["pos"] as Vector2) != Vector2.ZERO, "Skull Atoll found")
	PirateCrews.get_crew(s, "bone_tide")["grudge"] = 50.0
	var n: Dictionary = PirateCrews.act(s, "bone_tide", "raid_port", _rng())
	assert_eq(n["key"], "pcrew.news.threat", "a crew with a grudge goes for the lagoon")
	assert_eq(PirateCrews.resolve_threats(s, 1.0).size(), 0, "not there yet")
	var made: Array[Dictionary] = PirateCrews.resolve_threats(s, CrewData.HOLDING_RAID_HOURS + 9.0 + 1.0)
	assert_eq(made.size(), 1)
	assert_eq(int(s["lagoon"]["gold"]), 850, "15% of the store is gone")
	PirateCrews.act(s, "bone_tide", "raid_port", _rng())
	PirateCrews.ship_beaten(s, "bone_tide", "")
	assert_true((PirateCrews.root(s)["threats"] as Array).is_empty(), "beating their raiders calls the raid off")


func test_league_ranks_the_player_and_crowns_a_king_once() -> void:
	var s: Dictionary = _state()
	assert_eq(PirateCrews.player_rank(s), 5)
	PirateCrews.root(s)["player_renown"] = 500
	assert_eq(PirateCrews.player_rank(s), 1)
	var made: Array[Dictionary] = PirateCrews.day_tick(s, _rng())
	var kings: int = 0
	for n in made:
		if n["key"] == "pcrew.news.king":
			kings += 1
	assert_eq(kings, 1)
	made = PirateCrews.day_tick(s, _rng())
	for n in made:
		assert_true(n["key"] != "pcrew.news.king", "only once")


func test_news_reads_in_words() -> void:
	var s: Dictionary = _state()
	var n: Dictionary = PirateCrews.act(s, "red_hand", "raid_trade", _rng())
	var t: String = PirateCrews.news_text(n)
	assert_true(t.contains("The Red Hand") and not t.contains("merchants_reach"), t)
	PirateCrews.beat_player(s, "red_hand")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(PirateCrews.root(s)["news"].back()))
	t = PirateCrews.news_text(saved)
	assert_true(t.contains("2500"), "numbers survive a save: " + t)


func test_crew_deck_men_are_sharper_but_not_tougher() -> void:
	var s: Dictionary = _state()
	var plain: DeckCombat = DeckBridge.build(14, 1.0, 70.0, "pirate", 14, 1.0, 70.0, s, 3)
	var crew: DeckCombat = DeckBridge.build(14, 1.0, 70.0, CrewData.faction_of("sea_wolves"), 14, 1.0, 70.0, s, 3)
	var pp: float = 0.0
	var cp: float = 0.0
	for f in plain.fighters:
		if f.team == 1:
			pp += f.parry_skill
	for f in crew.fighters:
		if f.team == 1:
			cp += f.parry_skill
			assert_true(not f.panics, "crew men never run")
	assert_true(cp > pp, "crew men parry more")
	var roster: Dictionary = CrewDeck.roster("sea_wolves", 30, true)
	assert_eq(roster["fighters"][0], "captain", "the flagship brings the captain")
	assert_eq(int(roster["reserve"]), 30 - DeckData.MAX_ON_SCREEN)


func test_crew_fights_cost_more_men_than_plain_pirates() -> void:
	var s: Dictionary = _state()
	var lost_plain: int = 0
	var lost_crew: int = 0
	for seed_value in 6:
		lost_plain += 13 - int(_fight(s, "pirate", seed_value)["crew_left"])
		lost_crew += 13 - int(_fight(s, CrewData.faction_of("bone_tide"), seed_value)["crew_left"])
	assert_true(lost_crew > lost_plain, "crews are harder (%d v %d men lost)" % [lost_crew, lost_plain])


func _fight(s: Dictionary, faction: String, seed_value: int) -> Dictionary:
	var c: DeckCombat = DeckBridge.build(14, 1.0, 70.0, faction, 12, 1.0, 70.0, s, 100 + seed_value)
	var guard: int = 0
	while c.outcome == DeckCombat.Outcome.ONGOING and guard < 30 * 400:
		DeckBridge.autopilot(c, 1.0 / 30.0)
		c.tick(1.0 / 30.0)
		guard += 1
	return c.result()


func test_old_save_gets_fresh_crews() -> void:
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 12
	old.erase("crews")
	var d: Dictionary = SaveGame.from_json(JSON.stringify(old))
	assert_eq(int(d["version"]), SaveGame.VERSION)
	assert_eq(PirateCrews.alive_ids(d).size(), 4)
