extends TestCase


func _duel(my_weapon: String = "cutlass", enemy_kind: String = "sailor") -> DeckCombat:
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": my_weapon, "ranged": "flintlock", "shots": 10, "crew": [], "reserve": 0, "morale": 70.0},
		{"fighters": [enemy_kind], "reserve": 0, "morale": 70.0}, 1)
	c.covers = []
	c.kegs = []
	c.ropes = []
	return c


func _face(a: FighterState, b: FighterState, dist: float = 1.5) -> void:
	a.pos = Vector2(0, 0)
	b.pos = Vector2(dist, 0)
	a.dir = Vector2.RIGHT
	b.dir = Vector2.LEFT


func _enemy(c: DeckCombat) -> FighterState:
	for f in c.fighters:
		if f.team == 1:
			return f
	return null


# ---- parry timing ------------------------------------------------------------------------------

func test_parry_inside_the_window() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	me.raise_block(10.0)
	var r: Dictionary = me.receive_melee(foe, 20.0, false, false, 10.15)
	assert_eq(r["result"], "parried")
	assert_near(me.hp, me.hp_max, 0.0001)
	assert_eq(foe.state, FighterState.State.STAGGER)
	assert_near(foe.stagger_left, 1.0, 0.0001)
	assert_near(foe.vulnerable, 2.0, 0.0001)
	assert_eq(me.parries, 1)


func test_late_block_is_only_a_block() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	me.raise_block(10.0)
	var r: Dictionary = me.receive_melee(foe, 20.0, false, false, 10.21)
	assert_eq(r["result"], "blocked")
	assert_near(me.hp, me.hp_max - 4.0, 0.0001)  # 80% off
	assert_eq(foe.state, FighterState.State.IDLE)


func test_parry_window_edges() -> void:
	for case in [[10.19, "parried"], [10.2, "parried"], [10.201, "blocked"]]:
		var c: DeckCombat = _duel()
		var me: FighterState = c.player
		var foe: FighterState = _enemy(c)
		_face(me, foe)
		me.raise_block(10.0)
		assert_eq(me.receive_melee(foe, 20.0, false, false, case[0])["result"], case[1], str(case[0]))


func test_rapier_has_a_wider_parry_window() -> void:
	var c: DeckCombat = _duel("rapier")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	me.raise_block(10.0)
	assert_eq(me.receive_melee(foe, 20.0, false, false, 10.28)["result"], "parried")  # 0.3 s window


func test_riposte_after_parry_does_double() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	me.raise_block(5.0)
	me.receive_melee(foe, 10.0, false, false, 5.1)
	var hp_before: float = foe.hp
	foe.receive_melee(me, 10.0, false, false, 5.5)
	assert_near(hp_before - foe.hp, 20.0, 0.0001)
	var hp2: float = foe.hp
	foe.receive_melee(me, 10.0, false, false, 6.0)  # only the next hit is doubled
	assert_near(hp2 - foe.hp, 10.0, 0.0001)


func test_block_from_behind_does_nothing() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(0, 0)
	foe.pos = Vector2(-1.5, 0)  # behind a captain who faces right
	me.dir = Vector2.RIGHT
	me.raise_block(1.0)
	var r: Dictionary = me.receive_melee(foe, 20.0, false, false, 1.1)
	assert_eq(r["result"], "hit")
	assert_near(me.hp, me.hp_max - 20.0, 0.0001)


func test_block_drains_stamina_and_breaks() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	me.raise_block(0.0)
	me.receive_melee(foe, 30.0, false, false, 5.0)
	assert_near(me.stamina, 100.0 - 15.0, 0.0001)  # 0.5 stamina per damage
	me.stamina = 5.0
	var r: Dictionary = me.receive_melee(foe, 30.0, false, false, 6.0)
	assert_eq(r["result"], "guard_broken")
	assert_near(me.stamina, 0.0, 0.0001)
	assert_eq(me.state, FighterState.State.STAGGER)
	assert_near(r["damage"], 15.0, 0.0001)


