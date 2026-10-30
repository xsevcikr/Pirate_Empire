extends TestCase


## Tick until the named attack is being told, then into its answer window. Returns false if it never came.
func _wait_for(f: MonsterFight, atk: String, into_window: bool = true) -> bool:
	var guard: int = 0
	while f.telegraph() != atk and guard < 3000:
		f.tick(0.1)
		guard += 1
	if f.telegraph() != atk:
		return false
	while into_window and f.boss.telegraph_left_s > 0.85:
		f.tick(0.05)
	return true


func _land(f: MonsterFight) -> void:
	while f.telegraph() != "":
		f.tick(0.05)


## Put the boss into a phase without the roar getting in the way.
func _phase(f: MonsterFight, p: int) -> void:
	f.boss.untargetable = false
	var th: Array = Boss.DEFS[f.id]["thresholds"]
	f.boss.hp = f.boss.max_hp * float(th[p]) - 1.0
	f.boss.damage(0.0, true)
	f.boss.enrage_left_s = 0.0
	f.boss._timer_s = 0.0


func test_every_boss_attack_is_defined_named_and_answerable() -> void:
	for id: String in Boss.DEFS.keys():
		var names: Dictionary = {}
		for phase: Array in Boss.DEFS[id]["actions"]:
			for atk: String in phase:
				names[atk] = true
				var a: Dictionary = BossAttacks.of(id, atk)
				assert_true(not a.is_empty(), "%s %s has data" % [id, atk])
				assert_true(float(a["tele"]) >= 1.5 and float(a["tele"]) <= 3.0, "%s %s tell length" % [id, atk])
				assert_true(str(a["fx"]) != "", "%s %s is acted out" % [id, atk])
				assert_true(Loc.t("atk." + atk) != "atk." + atk, "atk.%s translated" % atk)
				assert_true(Loc.t("tell." + atk) != "tell." + atk, "tell.%s translated" % atk)
				if float(a["dmg"]) > 0.0:
					assert_true(not (a["counter"] as Array).is_empty(), "%s %s can be answered" % [id, atk])
				assert_true(Loc.t(BossAttacks.answer_key(id, atk)) != BossAttacks.answer_key(id, atk), BossAttacks.answer_key(id, atk))
		if BossModel.has_model(id):
			assert_true(names.size() >= 5, "%s has at least five attacks of its own (%d)" % [id, names.size()])


func test_monster_attacks_are_unique_to_each_monster() -> void:
	var owner: Dictionary = {}
	for id: String in BossModel.KINDS:
		for atk: String in BossAttacks.ATTACKS[id].keys():
			assert_true(not owner.has(atk), "%s is %s's, not also %s's" % [atk, owner.get(atk, ""), id])
			owner[atk] = id


func test_each_phase_attacks_faster_and_roars_first() -> void:
	assert_true(BossAttacks.PHASE_GAP_S[0] > BossAttacks.PHASE_GAP_S[1] and BossAttacks.PHASE_GAP_S[1] > BossAttacks.PHASE_GAP_S[2])
	var b := Boss.new("kraken", 1)
	b.damage(b.max_hp * 0.4)
	assert_eq(b.phase, 1)
	assert_true(b.enrage_left_s > 0.0, "it roars")
	b.tick(BossAttacks.ENRAGE_PAUSE_S + 0.01)
	b.tick(BossAttacks.PHASE_GAP_S[1] - 0.2)
	assert_eq(b.special_pending, "", "no attack during the roar")
	b.tick(0.4)
	assert_eq(b.special_pending, "grab_and_crush", "phase two opens with the grab")


func test_serpent_spits_poison_that_hurts_over_time() -> void:
	var f := MonsterFight.new("sea_serpent", 1)
	assert_true(_wait_for(f, "venom_spit", false))
	_land(f)
	assert_near(f.player_hp, 1200.0 - 80.0, 0.5)
	assert_true(f.has_effect("poison"))
	var before: float = f.player_hp
	f.tick(1.0)
	assert_near(before - f.player_hp, 15.0, 0.6, "15 a second")
	f.tick(10.0)
	assert_true(not f.has_effect("poison"))


func test_tail_sweep_cannot_be_dodged_but_a_brace_takes_a_quarter() -> void:
	var f := MonsterFight.new("sea_serpent", 1)
	_phase(f, 1)
	assert_true(_wait_for(f, "tail_sweep"))
	f.dodge()
	var hp: float = f.player_hp
	_land(f)
	assert_near(hp - f.player_hp, 90.0, 0.5, "dodging a tail sweep does nothing")
	var g := MonsterFight.new("sea_serpent", 1)
	_phase(g, 1)
	assert_true(_wait_for(g, "tail_sweep"))
	assert_true(g.block())
	var hp2: float = g.player_hp
	_land(g)
	assert_near(hp2 - g.player_hp, 90.0 * 0.25, 0.5)


