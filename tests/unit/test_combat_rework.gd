extends TestCase
## Rob's combat rework: aimed guns, fists, rum, the captain's health between fights, the deck gun and repair party
## orders, and the crew's orders at sea.


func _duel(enemy_kind: String = "officer", crew: Array = []) -> DeckCombat:
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "flintlock", "shots": 10, "crew": crew, "reserve": 0, "morale": 70.0},
		{"fighters": [enemy_kind], "reserve": 0, "morale": 70.0}, 1)
	c.covers = []
	c.kegs = []
	c.ropes = []
	return c


func _enemy(c: DeckCombat) -> FighterState:
	for f in c.fighters:
		if f.team == 1:
			return f
	return null


func _hands(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"type": "carpenter" if i == 0 else "green", "level": 1, "name": "Hand %d" % i})
	return out


# ---- aiming ----------------------------------------------------------------------------------------

func test_a_steady_aim_is_tighter_than_the_hip() -> void:
	var f: FighterState = FighterState.make_player(1, "cutlass", "flintlock", 10)
	var hip: float = f.shot_spread_deg()
	f.mode = FighterState.Mode.GUN
	f.aiming = true
	f.aim_hold_t = 0.0
	var first: float = f.shot_spread_deg()
	f.aim_hold_t = DeckData.AIM_STEADY_S
	var steady: float = f.shot_spread_deg()
	assert_near(hip, DeckData.AIM_SPREAD_HIP_DEG, 0.0001)
	assert_true(first < hip and steady < first, "%f %f %f" % [hip, first, steady])
	assert_near(steady, DeckData.AIM_SPREAD_STEADY_DEG, 0.0001)


func test_aimed_shots_hit_more_often_than_hip_shots() -> void:
	var hits: Array[int] = [0, 0]
	for steady in 2:
		for n in 40:
			var c: DeckCombat = _duel("sailor")
			c.rng.seed = 100 + n
			var me: FighterState = c.player
			var foe: FighterState = _enemy(c)
			me.pos = Vector2(-6, 0)
			foe.pos = Vector2(6, 0)  # twelve metres off
			foe.think_left = 1000.0
			if steady == 1:
				me.mode = FighterState.Mode.GUN
				me.aiming = true
				me.aim_hold_t = 5.0
			c.fire_ranged(me, Vector2.RIGHT)
			if foe.hp < foe.hp_max:
				hits[steady] += 1
	assert_true(hits[1] >= 36, "aimed hits %d of 40" % hits[1])
	assert_true(hits[0] < hits[1] - 8, "hip %d vs aimed %d" % [hits[0], hits[1]])


func test_a_shot_aimed_away_misses() -> void:
	var c: DeckCombat = _duel("sailor")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-5, 0)
	foe.pos = Vector2(5, 0)
	foe.think_left = 1000.0
	me.aiming = true
	me.aim_hold_t = 5.0
	c.fire_ranged(me, Vector2(1, 1))  # forty-five degrees off
	assert_eq(foe.hp, foe.hp_max)


func test_the_ball_hits_the_first_man_in_line() -> void:
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "flintlock", "shots": 10, "crew": [], "reserve": 0, "morale": 70.0},
		{"fighters": ["sailor", "sailor"], "reserve": 0, "morale": 70.0}, 1)
	c.covers = []
	c.kegs = []
	var near: FighterState = c.fighters[1]
	var far: FighterState = c.fighters[2]
	c.player.pos = Vector2(-6, 0)
	near.pos = Vector2(0, 0)
	far.pos = Vector2(4, 0)
	near.think_left = 1000.0
	far.think_left = 1000.0
	c.player.aiming = true
	c.player.aim_hold_t = 5.0
	c.fire_ranged(c.player, Vector2.RIGHT)
	assert_near(near.hp, 150.0, 0.0001)
	assert_eq(far.hp, far.hp_max)