func test_axe_heavy_breaks_block() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	me.raise_block(0.0)
	var r: Dictionary = me.receive_melee(foe, 65.0, true, true, 3.0)
	assert_eq(r["result"], "guard_broken")
	assert_near(r["damage"], 65.0, 0.0001)


# ---- dodge, kick, stamina ----------------------------------------------------------------------

func test_dodge_costs_stamina_and_gives_quarter_second_invulnerability() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	assert_true(me.try_dodge(Vector2.UP))
	assert_near(me.stamina, 75.0, 0.0001)
	me.tick(0.2, 1.0)
	assert_eq(me.receive_melee(foe, 20.0, false, false, 1.0)["result"], "dodged")
	me.tick(0.06, 1.1)
	assert_eq(me.receive_melee(foe, 20.0, false, false, 1.1)["result"], "hit")


func test_dodge_needs_25_stamina() -> void:
	var c: DeckCombat = _duel()
	c.player.stamina = 24.0
	assert_true(not c.player.try_dodge(Vector2.UP))


func test_stamina_regenerates_25_per_second_unless_blocking() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	me.stamina = 0.0
	me.tick(1.0, 0.0)
	assert_near(me.stamina, 25.0, 0.0001)
	me.raise_block(0.0)
	me.tick(1.0, 1.0)
	assert_near(me.stamina, 25.0, 0.0001)


func test_kick_breaks_guard_and_pushes_overboard_at_the_rail() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(5.0, 0.0)
	me.dir = Vector2.RIGHT
	foe.pos = Vector2(6.1, 0.0)  # at their rail
	assert_true(me.try_kick())
	for i in 40:
		c.tick(1.0 / 60.0)
	assert_true(foe.overboard)
	assert_eq(foe.state, FighterState.State.DEAD)
	assert_eq(me.kills, 1)


func test_kick_staggers_a_blocking_man() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-2.0, 0.0)
	me.dir = Vector2.RIGHT
	foe.pos = Vector2(-0.8, 0.0)
	foe.raise_block(0.0)
	me.try_kick()
	for i in 40:
		c.tick(1.0 / 60.0)
		foe.move_intent = Vector2.ZERO
	assert_true(foe.hp < foe.hp_max)
	assert_true(not foe.block_up)


# ---- damage numbers ----------------------------------------------------------------------------

func test_weapon_damage_table() -> void:
	assert_eq(DeckData.swing_damage("rusty_cutlass", false), 18.0)
	assert_eq(DeckData.swing_damage("rusty_cutlass", true), 32.0)
	assert_eq(DeckData.swing_damage("cutlass", false), 25.0)
	assert_eq(DeckData.swing_damage("cutlass", true), 45.0)
	assert_eq(DeckData.swing_damage("rapier", false), 18.0)
	assert_eq(DeckData.swing_damage("rapier", true), 34.0)
	assert_eq(DeckData.swing_damage("boarding_axe", false), 35.0)
	assert_eq(DeckData.swing_damage("boarding_axe", true), 65.0)
	assert_eq(DeckData.swing_damage("captains_cutlass", true), 58.0)
	assert_near(DeckData.swing_time("cutlass", false), 0.5, 0.0001)
	assert_near(DeckData.swing_time("cutlass", true), 1.1, 0.0001)
	assert_near(DeckData.swing_time("rapier", false), 0.35, 0.0001)


func test_enemy_archetype_hit_points() -> void:
	assert_eq(DeckData.ENEMIES["sailor"]["hp"], 40.0)
	assert_eq(DeckData.ENEMIES["marine"]["hp"], 70.0)
	assert_eq(DeckData.ENEMIES["officer"]["hp"], 110.0)
	assert_eq(DeckData.ENEMIES["brute"]["hp"], 160.0)
	assert_eq(DeckData.player_hp(1), 100.0)
	assert_eq(DeckData.player_hp(5), 140.0)
	assert_eq(FighterState.make_enemy("captain", 900.0).hp, 900.0)


