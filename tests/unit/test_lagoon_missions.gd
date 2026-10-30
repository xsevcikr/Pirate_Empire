extends TestCase


func _claimed(pop: int = 10, gold: int = 200000) -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = gold
	s["ship_class"] = "sloop"
	s["fame"] = 99999
	Lagoon.claim(s)
	Lagoon.place(s, "hut", Vector2i(1, 0))
	Lagoon.place(s, "hut", Vector2i(-1, 0))
	Lagoon.place(s, "hut", Vector2i(0, 1))
	Lagoon.data(s)["pop"] = pop
	return s


func _rng(seed_v: int = 3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


func test_send_takes_residents_away_and_holds_their_beds() -> void:
	var s: Dictionary = _claimed(10)
	assert_eq(LagoonMissions.send_problem(s, "fishing"), "")
	assert_true(LagoonMissions.send(s, "fishing"))
	assert_eq(int(Lagoon.data(s)["pop"]), 7)
	assert_eq(LagoonMissions.away(s), 3)
	assert_eq(LagoonMissions.send_problem(s, "wreck_dive"), "slots", "a hideout runs one party at a time")
	# while they are away nobody new takes their beds
	var beds: int = Lagoon.beds(s)
	for i in 10:
		Lagoon.daily(s, _rng(i))
	assert_true(int(Lagoon.data(s)["pop"]) + LagoonMissions.away(s) <= beds)


func test_refusals() -> void:
	var s: Dictionary = _claimed(2)
	assert_eq(LagoonMissions.send_problem(s, "fishing"), "crew")
	assert_eq(LagoonMissions.send_problem(s, "smuggling"), "rank")
	assert_eq(LagoonMissions.send_problem(SaveGame.new_state(), "fishing"), "unclaimed")
	assert_true(not LagoonMissions.send(s, "fishing"))


func test_party_comes_home_on_its_day_with_gold() -> void:
	var s: Dictionary = _claimed(10)
	s["day"] = 4
	LagoonMissions.send(s, "fishing")
	assert_eq(LagoonMissions.daily(s, _rng()).size(), 0, "not back the same day")
	s["day"] = 5
	var gold: int = int(s["gold"])
	var back: Array[Dictionary] = LagoonMissions.daily(s, _rng())
	assert_eq(back.size(), 1)
	assert_true(LagoonMissions.active(s).is_empty())
	assert_eq(LagoonMissions.away(s), 0)
	var e: Dictionary = back[0]
	assert_eq(int(s["gold"]), gold + int(e["gold"]), "the share goes into the purse")
	assert_eq(int(Lagoon.data(s)["pop"]), 7 + int(e["alive"]))
	assert_eq(LagoonMissions.log_of(s)[0], e)
	assert_true(LagoonMissions.report(e) != "")


func test_outcomes_over_many_runs() -> void:
	var lost: int = 0
	var dead: int = 0
	var paid: int = 0
	var rng := _rng(11)
	for i in 400:
		var s: Dictionary = _claimed(30)
		Lagoon.data(s)["rank"] = 3
		LagoonMissions.send(s, "fort_raid")
		s["day"] = 6
		var e: Dictionary = LagoonMissions.daily(s, rng)[0]
		if int(e["alive"]) == 0:
			lost += 1
			assert_eq(int(e["gold"]), 0)
		else:
			dead += int(e["sent"]) - int(e["alive"])
			paid += int(e["gold"])
			assert_true(int(e["gold"]) <= 9000)
	assert_true(lost > 10 and lost < 100, "storming a fort sometimes loses the whole party (%d)" % lost)
	assert_true(dead > 0, "and costs lives")
	assert_true(paid > 0)


func test_morale_makes_missions_safer() -> void:
	var s: Dictionary = _claimed(10)
	var before: float = LagoonMissions.risk(s, "merchant_raid")
	Lagoon.place(s, "statue", Vector2i(1, 1))
	Lagoon.place(s, "tavern", Vector2i(-1, 1))
	assert_true(LagoonMissions.risk(s, "merchant_raid") < before)


func test_rank_opens_more_parties() -> void:
	var s: Dictionary = _claimed(14)
	Lagoon.data(s)["rank"] = 1
	assert_eq(LagoonMissions.slots(s), 2)
	assert_true(LagoonMissions.send(s, "fishing"))
	assert_true(LagoonMissions.send(s, "wreck_dive"))
	assert_eq(LagoonMissions.send_problem(s, "merchant_raid"), "slots")


func test_housing_adds_beds_and_needs_rank() -> void:
	var s: Dictionary = _claimed(0)
	var beds: int = Lagoon.beds(s)
	assert_true(Lagoon.expand_housing(s))
	assert_eq(Lagoon.beds(s), beds + int(LagoonData.HOUSING["beds"][0]))
	assert_true(not Lagoon.expand_housing(s), "level 2 needs the cove")
	Lagoon.data(s)["rank"] = 1
	assert_true(Lagoon.expand_housing(s))
	assert_eq(Lagoon.housing_level(s), 2)


func test_old_lagoon_without_new_fields_still_works() -> void:
	var s: Dictionary = _claimed(10)
	var l: Dictionary = Lagoon.data(s)
	for k in ["housing", "away", "missions", "mission_log"]:
		l.erase(k)
	assert_eq(LagoonMissions.away(s), 0)
	assert_true(LagoonMissions.send(s, "fishing"))
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(LagoonMissions.away(back), 3)
	assert_eq(typeof(Lagoon.data(back)["missions"][0]["back"]), TYPE_INT)


func test_office_catalogue_lists_upgrades_lagoon_and_missions() -> void:
	var s: Dictionary = _claimed(10)
	var src := HarbourOfficeCatalogue.new()
	var items: Array[CatalogueItem] = src.items(s)
	var by_cat: Dictionary = {}
	for it in items:
		by_cat[it.category] = int(by_cat.get(it.category, 0)) + 1
		assert_true(src.categories().has(it.category), "%s sits under a tab" % it.id)
	assert_eq(int(by_cat["cat.upgrades"]), Upgrades.BASE_COST.size())
	assert_true(by_cat.has("office.lagoon") and by_cat.has("office.missions"))
	var fishing: CatalogueItem = null
	var house: CatalogueItem = null
	for it in items:
		if it.id == "mission:fishing":
			fishing = it
		if it.id == "office:housing":
			house = it
	assert_true(fishing.can_buy(int(s["gold"])))
	assert_true(src.buy(s, fishing))
	assert_true(LagoonMissions.is_out(s, "fishing"))
	assert_true(src.buy(s, house))
	assert_eq(Lagoon.housing_level(s), 1)
	var upg: CatalogueItem = null
	for it in src.items(s):
		if it.id == "upg:hull":
			upg = it
	var gold: int = int(s["gold"])
	assert_true(src.buy(s, upg))
	assert_true(int(s["gold"]) < gold)
	assert_eq(int(s["upgrades"]["hull"]), 1)