func test_an_enemy_levels_his_gun_before_he_fires_and_can_be_dodged() -> void:
	var c: DeckCombat = _duel("marine")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-5, 0)
	foe.pos = Vector2(5, 0)
	foe.aim_left = 0.0
	foe.think_left = 0.0
	foe.aim_skill_deg = 0.01
	me.think_left = 1000.0
	c.tick(1.0 / 60.0)
	assert_true(foe.aim_lock_left > 0.0, "the marine takes aim")
	assert_eq(me.hp, me.hp_max)  # not yet: the shot goes when the lock runs out
	me.pos = Vector2(-5, 3)  # the captain steps out of the line
	for i in 90:
		c.tick(1.0 / 60.0)
		me.move_intent = Vector2.ZERO
	assert_eq(me.hp, me.hp_max)
	assert_eq(foe.ranged_ammo, 3)  # the shot went, and missed


func test_an_enemy_shot_lands_when_you_stand_still() -> void:
	var c: DeckCombat = _duel("marine")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-5, 0)
	foe.pos = Vector2(5, 0)
	foe.aim_left = 0.0
	foe.think_left = 0.0
	foe.aim_skill_deg = 0.01
	for i in 90:
		c.tick(1.0 / 60.0)
		me.move_intent = Vector2.ZERO
		me.pos = Vector2(-5, 0)
		if me.hp < me.hp_max:
			break
	assert_near(me.hp, me.hp_max - DeckData.GUN_DAMAGE, 0.0001)


# ---- enemies fight back ---------------------------------------------------------------------------

func test_enemies_kick_a_guard_held_too_long() -> void:
	var kicked: bool = false
	for n in 6:
		var c: DeckCombat = _duel("officer")
		c.rng.seed = 7 + n
		var me: FighterState = c.player
		var foe: FighterState = _enemy(c)
		me.pos = Vector2(0, 0)
		foe.pos = Vector2(1.3, 0)
		me.dir = Vector2.RIGHT
		foe.dir = Vector2.LEFT
		foe.aim_left = 100.0
		for i in 180:
			me.raise_block(c.time_s)
			me.move_intent = Vector2.ZERO
			c.tick(1.0 / 60.0)
			if foe.state == FighterState.State.KICK:
				kicked = true
		if kicked:
			break
	assert_true(kicked, "an officer boots a captain who only blocks")


func test_a_one_on_one_against_an_officer_is_not_a_walkover() -> void:
	# the captain only swings (no blocking or parries): an officer who blocks and parries should hurt him badly
	var c: DeckCombat = _duel("officer")
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.pos = Vector2(-0.8, 0)
	foe.pos = Vector2(0.8, 0)
	foe.aim_left = 100.0
	var steps: int = 0
	while c.outcome == DeckCombat.Outcome.ONGOING and steps < 60 * 120:
		me.dir = (foe.pos - me.pos).normalized()
		me.move_intent = me.dir if me.pos.distance_to(foe.pos) > 1.5 else Vector2.ZERO
		me.try_swing(false)
		c.tick(1.0 / 60.0)
		steps += 1
	assert_true(me.hp < me.hp_max * 0.6 or me.state == FighterState.State.DOWN, "captain left with %d" % me.hp)


# ---- rum and recovery -------------------------------------------------------------------------------

func test_rum_heals_50_after_a_pull() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	me.hp = 100.0
	_enemy(c).pos = Vector2(6, 9)
	_enemy(c).think_left = 1000.0
	assert_eq(me.rum_left, DeckData.RUM_PER_FIGHT)
	assert_true(me.try_drink())
	assert_eq(me.state, FighterState.State.DRINK)
	assert_near(me.hp, 100.0, 0.0001)  # not until he has swallowed
	for i in 60:
		c.tick(1.0 / 60.0)
		_enemy(c).think_left = 1000.0
	assert_near(me.hp, 150.0, 0.0001)
	assert_eq(me.rum_left, DeckData.RUM_PER_FIGHT - 1)
	assert_true(not me.try_drink())  # cooling down
	assert_eq(c.result()["rum_drunk"], 1)


func test_rum_does_not_heal_past_200_and_not_when_unhurt() -> void:
	var f: FighterState = FighterState.make_player(1, "cutlass", "", 0)
	f.rum_left = 3
	assert_true(not f.try_drink())
	f.hp = 180.0
	assert_true(f.try_drink())
	f.tick(1.0, 0.0)
	assert_near(f.hp, 200.0, 0.0001)