func _swing_and_resolve(c: DeckCombat, att: FighterState, heavy: bool) -> void:
	att.try_swing(heavy)
	for i in 120:
		c.tick(1.0 / 60.0)
		for f in c.fighters:
			if f != att:
				f.move_intent = Vector2.ZERO
		if not att.swing_struck:
			continue
		if att.state != FighterState.State.SWING:
			break


func test_light_and_heavy_hit_for_table_damage() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	foe.think_left = 1000.0  # keep the dummy still
	me.stamina = 100.0
	_swing_and_resolve(c, me, false)
	assert_near(foe.hp, 110.0 - 25.0, 0.01)
	c = _duel("cutlass", "officer")
	me = c.player
	foe = _enemy(c)
	_face(me, foe)
	foe.think_left = 1000.0
	_swing_and_resolve(c, me, true)
	assert_near(foe.hp, 110.0 - 45.0, 0.01)


func test_three_hit_combo_multiplies_the_third_blow() -> void:
	var c: DeckCombat = _duel("cutlass", "brute")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	_face(me, foe)
	foe.think_left = 1000.0
	foe.dir = Vector2.RIGHT  # facing away: a flank hit, no front armour
	var dealt: Array[float] = []
	for n in 3:
		var before: float = foe.hp
		me.try_swing(false)
		for i in 60:
			c.tick(1.0 / 60.0)
			me.dir = Vector2.RIGHT
			foe.think_left = 1000.0
			if me.state == FighterState.State.IDLE and i > 5:
				break
		dealt.append(before - foe.hp)
	assert_near(dealt[0], 25.0, 0.01)
	assert_near(dealt[1], 25.0 * 1.1, 0.01)
	assert_near(dealt[2], 25.0 * 1.4, 0.01)


func test_brute_front_armour_needs_a_flank() -> void:
	var brute: FighterState = FighterState.make_enemy("brute")
	var att: FighterState = FighterState.make_crew("green")
	brute.pos = Vector2(2, 0)
	brute.dir = Vector2.LEFT
	att.pos = Vector2(0.5, 0)
	var front: Dictionary = brute.receive_melee(att, 40.0, false, false, 0.0)
	assert_near(front["damage"], 20.0, 0.0001)
	att.pos = Vector2(3.5, 0)  # behind him
	var back: Dictionary = brute.receive_melee(att, 40.0, false, false, 0.0)
	assert_near(back["damage"], 40.0, 0.0001)


func test_dagger_backstab_triples() -> void:
	var c: DeckCombat = _duel("dagger", "officer")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(0, 0)
	me.dir = Vector2.RIGHT
	foe.pos = Vector2(1.2, 0)
	foe.dir = Vector2.RIGHT  # his back is to us
	foe.think_left = 1000.0
	me.try_swing(false)
	for i in 30:
		c.tick(1.0 / 60.0)
		foe.think_left = 1000.0
	assert_near(110.0 - foe.hp, 12.0 * 3.0, 0.01)


func test_swordsman_hits_harder() -> void:
	var s: FighterState = FighterState.make_crew("swordsman")
	assert_near(s.strength, 1.6, 0.0001)
	assert_near(DeckData.swing_damage(s.melee, false) * s.strength, 40.0, 0.0001)


# ---- guns, cover, props ------------------------------------------------------------------------

func test_pistol_braces_and_reload() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-5, 0)
	foe.pos = Vector2(5, 0)
	foe.think_left = 1000.0
	assert_eq(me.charges, 4)
	assert_true(c.fire_ranged(me, Vector2.RIGHT))  # 10 m is inside pistol range (15 m): it fires
	assert_eq(me.charges, 3)
	assert_eq(me.ranged_ammo, 9)
	assert_near(foe.hp, 40.0 - 60.0 if false else 0.0, 0.0001)  # a 60-damage ball kills a 40 HP sailor
	for i in 3:
		c.fire_ranged(me, Vector2.RIGHT)
	assert_eq(me.charges, 0)
	assert_true(not c.fire_ranged(me, Vector2.RIGHT))
	me.tick(5.1, 0.0)
	assert_eq(me.charges, 1)  # five seconds reload one barrel
	assert_eq(WeaponData.WEAPONS["flintlock"]["damage"], 60)
	assert_eq(WeaponData.WEAPONS["flintlock"]["range"], 15.0)


