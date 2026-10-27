extends TestCase


func _rng(s: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_every_boss_changes_phase_at_its_thresholds() -> void:
	for id: String in Boss.DEFS.keys():
		var b := Boss.new(id, 1)
		var th: Array = Boss.DEFS[id]["thresholds"]
		b.untargetable = false
		for i in range(1, th.size()):
			b.hp = b.max_hp * (float(th[i]) + 0.01)
			b.damage(0.0, true)
			b.hp = b.max_hp * float(th[i])
			b.damage(0.001, true)
			assert_true(b.phase >= i or id == "ghost_admiral", "%s phase %d at %f" % [id, i, th[i]])


func test_every_boss_telegraphs_two_seconds_ahead() -> void:
	for id: String in Boss.DEFS.keys():
		var b := Boss.new(id, 1)
		var guard: int = 0
		while b.telegraph_left_s <= 0.0 and guard < 400:
			b.tick(0.1)
			guard += 1
		assert_true(b.special_pending != "", id)
		assert_near(b.telegraph_left_s, Boss.TELEGRAPH_S, 0.11, id)


func test_bosses_heal_20_percent_a_minute_outside_the_arena() -> void:
	for id in BossArena.ids():
		if not Boss.DEFS.has(id):
			continue
		var b := Boss.new(id, 1)
		b.hp = b.max_hp * 0.5
		var far: Vector2 = BossArena.centre(id) + Vector2(50000.0, 0.0)
		BossArena.tick(id, b, far, 60.0)
		assert_near(b.hp, b.max_hp * 0.7, 1.0, id)
		BossArena.tick(id, b, BossArena.centre(id), 1.0)
		assert_true(b.in_arena, id)


func test_every_boss_arena_is_on_a_real_island() -> void:
	for id in BossArena.ids():
		assert_true(PortData.gen().index_of(BossArena.ARENAS[id]["island"]) >= 0, id)


func test_every_guardian_falls_to_perfect_play() -> void:
	for m: String in ["valcourt", "ghost_admiral", "brass_colossus", "ice_leviathan", "kraken", "black_ibrahim"]:
		var f := MonsterFight.new(m, 1)
		assert_true(f.autoplay(900.0), m + " falls")
		assert_true(f.player_hp > 0.0, m)


func test_ghost_admiral_needs_lanterns_shot() -> void:
	var f := MonsterFight.new("ghost_admiral", 1)
	assert_true(f.boss.untargetable)
	assert_near(f.strike(100.0, "round"), 0.0, 0.001, "untargetable in phase one")
	assert_true(f.shoot_lantern() and f.shoot_lantern())
	assert_true(not f.boss.untargetable)
	assert_true(f.strike(100.0) > 0.0)
	assert_true(TourHazards.ghost_hit("heated") and TourHazards.ghost_hit("blessed") and not TourHazards.ghost_hit("round"))


func test_kraken_head_only_after_all_eight_tentacles() -> void:
	var f := MonsterFight.new("kraken", 1)
	for i in 8:
		assert_near(f.strike(150.0), 0.0, 0.001)
	assert_eq(f.tentacles_left, 0)
	assert_true(f.is_exposed())
	assert_true(f.strike(100.0) > 0.0)


func test_hazard_rules() -> void:
	assert_true(TourHazards.moonlit(22.0) and TourHazards.moonlit(2.0) and not TourHazards.moonlit(12.0))
	assert_near(TourHazards.ghost_storm_damage(60.0), 450.0, 0.001)
	assert_true(TourHazards.patrol_sees(Vector2.ZERO, Vector2(500, 0), false))
	assert_true(not TourHazards.patrol_sees(Vector2.ZERO, Vector2(500, 0), true))
	var c := Vector2(1000, 1000)
	assert_true(TourHazards.whirlpool(c + Vector2(500, 0), c) != Vector2.ZERO)
	assert_eq(TourHazards.whirlpool(c + Vector2(5000, 0), c), Vector2.ZERO)
	assert_true(TourHazards.in_whirl_core(c + Vector2(100, 0), c))
	var bergs: Array[Dictionary] = TourHazards.icebergs(c, _rng(2))
	assert_eq(bergs.size(), TourHazards.BERG_COUNT)
	assert_true(TourHazards.berg_hit(bergs[0]["pos"], 5.0, bergs))
	assert_true(not TourHazards.berg_hit(c, 20.0, bergs), "the arrival point is clear")


func test_new_puzzles_solve_with_hints_on_every_seed() -> void:
	for k: String in ["bells", "vents", "cart", "ice", "sluice", "mirrors", "rhyme"]:
		for seed_v in 40:
			var p := DungeonPuzzle.new(k, _rng(seed_v))
			p.solve_with_hints()
			assert_true(p.solved, "%s seed %d" % [k, seed_v])
		for lv in range(1, 4):
			assert_true(Loc.t("puzzle.hint%d.%s" % [lv, k]) != "puzzle.hint%d.%s" % [lv, k], k)


func test_vent_burns_when_opened_early_and_cycle_is_3_in_6() -> void:
	var p := DungeonPuzzle.new("vents", _rng(1))
	assert_true(p.vent_open(0))
	assert_true(not p.press(0))
	assert_eq(p.burns, 1)
	p.tick(3.1)
	assert_true(not p.vent_open(0))
	assert_true(p.press(0))


func test_ice_floor_is_always_solvable_and_slides_to_walls() -> void:
	for seed_v in 60:
		var p := DungeonPuzzle.new("ice", _rng(seed_v))
		assert_true(not p.solution.is_empty(), "seed %d" % seed_v)
		assert_true(p.solution.size() >= 3)
		for d in p.solution:
			p.press(d)
		assert_true(p.solved)


func test_all_six_tours_are_well_formed() -> void:
	assert_eq(TourData.tour_ids().size(), 6)
	assert_true(TourState.hint_paths_complete())
	var old: String = Loc.locale
	Loc.locale = "cs"
	assert_true(TourState.hint_paths_complete(), "czech")
	Loc.locale = old
	var g: WorldGen = PortData.gen()
	for id: String in TourData.tour_ids():
		for s: Dictionary in TourData.steps(id):
			assert_true(g.index_of(s["island"]) >= 0, "%s: %s" % [id, s["island"]])
			if s["kind"] == "dungeon":
				assert_true(TourData.DUNGEONS.has(s["dungeon"]))
				var n: int = TourData.DUNGEONS[s["dungeon"]]["rooms"].size()
				assert_true(n >= 3 and n <= 6, s["dungeon"])
			if s["kind"] == "guardian":
				assert_true(TourData.MONSTERS.has(s["monster"]) or TourData.MONSTERS_BIG.has(s["monster"]))
				assert_true(BossArena.ARENAS.has(s["monster"]), s["monster"])


func test_kraken_needs_the_other_five_tours() -> void:
	var s: Dictionary = SaveGame.new_state()
	assert_true(not TourState.available(s, "krakens_maw"))
	assert_true(MapFragments.next_missing(s).begins_with("drowned_purse"))
	for id in ["drowned_purse", "song_of_sirens", "ghost_ledger", "iron_heart"]:
		TourState.finish(s, id)
	assert_true(not TourState.available(s, "krakens_maw"))
	TourState.finish(s, "frostmourn_vault")
	assert_true(TourState.available(s, "krakens_maw"))
	for id in TourData.tour_ids():
		TourState.finish(s, id)
	assert_eq(MapFragments.next_missing(s), "")


func test_rewards_are_granted_once() -> void:
	var s: Dictionary = SaveGame.new_state()
	var g0: int = int(s["gold"])
	TourState.finish(s, "ghost_ledger")
	TourState.finish(s, "ghost_ledger")
	assert_eq(int(s["gold"]) - g0, 10000)
	assert_true(LegendaryShips.owned(s).has("revenant"))
	TourState.finish(s, "iron_heart")
	assert_eq(int(s["ammo"]["explosive"]), 40)
	assert_eq(int(s["upgrades"]["armor"]), 5)
	TourState.finish(s, "frostmourn_vault")
	assert_near(TourRewards.storm_mast_factor(s), 0.0, 0.0001)
	assert_true(TourRewards.boss_defeated(s, "valcourt").has("ship_sovereign"))
	assert_true(TourRewards.boss_defeated(s, "valcourt").is_empty(), "the Sovereign is given once")
	assert_true(LegendaryShips.owned(s).has("sovereign"))
	TourState.finish(s, "krakens_maw")
	assert_true(TourRewards.has(s, "unlock_black_ibrahim") and TourRewards.has(s, "heart_of_the_deep") and TourRewards.has(s, "kraken_ink"))


func test_legendary_ships_load_and_swap() -> void:
	for id: String in ["revenant", "sovereign"]:
		var st: ShipStats = PortService.ship_stats(id)
		assert_eq(st.class_id, id)
		assert_true(st.hull_hp > 0.0 and st.max_speed_kn > 0.0 and st.guns_per_side > 0)
		assert_true(Upgrades.CLASS_MULT.has(id))
	assert_true(PortService.ship_stats("revenant").max_speed_kn > PortService.ship_stats("frigate").max_speed_kn)
	assert_true(PortService.ship_stats("sovereign").hull_hp > PortService.ship_stats("man_o_war").hull_hp)
	var s: Dictionary = SaveGame.new_state()
	assert_true(not LegendaryShips.take_helm(s, "revenant"), "not owned yet")
	TourState.finish(s, "ghost_ledger")
	assert_true(LegendaryShips.take_helm(s, "revenant"))
	assert_eq(s["ship_class"], "revenant")
	assert_eq(s["fleet"].size(), 1)
	assert_true(not LegendaryShips.take_helm(s, "revenant"))


func test_random_treasure_maps() -> void:
	var s: Dictionary = SaveGame.new_state()
	var g: WorldGen = PortData.gen()
	for seed_v in 120:
		var id: String = TreasureMapGen.generate(s, _rng(seed_v))
		var t: Dictionary = TourData.tour(id)
		var gold: int = int(t["reward"]["gold"])
		assert_true(gold >= 1000 and gold <= 8000, "reward %d" % gold)
		var hz: Array[String] = []
		for st: Dictionary in t["steps"]:
			assert_true(g.index_of(st["island"]) >= 0)
			if st.has("hazard"):
				hz.append(st["hazard"])
			if st["kind"] == "dungeon":
				var n: int = (st["rooms"] as Array).size()
				assert_true(n >= 3 and n <= 6, "rooms %d" % n)
				var run := Dungeon.new("generated", seed_v, 100.0, st["rooms"])
				run.autowalk()
				assert_true(run.is_done(), "generated dungeon %d can be walked" % seed_v)
		assert_eq(hz.size(), 2)
		assert_true(hz[0] != hz[1])
		assert_true(MapFragments.owned(s, id) == 3)
		assert_true(TourState.active(s).has(id))
	assert_eq(TourData.EXTRA.size(), 120)
	TourData.EXTRA.clear()
	TourData.restore(s)
	assert_eq(TourData.EXTRA.size(), 120, "restored from the save")
	TourData.EXTRA.clear()


func test_moonlit_clue_and_night_sail() -> void:
	var s: Dictionary = SaveGame.new_state()
	for n in 3:
		MapFragments.add(s, TourData.fragment_id("ghost_ledger", n + 1))
	var t: Array[int] = [0, 0, 0]
	assert_true(not TourState.read_map(s, "ghost_ledger", t, 12.0), "unreadable by day")
	assert_true(TourState.read_map(s, "ghost_ledger", t, 23.0))
	var step: Dictionary = TourData.steps("ghost_ledger")[1]
	var at: Vector2 = TourData.step_pos(step)
	assert_true(not TourState.arrived(step, at, 12.0, 0.0))
	assert_true(TourState.arrived(step, at, 23.0, 0.0))
