extends TestCase


func _rng(s: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _state() -> Dictionary:
	return SaveGame.new_state()


func test_drop_rates_match_the_table() -> void:
	var r: RandomNumberGenerator = _rng(21)
	var s: Dictionary = _state()
	for src: String in ["merchant", "pirate", "treasure_galleon"]:
		var hits: int = 0
		for i in 20000:
			if MapFragments.roll_drop(s, src, r) != "":
				hits += 1
		assert_near(float(hits) / 20000.0, float(TourData.DROP_RATE[src]), 0.012, src)
	assert_true(MapFragments.roll_drop(s, "rival", r) != "", "a rival always drops one")
	assert_eq(MapFragments.roll_drop(s, "navy", r), "", "navy ships carry none")


func test_fragments_go_to_the_first_unfinished_tour_and_count() -> void:
	var s: Dictionary = _state()
	assert_eq(MapFragments.next_missing(s), "drowned_purse_1")
	assert_true(MapFragments.add(s, "drowned_purse_1"))
	assert_true(not MapFragments.add(s, "drowned_purse_1"), "a piece counts once")
	MapFragments.add(s, "drowned_purse_2")
	assert_eq(MapFragments.owned(s, "drowned_purse"), 2)
	assert_eq(MapFragments.view_level(s, "drowned_purse"), 2)
	MapFragments.add(s, "drowned_purse_3")
	assert_eq(MapFragments.next_missing(s), "song_of_sirens_1")


func test_rotate_puzzle_scrambles_and_joins() -> void:
	for seed_v in 40:
		var t: Array[int] = MapFragments.scramble("drowned_purse", _rng(seed_v))
		assert_true(not MapFragments.is_joined(t), "never starts solved")
		var n: int = 0
		while not MapFragments.is_joined(t) and n < 20:
			MapFragments.rotate(t, MapFragments.next_piece(t))
			n += 1
		assert_true(MapFragments.is_joined(t) and n <= 9)


func test_reading_the_map_needs_three_pieces_and_a_joined_puzzle() -> void:
	var s: Dictionary = _state()
	var t: Array[int] = [0, 0, 0]
	assert_true(not TourState.read_map(s, "drowned_purse", t), "no pieces yet")
	for n in 3:
		MapFragments.add(s, TourData.fragment_id("drowned_purse", n + 1))
	var crooked: Array[int] = [0, 1, 0]
	assert_true(not TourState.read_map(s, "drowned_purse", crooked))
	assert_true(TourState.read_map(s, "drowned_purse", t))
	assert_eq(int(TourState.progress(s, "drowned_purse")["step"]), 1)


func test_arrival_needs_low_tide_and_dusk() -> void:
	var reef: Dictionary = TourData.steps("drowned_purse")[1]
	var at: Vector2 = TourData.step_pos(reef)
	assert_true(TourState.arrived(reef, at, 12.0, 0.0))
	assert_true(not TourState.arrived(reef, at, 12.0, 0.9), "high tide covers the reef")
	assert_true(not TourState.arrived(reef, at + Vector2(900, 0), 12.0, 0.0), "too far")
	var land: Dictionary = TourData.steps("drowned_purse")[2]
	assert_true(TourState.arrived(land, at, 18.0, 0.0))
	assert_true(not TourState.arrived(land, at, 11.0, 0.0), "not at dusk")


func test_paces_allow_three_either_way() -> void:
	var land: Dictionary = TourData.steps("drowned_purse")[2]
	assert_true(TourState.check_paces(land, 40))
	assert_true(TourState.check_paces(land, 37))
	assert_true(TourState.check_paces(land, 43))
	assert_true(not TourState.check_paces(land, 36))
	assert_true(not TourState.check_paces(land, 44))


func test_hint_levels_and_prices() -> void:
	var s: Dictionary = _state()
	s["gold"] = 1000
	for n in 3:
		MapFragments.add(s, TourData.fragment_id("drowned_purse", n + 1))
	var h1: Dictionary = TourState.hint(s, "drowned_purse", 1)
	assert_eq(h1["cost"], 0)
	var h2: Dictionary = TourState.hint(s, "drowned_purse", 2)
	assert_eq(h2["cost"], 50)
	var h3: Dictionary = TourState.hint(s, "drowned_purse", 3)
	assert_eq(h3["cost"], 500)
	assert_eq(s["gold"], 450)
	assert_eq(TourState.hint(s, "drowned_purse", 3)["cost"], 0, "a hint already bought is free to read again")


func test_hints_are_free_when_broke_or_stuck() -> void:
	var s: Dictionary = _state()
	s["gold"] = 10
	MapFragments.add(s, "drowned_purse_1")
	assert_eq(TourState.hint(s, "drowned_purse", 3)["cost"], 0, "cannot pay, so it is free")
	s["gold"] = 1000
	TourState.progress(s, "drowned_purse")["hints"] = {}
	TourState.progress(s, "drowned_purse")["step_time"] = TourData.STUCK_FREE_S
	assert_eq(TourState.hint(s, "drowned_purse", 3)["cost"], 0, "stuck for ten minutes")
	assert_eq(s["gold"], 1000)


func test_every_step_has_three_hints_in_both_languages() -> void:
	assert_true(TourState.hint_paths_complete(), "english hints")
	var old: String = Loc.locale
	Loc.locale = "cs"
	assert_true(TourState.hint_paths_complete(), "czech hints")
	Loc.locale = old


func test_death_costs_a_fifth_and_returns_to_the_checkpoint() -> void:
	var s: Dictionary = _state()
	s["gold"] = 1000
	var p: Dictionary = TourState.progress(s, "drowned_purse")
	p["step"] = 4
	p["checkpoint"] = 3
	var out: Dictionary = TourState.on_death(s, "drowned_purse")
	assert_eq(out["lost"], 200)
	assert_eq(s["gold"], 800)
	assert_eq(out["respawn"], TourData.step_pos(TourData.steps("drowned_purse")[3]))
	assert_eq(int(p["step"]), 4, "the step is kept, only the attempt restarts")


func test_finishing_a_tour_pays_the_reward() -> void:
	var s: Dictionary = _state()
	var g0: int = int(s["gold"])
	TourState.finish(s, "song_of_sirens")
	assert_eq(int(s["gold"]) - g0, 6000)
	assert_eq(TourState.root(s)["pearls"], 40)
	assert_true(TourState.root(s)["perks"].has("siren_figurehead") and TourState.root(s)["perks"].has("harpoon_blueprint"))
	TourState.finish(s, "song_of_sirens")
	assert_eq(int(s["gold"]) - g0, 6000, "paid once")
	TourState.finish(s, "drowned_purse")
	assert_true(TourState.root(s)["perks"].has("captains_cutlass") and TourState.root(s)["perks"].has("sloop_discount_50"))


func test_shell_king_is_a_three_phase_fight_with_a_two_second_telegraph() -> void:
	var f := MonsterFight.new("shell_king", 1)
	assert_near(f.boss.max_hp, 1200.0, 0.1)
	var seen: float = 0.0
	var landed: String = ""
	while landed == "" and seen < 20.0:
		landed = f.tick(0.1)
		seen += 0.1
		if f.telegraph() != "":
			break
	assert_eq(f.boss.telegraph_left_s > 1.9 and f.boss.telegraph_left_s <= 2.0, true, "telegraph starts at 2 s")
	f.boss.damage(1200.0 * 0.45)
	assert_eq(f.boss.phase, 1)
	f.boss.damage(1200.0 * 0.3)
	assert_eq(f.boss.phase, 2)


func test_dodging_in_the_window_avoids_damage_and_opens_the_monster() -> void:
	var f := MonsterFight.new("shell_king", 1)
	var guard: int = 0
	while f.telegraph() == "" and guard < 400:
		f.tick(0.1)
		guard += 1
	while f.boss.telegraph_left_s > 0.9:
		f.tick(0.1)
	assert_true(f.dodge())
	while f.telegraph() != "":
		f.tick(0.1)
	assert_near(f.player_hp, 100.0, 0.001)
	assert_true(f.is_exposed())
	var open_hit: float = f.strike()
	assert_near(open_hit, 60.0, 0.01, "30 damage doubled while open")
	f.exposed_s = 0.0
	assert_near(f.strike(), 15.0, 0.01, "armour halves it")


func test_a_hit_that_is_not_dodged_hurts_and_a_parry_cracks_the_claw() -> void:
	var f := MonsterFight.new("shell_king", 1)
	var guard: int = 0
	while f.telegraph() == "" and guard < 400:
		f.tick(0.1)
		guard += 1
	var first: String = f.telegraph()
	while f.telegraph() != "":
		f.tick(0.1)
	assert_near(f.player_hp, 100.0 - float(TourData.MONSTERS["shell_king"]["dmg"][first]), 0.001)
	var g := MonsterFight.new("shell_king", 1)
	g.boss._action_i = 0
	guard = 0
	while g.telegraph() != "pincer_sweep" and guard < 400:
		g.tick(0.1)
		guard += 1
	if g.telegraph() == "pincer_sweep":
		while g.boss.telegraph_left_s > 0.9:
			g.tick(0.1)
		assert_true(g.parry())
		while g.telegraph() != "":
			g.tick(0.1)
		assert_true(g.claw_cracked)
		assert_near(g.player_hp, 100.0, 0.001)


func test_serpent_chain_shot_cuts_the_coil() -> void:
	var f := MonsterFight.new("sea_serpent", 1)
	assert_near(f.boss.max_hp, 4000.0, 0.1)
	var guard: int = 0
	while f.telegraph() != "coil" and guard < 600:
		f.tick(0.1)
		guard += 1
	assert_eq(f.telegraph(), "coil")
	f.chain_shot()
	while f.telegraph() != "":
		f.tick(0.1)
	assert_near(f.player_hp, 1200.0 - 120.0 * 0.25, 0.01)


func test_perfect_play_beats_both_guardians() -> void:
	for m: String in ["shell_king", "sea_serpent"]:
		var f := MonsterFight.new(m, 1)
		assert_true(f.autoplay(), m + " falls to perfect play")
		assert_true(f.boss.phases_seen.has(1) and f.boss.phases_seen.has(2), m + " went through all three phases")
		assert_true(f.player_hp > 0.0)


func test_siren_pull_morale_and_protection() -> void:
	var w := SirenWaters.new(Vector2.ZERO, 1500.0)
	assert_eq(w.pull(Vector2(2000, 0), false), Vector2.ZERO, "outside the waters")
	var p: Vector2 = w.pull(Vector2(600, 0), false)
	assert_true(p.x < 0.0 and absf(p.y) < 0.001, "toward the rock")
	assert_eq(w.pull(Vector2(600, 0), true), Vector2.ZERO, "wax")
	assert_near(w.morale_drain(Vector2(600, 0), false, 2.0), -1.0, 0.0001)
	for i in 4:
		w.shoot_siren()
	assert_near(w.pull(Vector2(600, 0), false).length(), p.length() * 0.5, 1.0, "half the choir, half the pull")
	assert_true(SirenWaters.shanty_works(40.0) and not SirenWaters.shanty_works(39.0))


func test_dungeons_can_be_walked_and_have_three_to_six_rooms() -> void:
	for d: String in TourData.DUNGEONS.keys():
		var run := Dungeon.new(d, 3)
		assert_true(run.room_count() >= 3 and run.room_count() <= 6, d)
		run.autowalk()
		assert_true(run.is_done(), d + " walked to the exit")


func test_torches_last_five_minutes_and_dying_keeps_solved_rooms() -> void:
	var run := Dungeon.new("sea_cave", 9)
	run.advance()
	assert_true(run.torch_lit())
	run.tick(TourData.TORCH_S - 1.0)
	assert_true(run.torch_lit())
	run.tick(2.0)
	assert_true(not run.torch_lit())
	run.cross_trap(false)
	run.advance()
	run.hp = 0.0
	run.tick(0.1)
	assert_eq(run.deaths, 1)
	assert_eq(run.room, 0)
	assert_true(run.torch_lit(), "a fresh torch at the entrance")
	run.advance()
	run.advance()
	assert_true(run.room >= 2, "the trap room does not need doing twice")


func test_sluice_puzzle_resets_on_a_wrong_pull_and_on_time() -> void:
	var p := DungeonPuzzle.new("sluice", _rng(4))
	assert_near(p.time_left_s, 180.0, 0.001)
	var wrong: int = (p.solution[0] + 1) % 3
	assert_true(not p.press(wrong))
	assert_eq(p.resets, 1)
	assert_true(p.press(p.solution[0]))
	p.tick(181.0)
	assert_eq(p.progress, 0)
	assert_eq(p.resets, 2)
	p.solve_with_hints()
	assert_true(p.solved)


func test_every_puzzle_can_be_solved_with_hints() -> void:
	for k: String in ["sluice", "mirrors", "rhyme"]:
		for seed_v in 10:
			var p := DungeonPuzzle.new(k, _rng(seed_v))
			assert_true(not p.solved, k)
			p.solve_with_hints()
			assert_true(p.solved, k)
		assert_true(Loc.t("puzzle.hint3." + k) != "puzzle.hint3." + k)


func test_skeleton_reassembles_unless_burned() -> void:
	var run := Dungeon.new("sea_cave", 2)
	while run.room_kind() != "guard":
		if run.room_kind() == "trap":
			run.cross_trap(false)
		elif run.room_kind() == "puzzle":
			run.puzzle.solve_with_hints()
		elif run.room_kind() == "chest":
			run.open_chest()
		run.advance()
	run.hit_skeleton(100.0)
	assert_true(not run.skeleton_done and run.skeleton_down_s > 0.0)
	run.tick(TourData.SKELETON_REASSEMBLE_S + 0.1)
	assert_near(run.skeleton_hp, 30.0, 0.01)
	run.hit_skeleton(100.0, true)
	assert_true(run.skeleton_done)


func test_dig_table_and_pity() -> void:
	var r: RandomNumberGenerator = _rng(33)
	var counts: Dictionary = {"chest": 0, "trap": 0, "skeleton": 0, "nothing": 0}
	for i in 20000:
		var d := Digging.new(r)
		var out: String = ""
		for k in TourData.DIG_SWINGS:
			out = d.swing(1.0)
		counts[out] += 1
	for k: String in counts:
		assert_near(float(counts[k]) / 20000.0, float(TourData.DIG_TABLE[k]), 0.015, k)
	for seed_v in 200:
		var d := Digging.new(_rng(seed_v), true)
		var holes: int = 0
		var out: String = ""
		while out != "chest":
			d.reset()
			for k in TourData.DIG_SWINGS:
				out = d.swing(0.5)
			holes += 1
		assert_true(holes <= TourData.DIG_PITY_EMPTY + 1, "a tour spot gives its chest by hole three")


func test_save_migrates_to_v9_with_tours() -> void:
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 8
	old.erase("tours")
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(m["version"], SaveGame.VERSION)
	assert_true(SaveGame.VERSION >= 12)
	assert_true(m.has("tours"))