func test_cover_cuts_ranged_damage_seventy_percent() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-5, 0)
	foe.pos = Vector2(4, 0)
	foe.think_left = 1000.0
	c.fire_ranged(me, Vector2.RIGHT)
	assert_near(110.0 - foe.hp, 60.0, 0.01)
	var c2: DeckCombat = _duel("cutlass", "officer")
	c2.covers = [{"pos": Vector2(0, 0), "radius": 0.8}]
	c2.player.pos = Vector2(-5, 0)
	var foe2: FighterState = _enemy(c2)
	foe2.pos = Vector2(4, 0)
	foe2.think_left = 1000.0
	c2.fire_ranged(c2.player, Vector2.RIGHT)
	assert_near(110.0 - foe2.hp, 60.0 * 0.3, 0.01)


func test_powder_keg_blast() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	c.kegs = [{"pos": Vector2(0, 0), "alive": true}]
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-6, 0)
	foe.pos = Vector2(0.0, 3.5)  # inside the 4 m blast, off the line of fire
	foe.think_left = 1000.0
	c.fire_ranged(me, Vector2.RIGHT)
	assert_true(not c.kegs[0]["alive"])
	assert_near(110.0 - foe.hp, 80.0 + 0.0, 0.01)  # the ball hits the keg first and the blast does 80
	assert_eq(me.hp, me.hp_max)  # six metres away from the barrel


func test_net_trap_stuns_and_hurts() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	c.ropes = [{"pos": Vector2(0, 0), "kind": "net", "drop": Vector2(3, 0), "used": false}]
	var foe: FighterState = _enemy(c)
	foe.pos = Vector2(3, 0.5)
	c.player.pos = Vector2(0.5, 0)
	assert_true(c.use_rope(c.player))
	assert_near(110.0 - foe.hp, 40.0, 0.01)
	assert_near(foe.stun_left, 2.0, 0.0001)
	assert_true(not c.use_rope(c.player))  # a rope can be cut once


func test_rope_swing_drop_attack() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	c.ropes = [{"pos": Vector2(0, 0), "kind": "swing", "drop": Vector2.ZERO, "used": false}]
	var foe: FighterState = _enemy(c)
	foe.pos = Vector2(6, 0)
	c.player.pos = Vector2(0.5, 0)
	assert_true(c.use_rope(c.player))
	assert_near(110.0 - foe.hp, 45.0, 0.01)
	assert_eq(foe.state, FighterState.State.STAGGER)
	assert_true(c.player.pos.distance_to(foe.pos) < 1.5)


func test_grenade_blast() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	var foe: FighterState = _enemy(c)
	foe.pos = Vector2(5, 0)
	foe.think_left = 1000.0
	c.throw_grenade(c.player, Vector2(5, 1))
	for i in 200:
		c.tick(1.0 / 60.0)
		foe.think_left = 1000.0
	assert_near(110.0 - foe.hp, 80.0, 0.01)


# ---- the fight as a whole ----------------------------------------------------------------------

func _twelve_v_twelve(seed_value: int = 3, morale_effic: float = 1.0) -> DeckCombat:
	var crew: Array = []
	for i in 11:
		crew.append({"type": "seasoned" if i < 4 else "green", "level": 1})
	var enemies: Array = []
	for i in 12:
		enemies.append("sailor" if i < 8 else ("marine" if i < 10 else "officer"))
	var c := DeckCombat.new()
	c.setup({"level": 3, "melee": "cutlass", "ranged": "flintlock", "shots": 10, "crew": crew, "reserve": 0, "morale": 70.0, "effic": morale_effic},
		{"fighters": enemies, "reserve": 0, "morale": 70.0}, seed_value)
	return c


func test_twelve_against_twelve_on_screen() -> void:
	var c: DeckCombat = _twelve_v_twelve()
	assert_eq(c.alive_on_screen(0), 12)
	assert_eq(c.alive_on_screen(1), 12)
	assert_eq(c.player.hp_max, 120.0)


