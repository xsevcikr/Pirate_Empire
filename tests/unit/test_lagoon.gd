extends TestCase


func _state(gold: int = 200000) -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = gold
	s["ship_class"] = "sloop"
	s["crew"] = 20
	s["fame"] = 99999
	return s


func _claimed(gold: int = 200000) -> Dictionary:
	var s: Dictionary = _state(gold)
	Lagoon.claim(s)
	return s


func _rng(seed_v: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


func test_claim_costs_gold_once() -> void:
	var s: Dictionary = _state(LagoonData.CLAIM_COST - 1)
	assert_true(not (Lagoon.claim(s)), "too poor to claim")
	s["gold"] = LagoonData.CLAIM_COST + 10
	assert_true(Lagoon.claim(s))
	assert_eq(int(s["gold"]), 10)
	assert_true(not (Lagoon.claim(s)), "claimed only once")
	assert_eq(Lagoon.rank_of(s), 0)


func test_skull_atoll_is_uninhabited_and_near_home() -> void:
	var isl: Dictionary = LagoonData.island()
	assert_eq(isl["city"], "", "the lagoon island has no town of its own")
	assert_true((isl["pos"] as Vector2).length() < 2500.0, "a short sail from Haven Rock")
	assert_eq(PortData.port_near(LagoonData.dock_point(), LagoonData.DOCK_RADIUS_M + 50.0), "", "no port dock zone overlaps the lagoon's")
	assert_true(not (PortData.gen().is_land(LagoonData.dock_point())), "the landing point is in the water")


func test_plots_grow_with_rank() -> void:
	var last: int = 0
	for r in LagoonData.RANKS.size():
		var n: int = LagoonData.cells(r).size()
		assert_true(n > last, "rank %d opens more plots (%d)" % [r, n])
		last = n
	assert_true(not (LagoonData.cell_open(0, Vector2i.ZERO)), "the centre is the captain's hall")
	assert_true(not (LagoonData.cell_open(0, Vector2i(3, 0))))
	assert_true(LagoonData.cell_open(1, Vector2i(3, 0)))


func test_cells_round_trip_through_island_space() -> void:
	for c in LagoonData.cells(3):
		assert_eq(LagoonData.cell_at(LagoonData.cell_local(c)), c)
		assert_true(LagoonData.cell_local(c).distance_to(LagoonData.pad_center()) < LagoonData.PAD_RADIUS_M, "plot %s is on the levelled ground" % c)


func test_place_upgrade_demolish() -> void:
	var s: Dictionary = _claimed(5000)
	var c := Vector2i(1, 0)
	var g: int = int(s["gold"])
	assert_true(Lagoon.place(s, "hut", c))
	assert_eq(int(s["gold"]), g - LagoonData.cost("hut", 1))
	assert_true(not (Lagoon.place(s, "tavern", c)), "plot taken")
	assert_eq(Lagoon.place_problem(s, "hut", Vector2i(4, 0)), "closed")
	assert_eq(Lagoon.upgrade_cost(s, c), LagoonData.cost("hut", 2))
	assert_true(Lagoon.upgrade(s, c))
	assert_eq(int(Lagoon.building_at(s, c)["lv"]), 2)
	assert_eq(Lagoon.beds(s), 8)
	Lagoon.rotate(s, c)
	assert_eq(int(Lagoon.building_at(s, c)["rot"]), 1)
	var refund: int = Lagoon.demolish(s, c)
	assert_eq(refund, int((LagoonData.cost("hut", 1) + LagoonData.cost("hut", 2)) * 0.5))
	assert_true(Lagoon.building_at(s, c).is_empty())


func test_residents_move_in_and_pay_tribute() -> void:
	var s: Dictionary = _claimed()
	Lagoon.place(s, "hut", Vector2i(1, 0))
	Lagoon.place(s, "hut", Vector2i(-1, 0))
	Lagoon.place(s, "market", Vector2i(0, 1))
	for d in 3:
		Lagoon.daily(s, _rng(d))
	assert_eq(int(Lagoon.data(s)["pop"]), 3, "one pirate moves in a day without a tavern")
	Lagoon.place(s, "tavern", Vector2i(0, -1))
	Lagoon.daily(s, _rng())
	assert_eq(int(Lagoon.data(s)["pop"]), 5, "a tavern draws them faster")
	for d in 10:
		Lagoon.daily(s, _rng(d))
	assert_eq(int(Lagoon.data(s)["pop"]), Lagoon.beds(s), "never more than the beds")
	var expect: float = 60.0 + 30.0 + 8.0 * LagoonData.TRIBUTE_PER_RESIDENT
	assert_near(Lagoon.income_daily(s), expect, 0.01)


func test_chest_is_capped_and_warehouses_raise_it() -> void:
	var s: Dictionary = _claimed()
	Lagoon.place(s, "market", Vector2i(1, 0))
	Lagoon.upgrade(s, Vector2i(1, 0))
	Lagoon.upgrade(s, Vector2i(1, 0))
	for d in 30:
		Lagoon.daily(s, _rng(d))
	assert_near(float(Lagoon.data(s)["chest"]), LagoonData.CHEST_BASE, 0.01)
	Lagoon.place(s, "warehouse", Vector2i(-1, 0))
	assert_near(Lagoon.chest_cap(s), LagoonData.CHEST_BASE + 2000.0, 0.01)


func test_landing_collects_and_rests_once_a_day() -> void:
	var s: Dictionary = _claimed(10000)
	Lagoon.place(s, "tavern", Vector2i(1, 0))
	Lagoon.place(s, "farm", Vector2i(-1, 0))
	Lagoon.place(s, "shipyard", Vector2i(0, 1))
	Lagoon.data(s)["chest"] = 250.0
	Lagoon.data(s)["larder"] = 12.0
	s["morale"] = 50.0
	s["wounded"] = 3
	s["ship_hull"] = 0.5
	var g: int = int(s["gold"])
	var food: float = float(s["supplies"]["food"])
	var r: Dictionary = Lagoon.land(s, 4)
	assert_eq(int(r["gold"]), 250)
	assert_eq(int(s["gold"]), g + 250)
	assert_near(float(s["supplies"]["food"]), food + 12.0, 0.01)
	assert_near(float(s["morale"]), 54.0, 0.01)
	assert_eq(int(s["wounded"]), 2)
	assert_near(float(s["ship_hull"]), 0.75, 0.001)
	var again: Dictionary = Lagoon.land(s, 4)
	assert_near(float(again["morale"]), 0.0, 0.001, "the crew rests once a day")


func test_ranks_open_piers_and_berths_hold_the_fleet() -> void:
	var s: Dictionary = _claimed()
	assert_true(Lagoon.build_pier(s))
	assert_true(not (Lagoon.build_pier(s)), "a hideout has one pier")
	assert_true(Lagoon.rank_up(s))
	assert_true(Lagoon.build_pier(s))
	assert_eq(Lagoon.berths(s), 2)
	assert_true(Lagoon.upgrade_pier(s, 0))
	assert_eq(Lagoon.berths(s), 3)
	for i in 4:
		s["fleet"].append({"class": "sloop", "name": "S%d" % i, "crew": 0, "hull": 0.5})
	assert_eq(Lagoon.moored(s).size(), 3, "a ship without a berth waits at anchor")


func test_shipyard_lays_down_ships_into_free_berths() -> void:
	var s: Dictionary = _claimed()
	assert_eq(Lagoon.commission_problem(s, "sloop"), "yard")
	Lagoon.place(s, "shipyard", Vector2i(1, 0))
	var small: Array[String] = []
	for i in 3:
		small.append(PortData.CLASS_ORDER[i])
	assert_eq(Lagoon.commission_classes(s), small, "a first-level yard lays down the three smallest classes")
	var third: String = small[2]
	assert_eq(Lagoon.commission_problem(s, "sloop"), "berth")
	Lagoon.build_pier(s)
	var g: int = int(s["gold"])
	assert_true(Lagoon.commission(s, third, "Sea Wolf"))
	assert_eq(int(s["gold"]), g - PortService.ship_stats(third).price)
	assert_eq(Lagoon.class_of(s["fleet"][0]), third)
	assert_eq(Lagoon.commission_problem(s, "sloop"), "berth")
	Lagoon.upgrade(s, Vector2i(1, 0))
	assert_true(Lagoon.commission_classes(s).has(PortData.CLASS_ORDER[4]), "a second-level yard lays down bigger keels")


func test_take_command_swaps_the_flagship() -> void:
	var s: Dictionary = _claimed()
	s["fleet"].append({"class": "brigantine", "name": "Prize", "crew": 6, "hull": 0.8})
	s["ship_hull"] = 0.4
	assert_true(Lagoon.take_command(s, 0))
	assert_eq(s["ship_class"], "brigantine")
	assert_eq(s["ship_name"], "Prize")
	assert_near(float(s["ship_hull"]), 0.8, 0.001)
	assert_eq(int(s["crew"]), 26, "the prize crew joins")
	assert_eq(Lagoon.class_of(s["fleet"][0]), "sloop")
	assert_near(float(s["fleet"][0]["hull"]), 0.4, 0.001)


func test_sell_fleet_ship() -> void:
	var s: Dictionary = _claimed(0)
	s["fleet"].append({"class": "sloop", "name": "Old Tub", "crew": 0, "hull": 1.0})
	var g: int = Lagoon.sell_ship(s, 0)
	assert_eq(g, int(PortService.ship_stats("sloop").price * LagoonData.SELL_SHARE))
	assert_eq((s["fleet"] as Array).size(), 0)


func test_raids_need_rank_and_defence_wins() -> void:
	var s: Dictionary = _claimed()
	for d in 200:
		assert_eq(str(Lagoon.daily(s, _rng(d))["raid"]), "", "no raids on a hideout")
	Lagoon.rank_up(s)
	Lagoon.place(s, "market", Vector2i(1, 0))
	var lost: int = 0
	for d in 400:
		Lagoon.data(s)["chest"] = 1000.0
		var r: Dictionary = Lagoon.daily(s, _rng(d))
		if r["raid"] == "lost":
			lost += 1
			assert_true(int(r["lost_gold"]) > 0)
			break
	assert_eq(lost, 1, "an undefended cove is raided sooner or later")
	assert_true(bool(Lagoon.building_at(s, Vector2i(1, 0))["dmg"]), "the raid burns the market")
	assert_near(Lagoon.total(s, "income"), 0.0, 0.01, "a burnt market earns nothing")
	assert_true(Lagoon.repair(s, Vector2i(1, 0)))
	Lagoon.place(s, "battery", Vector2i(-1, 0))
	Lagoon.upgrade(s, Vector2i(-1, 0))
	assert_true(Lagoon.defence(s) >= Lagoon.raid_strength(s))
	for d in 400:
		var r2: Dictionary = Lagoon.daily(s, _rng(d))
		assert_true(r2["raid"] != "lost", "a defended cove holds")


func test_moored_ships_add_defence_and_mend() -> void:
	var s: Dictionary = _claimed()
	Lagoon.build_pier(s)
	Lagoon.place(s, "shipyard", Vector2i(1, 0))
	s["fleet"].append({"class": "brigantine", "name": "B", "crew": 0, "hull": 0.5})
	assert_near(Lagoon.defence(s), 9.0 * LagoonData.GUN_DEFENCE, 0.01)
	Lagoon.daily(s, _rng())
	assert_near(float(s["fleet"][0]["hull"]), 0.6, 0.001)


func test_save_round_trip_and_migration() -> void:
	var s: Dictionary = _claimed()
	Lagoon.place(s, "hut", Vector2i(1, -1), 2)
	Lagoon.build_pier(s)
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(back["lagoon"], s["lagoon"])
	assert_eq(typeof(back["lagoon"]["buildings"][0]["x"]), TYPE_INT)
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 12
	old.erase("lagoon")
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(int(m["version"]), SaveGame.VERSION)
	assert_true(not (Lagoon.claimed(m)), "an old save starts with the atoll unclaimed")


func test_every_building_has_strings_and_levels() -> void:
	for t in LagoonData.ORDER:
		assert_true(LagoonData.BUILDINGS.has(t))
		assert_true(Loc.t("lagoon.b_" + t) != "lagoon.b_" + t, "name for " + t)
		assert_true(Loc.t("lagoon.d_" + t) != "lagoon.d_" + t, "description for " + t)
	assert_eq(LagoonData.ORDER.size(), LagoonData.BUILDINGS.size())


func test_art_builds_every_level() -> void:
	for t in LagoonData.ORDER:
		for lv in range(1, LagoonData.levels(t) + 1):
			var n: Node3D = LagoonArt.building(t, lv, 3, lv == 1)
			assert_true(Kenney.meshes_of(n).size() > 0, "%s level %d has a model" % [t, lv])
			n.free()
	for r in LagoonData.RANKS.size():
		var h: Node3D = LagoonArt.hall(r, 1)
		assert_true(Kenney.meshes_of(h).size() > 0)
		h.free()
	var p: Node3D = LagoonArt.pier(3)
	assert_true(Kenney.meshes_of(p).size() > 10)
	p.free()
	var sh: Node3D = LagoonArt.moored_ship("galleon")
	assert_true(Kenney.meshes_of(sh).size() > 0)
	sh.free()