func test_a_blow_knocks_the_bottle_away() -> void:
	var c: DeckCombat = _duel()
	var me: FighterState = c.player
	var foe: FighterState = _enemy(c)
	me.hp = 100.0
	me.try_drink()
	me.receive_melee(foe, 30.0, false, false, 0.0)
	assert_eq(me.state, FighterState.State.STAGGER)
	me.tick(1.0, 1.0)
	assert_near(me.hp, 70.0, 0.0001)  # no heal: the rum spilled


func test_captain_health_carries_and_recovers() -> void:
	var s: Dictionary = SaveGame.new_state()
	assert_near(CaptainHealth.hp(s), 200.0, 0.0001)
	CaptainHealth.after_fight(s, {"captain_hp": 90.0, "rum_drunk": 2, "captain_down": false})
	assert_near(CaptainHealth.hp(s), 90.0, 0.0001)
	assert_near(s["supplies"]["rum"], 1.0 - 2.0 * DeckData.RUM_SUPPLY_PER_DRINK, 0.0001)
	CaptainHealth.regen(s, 20.0)
	assert_near(CaptainHealth.hp(s), 90.0 + 20.0 * DeckData.REGEN_HP_PER_S, 0.0001)
	assert_true(CaptainHealth.drink(s))
	assert_near(CaptainHealth.hp(s), 150.0, 0.0001)
	CaptainHealth.regen(s, 10000.0)
	assert_near(CaptainHealth.hp(s), 200.0, 0.0001)
	assert_true(not CaptainHealth.drink(s))  # not hurt
	CaptainHealth.after_fight(s, {"captain_hp": 0.0, "captain_down": true})
	assert_near(CaptainHealth.hp(s), DeckData.KNOCKED_OUT_HP, 0.0001)
	s["supplies"]["rum"] = 0.0
	assert_true(not CaptainHealth.drink(s))
	assert_eq(CaptainHealth.rum_bottles(s), 0)


func test_a_fight_starts_with_the_captains_carried_health_and_rum() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["captain_hp"] = 120.0
	s["supplies"]["rum"] = 0.03  # one tot and a bit
	var c: DeckCombat = DeckBridge.build(6, 1.0, 70.0, "navy", 4, 1.0, 50.0, s, 3)
	assert_near(c.player.hp, 120.0, 0.0001)
	assert_eq(c.player.hp_max, 200.0)
	assert_eq(c.player.rum_left, 1)


func test_save_v12_migrates_to_200_health() -> void:
	var s: Dictionary = SaveGame.from_json('{"version": 12, "gold": 50, "captain_hp": 100}')
	assert_eq(s["version"], SaveGame.VERSION)
	assert_near(float(s["captain_hp"]), 200.0, 0.0001)


# ---- the deck gun and the repair party -------------------------------------------------------------------

func test_load_and_fire_the_deck_gun() -> void:
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "", "shots": 0, "crew": _hands(4), "reserve": 0, "morale": 90.0},
		{"fighters": ["sailor", "sailor", "sailor"], "reserve": 0, "morale": 90.0}, 2)
	c.covers = []
	c.kegs = []
	c.command = DeckData.Command.HOLD  # the rest of the hands stay at the line
	assert_eq(c.order_fire_cannon(), -1)  # nothing in it
	assert_true(c.order_load_cannon())
	var gunners: int = 0
	for f in c.fighters:
		if f.job == DeckData.Job.CANNON:
			gunners += 1
	assert_eq(gunners, DeckData.CANNON_CREW)
	# hold the enemy across the deck, in a knot in front of the gun
	var e: Array[FighterState] = c.enemies_of(c.player)
	for i in e.size():
		e[i].pos = Vector2(4.0, -2.2 + 0.5 * float(i))
	var steps: int = 0
	while not c.cannon_loaded and steps < 60 * 20:
		for o in e:
			o.think_left = 1000.0
			o.move_intent = Vector2.ZERO
		c.tick(1.0 / 60.0)
		steps += 1
	assert_true(c.cannon_loaded, "two hands load the gun")
	assert_true(steps < 60 * 12, "loading took %d frames" % steps)
	var hits: int = c.order_fire_cannon()
	assert_eq(hits, 3)
	for o in e:
		assert_near(o.hp, 200.0 - DeckData.GUN_DAMAGE, 0.0001)
	assert_true(not c.cannon_loaded)
	for f in c.fighters:
		assert_eq(f.job, DeckData.Job.NONE)  # the gunners go back to the fight