func test_a_fight_ends_and_is_repeatable() -> void:
	var a: Dictionary = {}
	var b: Dictionary = {}
	for run in 2:
		var c: DeckCombat = _twelve_v_twelve(5)
		var steps: int = 0
		while c.outcome == DeckCombat.Outcome.ONGOING and steps < 60 * 130:
			c.command = DeckData.Command.CHARGE
			c.tick(1.0 / 60.0)
			steps += 1
		if run == 0:
			a = c.result()
		else:
			b = c.result()
	assert_true(a["outcome"] != DeckCombat.Outcome.ONGOING)
	assert_eq(a["outcome"], b["outcome"])
	assert_eq(a["crew_left"], b["crew_left"])
	assert_eq(a["enemy_left"], b["enemy_left"])
	assert_near(a["time_s"], b["time_s"], 0.0001)


func test_enemy_surrenders_when_morale_breaks() -> void:
	var c: DeckCombat = _twelve_v_twelve()
	c.morale[1] = 19.0
	c.tick(1.0 / 60.0)
	assert_eq(c.outcome, DeckCombat.Outcome.PLAYER_WINS)
	assert_true(c.surrendered)
	var c2: DeckCombat = _twelve_v_twelve()
	c2.morale[1] = 20.0  # 20 is not under 20
	c2.tick(1.0 / 60.0)
	assert_eq(c2.outcome, DeckCombat.Outcome.ONGOING)


func test_deaths_lower_morale_and_captain_halves_it() -> void:
	var c: DeckCombat = _duel("cutlass", "officer")
	var boss: FighterState = _enemy(c)
	c.started_with[1] = 10
	var before: float = c.morale[1]
	var killer: FighterState = c.player
	boss.hp = 1.0
	boss.receive_raw(5.0, killer)
	c._on_death(boss, killer)
	assert_near(c.morale[1], before - 4.0, 0.0001)  # 40 / 10 men
	var cap: FighterState = FighterState.make_enemy("captain", 300.0)
	c.fighters.append(cap)
	var m2: float = c.morale[1]
	c._on_death(cap, killer)
	assert_near(c.morale[1], (m2 - 4.0) * 0.5, 0.0001)


func test_killing_everyone_wins() -> void:
	var c: DeckCombat = _duel("cutlass", "sailor")
	var foe: FighterState = _enemy(c)
	foe.receive_raw(100.0, c.player)
	c._on_death(foe, c.player)
	c.tick(1.0 / 60.0)
	assert_eq(c.outcome, DeckCombat.Outcome.PLAYER_WINS)
	assert_true(c.result()["player_won"])


func test_losing_every_man_loses() -> void:
	var c: DeckCombat = _duel("cutlass", "sailor")
	c.player.receive_raw(500.0, _enemy(c))
	assert_eq(c.player.state, FighterState.State.DOWN)  # the captain is knocked out, not killed
	c.tick(1.0 / 60.0)
	assert_eq(c.outcome, DeckCombat.Outcome.ENEMY_WINS)
	assert_true(c.result()["captain_down"])


func test_crew_fights_on_while_the_captain_is_down() -> void:
	var c: DeckCombat = _twelve_v_twelve()
	c.player.receive_raw(500.0, null)
	for i in 120:
		c.tick(1.0 / 60.0)
	assert_eq(c.outcome, DeckCombat.Outcome.ONGOING)
	assert_true(c.standing_on_screen(0) > 0)


func test_time_limit_resolves_by_remaining_strength() -> void:
	var c: DeckCombat = _twelve_v_twelve()
	for f in c.fighters:
		f.think_left = 1.0e9
		f.move_intent = Vector2.ZERO
	c.time_s = BoardingSim.TIME_LIMIT_S - 0.001
	c.tick(0.01)
	assert_true(c.timed_out)
	assert_true(c.outcome != DeckCombat.Outcome.ONGOING)