func test_kraken_grab_is_cut_off_by_a_strike_in_time() -> void:
	var f := MonsterFight.new("kraken", 1)
	_phase(f, 1)
	assert_true(_wait_for(f, "grab_and_crush"))
	f.strike()
	assert_eq(f.answered(), "strike")
	_land(f)
	assert_eq(f.last_outcome, "countered")
	assert_near(f.player_hp, 1200.0, 0.01)
	assert_true(f.is_exposed())
	var g := MonsterFight.new("kraken", 1)
	_phase(g, 1)
	assert_true(_wait_for(g, "grab_and_crush"))
	g.dodge()
	_land(g)
	assert_near(g.player_hp, 1200.0 - 350.0, 0.01, "you cannot sail out of its grip")
	assert_true(g.has_effect("slow"))


func test_ink_blinds_and_halves_your_blows() -> void:
	var f := MonsterFight.new("kraken", 1)
	_phase(f, 1)
	assert_true(_wait_for(f, "ink_spit", false))
	_land(f)
	assert_true(f.has_effect("blind"))
	f.tentacles_left = 0
	f.exposed_s = 0.0
	assert_near(f.strike(100.0), 100.0 * MonsterFight.BLIND_MULT * 1.0, 0.01)


func test_slowed_cannot_dodge_and_stunned_cannot_answer() -> void:
	var f := MonsterFight.new("ice_leviathan", 1)
	assert_true(_wait_for(f, "hurl_ice"))
	f.effects["slow"] = 5.0
	assert_true(not f.dodge(), "the ship is frozen in place")
	f.effects.erase("slow")
	f.effects["stun"] = 2.0
	assert_true(not f.dodge() and not f.block())
	assert_near(f.strike(), 0.0, 0.001)


func test_each_trick_answers_its_own_attack() -> void:
	var c := MonsterFight.new("brass_colossus", 1)
	_phase(c, 2)
	assert_true(_wait_for(c, "overheat", false))
	c.cool_core()
	_land(c)
	assert_eq(c.last_outcome, "countered")
	assert_near(c.player_hp, 200.0, 0.01)
	var i := MonsterFight.new("ice_leviathan", 1)
	_phase(i, 2)
	assert_true(_wait_for(i, "frost_lock", false))
	i.explosive_shot()
	_land(i)
	assert_eq(i.last_outcome, "countered")
	var g := MonsterFight.new("ghost_admiral", 1)
	_phase(g, 1)
	assert_true(_wait_for(g, "soul_chains", false))
	assert_true(g.shoot_lantern())
	_land(g)
	assert_eq(g.last_outcome, "countered")
	assert_true(not g.has_effect("slow"))


func test_colossus_fist_hits_like_a_pistol_on_a_200_hp_captain() -> void:
	var f := MonsterFight.new("brass_colossus", 1)
	assert_near(f.player_max, 200.0, 0.01)
	assert_true(_wait_for(f, "fist_slam", false))
	_land(f)
	assert_near(f.player_hp, 150.0, 0.01)


func test_every_boss_falls_to_perfect_play_through_all_phases() -> void:
	for id: String in Boss.DEFS.keys():
		var f := MonsterFight.new(id, 1)
		assert_true(f.autoplay(900.0), id + " falls")
		assert_true(f.player_hp > 0.0, id + " the player lives")
		assert_true(f.boss.phases_seen.has(2), id + " reached the last phase")


func test_doing_nothing_loses() -> void:
	for id: String in BossModel.KINDS:
		var f := MonsterFight.new(id, 1)
		var t: float = 0.0
		while not f.is_over() and t < 900.0:
			f.tick(0.1)
			t += 0.1
		assert_true(f.lost(), id + " is not a pushover")


func test_the_fight_panel_never_shows_the_boss_health() -> void:
	var f := MonsterFight.new("kraken", 1)
	f.boss.damage(1234.0)
	var s := TourEncounterScreen.new()
	s.fight = f
	var text: String = s.status_text()
	assert_true(text.find(str(int(f.boss.hp))) < 0 and text.find(str(int(f.boss.max_hp))) < 0, text)
	assert_true(text.find(str(int(f.player_hp))) >= 0, "your own health is there")
	s.free()