func test_repair_party_patches_our_hull() -> void:
	var c := DeckCombat.new()
	c.setup({"level": 1, "melee": "cutlass", "ranged": "", "shots": 0, "crew": _hands(4), "reserve": 0, "morale": 90.0},
		{"fighters": ["sailor"], "reserve": 0, "morale": 90.0}, 2)
	var foe: FighterState = _enemy(c)
	foe.pos = Vector2(6, -9)
	c.command = DeckData.Command.HOLD
	assert_true(c.order_repair())
	var party: Array[FighterState] = []
	for f in c.fighters:
		if f.job == DeckData.Job.REPAIR:
			party.append(f)
	assert_eq(party.size(), 2)
	assert_eq(party[0].crew_type, "carpenter")  # the carpenter goes first
	for i in 60 * 10:
		foe.think_left = 1000.0
		foe.move_intent = Vector2.ZERO
		c.tick(1.0 / 60.0)
	assert_true(c.hull_repaired > 10.0, "patched %f" % c.hull_repaired)
	assert_true(not c.order_repair())  # pressing again calls them back
	for f in party:
		assert_eq(f.job, DeckData.Job.NONE)


func test_repair_hull_restores_sections_and_stops_leaks() -> void:
	var d := DamageModel.new(load("res://data/ships/sloop.tres"), 1)
	d.section_hp[1] = d.section_max * 0.2
	d.leak_rate[1] = 0.3
	var got: float = d.repair_hull(d.section_max * 0.5)
	assert_near(got, d.section_max * 0.5, 0.01)
	assert_near(d.section_hp[1], d.section_max * 0.7, 0.01)
	assert_eq(d.leak_rate[1], 0.0)
	assert_near(d.repair_hull(1.0e6), d.section_max * 0.3, 0.01)  # only up to full


# ---- what the player can see ------------------------------------------------------------------------

func test_enemy_hits_show_no_number() -> void:
	var hud := DeckHud.new()
	hud.on_hit({"result": "hit", "damage": 30.0}, Vector2.ZERO, 1)
	hud.on_hit({"result": "hit", "damage": 30.0}, Vector2.ZERO, 0)
	var texts: Array[String] = []
	for ch in hud.get_children():
		if ch is Label:
			texts.append((ch as Label).text)
	assert_eq(texts.size(), 2)
	assert_eq(texts[0], Loc.t("deck.hit"))
	assert_eq(texts[1], "-30")
	hud.free()


# ---- the crew's orders at sea --------------------------------------------------------------------------

func test_sea_orders_set_the_crew_focus() -> void:
	var ship := Ship.new()
	ship.stats = load("res://data/ships/sloop.tres")
	ship.crew = CrewState.new(ship.stats)
	ship.sail_level = 0
	var o: CrewOrders.Order = CrewOrders.give(ship, CrewOrders.Order.REPAIR, CrewOrders.Order.NONE)
	assert_eq(o, CrewOrders.Order.REPAIR)
	assert_eq(ship.crew.focus, CrewState.Focus.REPAIR)
	o = CrewOrders.give(ship, CrewOrders.Order.LOAD, o)
	assert_eq(ship.crew.focus, CrewState.Focus.GUNS)
	o = CrewOrders.give(ship, CrewOrders.Order.RETREAT, o)
	assert_eq(ship.crew.focus, CrewState.Focus.SAILS)
	assert_eq(ship.sail_level, 3)
	o = CrewOrders.give(ship, CrewOrders.Order.ATTACK, o)
	assert_eq(o, CrewOrders.Order.ATTACK)
	assert_eq(ship.crew.focus, CrewState.Focus.GUNS)
	ship.free()