func test_reinforcements_keep_twelve_on_screen_and_feed_from_reserve() -> void:
	var enemies: Array = []
	for i in 12:
		enemies.append("sailor")
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "", "shots": 0, "crew": [], "reserve": 0, "morale": 90.0},
		{"fighters": enemies, "reserve": 8, "morale": 90.0, "reserve_kind": "sailor"}, 2)
	assert_eq(c.alive_on_screen(1), 12)
	assert_eq(c.reserve_of(1), 8)
	var victim: FighterState = c.enemies_of(c.player)[0]
	victim.receive_raw(500.0, null)
	c._on_death(victim, null)
	for i in 120:
		c.tick(1.0 / 60.0)
		if c.outcome != DeckCombat.Outcome.ONGOING:
			break
	assert_true(c.alive_on_screen(1) <= DeckData.MAX_ON_SCREEN)
	assert_true(c.reserve_of(1) < 8)  # a man came over the rail


func test_the_captains_kills_feed_the_abstract_pool() -> void:
	var enemies: Array = ["sailor"]
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "", "shots": 0, "crew": [], "reserve": 0, "morale": 90.0},
		{"fighters": enemies, "reserve": 10, "morale": 90.0}, 2)
	var foe: FighterState = _enemy(c)
	foe.receive_raw(500.0, c.player)
	c._on_death(foe, c.player)
	assert_eq(c.player_kills, 1)
	assert_near(c.sim.defender.pool, 10.0 - BoardingSim.PLAYER_KILL_VALUE, 0.0001)


func test_squad_commands_change_where_the_crew_goes() -> void:
	var results: Dictionary = {}
	for cmd in [DeckData.Command.CHARGE, DeckData.Command.HOLD, DeckData.Command.PROTECT, DeckData.Command.FALL_BACK]:
		var c: DeckCombat = _twelve_v_twelve(9)
		c.command = cmd
		for i in 150:
			c.tick(1.0 / 60.0)
		var mean_x: float = 0.0
		var n: int = 0
		for f in c.fighters:
			if f.team == 0 and f.is_standing() and not f.is_player:
				mean_x += f.pos.x
				n += 1
		results[cmd] = mean_x / maxf(float(n), 1.0)
	assert_true(results[DeckData.Command.FALL_BACK] < results[DeckData.Command.HOLD] - 0.5, str(results))
	assert_true(results[DeckData.Command.CHARGE] > results[DeckData.Command.FALL_BACK], str(results))


func test_sailors_panic_at_low_morale_and_run() -> void:
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "", "shots": 0, "crew": [], "reserve": 0, "morale": 90.0},
		{"fighters": ["sailor", "officer"], "reserve": 0, "morale": 90.0}, 4)
	c.morale[1] = 25.0
	var sailor: FighterState = null
	for f in c.fighters:
		if f.kind == "sailor":
			sailor = f
		elif f.team == 1:
			f.pos = Vector2(-5.0, 9.0)  # the officer is too far off to rally him
	sailor.pos = Vector2(1.0, 0.0)
	var start_x: float = sailor.pos.x
	for i in 90:
		c.tick(1.0 / 60.0)
	assert_true(sailor.pos.x > start_x)  # running for his own rail (positive x)


func test_morale_band_changes_swing_speed() -> void:
	var loyal: FighterState = FighterState.make_crew("green")
	loyal.morale_effic = 1.10
	var sour: FighterState = FighterState.make_crew("green")
	sour.morale_effic = 0.75
	loyal.try_swing(false)
	sour.try_swing(false)
	assert_true(loyal.swing_dur < sour.swing_dur)


func test_twelve_v_twelve_tick_is_cheap() -> void:
	var c: DeckCombat = _twelve_v_twelve(7)
	var t0: int = Time.get_ticks_usec()
	var steps: int = 0
	while steps < 600 and c.outcome == DeckCombat.Outcome.ONGOING:
		c.tick(1.0 / 60.0)
		steps += 1
	var per_tick_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(steps, 1))
	assert_true(per_tick_ms < 4.0, "deck logic took %.2f ms per tick (budget 16.6 ms per frame)" % per_tick_ms)
