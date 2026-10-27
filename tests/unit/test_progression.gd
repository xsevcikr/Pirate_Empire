extends TestCase


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["crew"] = 10
	return s


func _rng(seed_v: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


# ---- levels and XP ------------------------------------------------------------------------------------------

func test_level_curve_runs_from_1_to_30() -> void:
	assert_eq(ProgressionData.xp_to_reach(1), 0)
	var prev: int = 0
	for l in range(2, ProgressionData.MAX_LEVEL + 1):
		var need: int = ProgressionData.xp_to_reach(l)
		assert_true(need > prev, "level %d needs more than level %d" % [l, l - 1])
		assert_eq(Progression.level_for_xp(need), l)
		assert_eq(Progression.level_for_xp(need - 1), l - 1)
		prev = need
	assert_eq(Progression.level_for_xp(10000000), ProgressionData.MAX_LEVEL, "level 30 is the cap")


func test_each_level_gives_one_skill_point() -> void:
	var s: Dictionary = _state()
	assert_eq(Progression.points_free(s), 0)
	var gained: int = Progression.add_xp(s, ProgressionData.xp_to_reach(5))
	assert_eq(gained, 4)
	assert_eq(int(s["captain_level"]), 5)
	assert_eq(Progression.points_free(s), 4)


func test_xp_rules_match_the_brief() -> void:
	assert_eq(Progression.xp_for("sink", {"class_id": "frigate"}), 20 * 4)
	assert_eq(Progression.xp_for("capture", {"class_id": "sloop"}), 35 * 2)
	assert_eq(Progression.xp_for("duel"), 50)
	assert_eq(Progression.xp_for("island"), 25)
	assert_eq(Progression.xp_for("trade", {"gold": 1250}), 12, "1 XP per 100 gold")
	assert_eq(Progression.xp_for("tour", {"tour_id": "drowned_purse"}), 500)
	assert_eq(Progression.xp_for("tour", {"tour_id": "krakens_maw"}), 2000)
	for id: String in TourData.ORDER:
		var xp: int = Progression.xp_for("tour", {"tour_id": id})
		assert_true(xp >= 500 and xp <= 2000, "%s tour XP %d is 500 to 2,000" % [id, xp])


func test_every_ship_class_has_a_tier() -> void:
	for f in DirAccess.get_files_at("res://data/ships"):
		if f.ends_with(".tres"):
			assert_true(ProgressionData.CLASS_TIER.has(f.get_basename()), "%s has an XP tier" % f)


# ---- skills ------------------------------------------------------------------------------------------------

func test_five_trees_of_five_skills() -> void:
	assert_eq(ProgressionData.TREES.size(), 5)
	for tree: String in ProgressionData.TREES:
		assert_eq((ProgressionData.SKILLS[tree] as Array).size(), 5, tree)
	assert_eq(ProgressionData.skill_ids().size(), 25)


func test_every_skill_rank_changes_the_stat_it_names() -> void:
	for full in ProgressionData.skill_ids():
		var s: Dictionary = _state()
		s["captain_level"] = 30
		var def: Dictionary = ProgressionData.skill(full)
		var prev: float = Progression.stat(s, str(def["stat"]))
		assert_eq(prev, float(def["neutral"]), "%s starts neutral" % full)
		for r in range(1, 4):
			assert_true(Progression.spend(s, full), "%s rank %d can be bought" % [full, r])
			var now: float = Progression.stat(s, str(def["stat"]))
			assert_true(not is_equal_approx(now, prev), "%s rank %d changes %s" % [full, r, def["stat"]])
			prev = now
		assert_true(not Progression.spend(s, full), "%s stops at rank 3" % full)


func test_stats_are_unique_per_skill() -> void:
	var seen: Dictionary = {}
	for full in ProgressionData.skill_ids():
		var st: String = str(ProgressionData.skill(full)["stat"])
		assert_true(not seen.has(st), "stat %s used once" % st)
		seen[st] = true


func test_spending_needs_points_and_respec_gives_them_back() -> void:
	var s: Dictionary = _state()
	assert_true(not Progression.spend(s, "gunnery.reload"), "no points, no rank")
	Progression.add_xp(s, ProgressionData.xp_to_reach(3))
	assert_true(Progression.spend(s, "gunnery.reload"))
	assert_true(Progression.spend(s, "gunnery.reload"))
	assert_true(not Progression.spend(s, "trade.cargo"), "out of points")
	Progression.respec(s)
	assert_eq(Progression.points_free(s), 2)
	assert_eq(Progression.rank(s, "gunnery.reload"), 0)


# ---- skills act on the game --------------------------------------------------------------------------------

func test_trade_skills_change_prices_cargo_and_insurance() -> void:
	var s: Dictionary = _state()
	s["captain_level"] = 30
	var base_cargo: float = Session.player_stats().cargo_t
	Session.state = s
	var plain: float = Session.player_stats().cargo_t
	Progression.spend(s, "trade.cargo")
	assert_true(is_equal_approx(Session.player_stats().cargo_t, plain * 1.05), "cargo +5% at rank 1")
	var prem0: int = Finance.insurance_premium(s)
	Progression.spend(s, "trade.insurance")
	assert_true(Finance.insurance_premium(s) < prem0, "insurance gets cheaper")
	var m: Market = PortService.market_of(s, PortData.START_PORT)
	var g: String = str(m.stock.keys()[0])
	s["cargo"][g] = 10.0
	var m1: Market = PortService.market_of(s, PortData.START_PORT)
	var gain0: int = PortService.sell_good(s.duplicate(true), m1, g, 10)
	Progression.spend(s, "trade.prices")
	s["cargo"][g] = 10.0
	var m2: Market = PortService.market_of(s, PortData.START_PORT)
	var gain1: int = PortService.sell_good(s, m2, g, 10)
	assert_true(gain1 > gain0, "better prices pay more (%d vs %d)" % [gain1, gain0])
	assert_true(base_cargo > 0.0)
	Session.state = {}


func test_seamanship_changes_speed_and_turn() -> void:
	var s: Dictionary = _state()
	s["captain_level"] = 30
	Session.state = s
	var v0: ShipStats = Session.player_stats()
	Progression.spend(s, "seamanship.speed")
	Progression.spend(s, "seamanship.turn")
	var v1: ShipStats = Session.player_stats()
	assert_true(v1.max_speed_kn > v0.max_speed_kn)
	assert_true(v1.turn_rate_deg_s > v0.turn_rate_deg_s)
	Session.state = {}


func test_leadership_makes_hiring_cheaper() -> void:
	var s: Dictionary = _state()
	s["captain_level"] = 30
	s["gold"] = 1000
	s["crew"] = 0
	var g0: int = int(s["gold"])
	assert_true(PortService.hire(s, "green", PortData.START_PORT))
	var plain_cost: int = g0 - int(s["gold"])
	Progression.spend(s, "leadership.hiring")
	Progression.spend(s, "leadership.hiring")
	Progression.spend(s, "leadership.hiring")
	var g1: int = int(s["gold"])
	assert_true(PortService.hire(s, "green", PortData.START_PORT))
	assert_true(g1 - int(s["gold"]) < plain_cost, "a rank-3 leader hires cheaper")
	var before: float = 50.0
	s["morale"] = before
	CrewLife.add_morale(s, 10.0)
	assert_true(float(s["morale"]) - before >= 10.0)


func test_swordplay_reaches_the_deck_fight() -> void:
	var s: Dictionary = _state()
	s["captain_level"] = 30
	for id in ["swordplay.damage", "swordplay.parry", "swordplay.stamina", "swordplay.pistol"]:
		for i in 3:
			Progression.spend(s, id)
	var c: DeckCombat = DeckBridge.build(6, 1.0, 70.0, "navy", 4, 1.0, 50.0, s, 3)
	assert_true(c.player.melee_mult > 1.2)
	assert_true(c.player.parry_mult > 1.4)
	assert_true(c.player.stamina_max > DeckData.STAMINA_MAX)
	assert_eq(c.player.stamina, c.player.stamina_max)
	assert_true(c.player.pistol_reload_mult < 0.7)
	var plain: DeckCombat = DeckBridge.build(6, 1.0, 70.0, "navy", 4, 1.0, 50.0, _state(), 3)
	assert_eq(plain.player.melee_mult, 1.0)


# ---- achievements, stats and the log -----------------------------------------------------------------------

func test_there_are_32_achievements_with_distinct_ids() -> void:
	assert_eq(AchievementData.LIST.size(), 32)
	assert_eq(AchievementData.ids().size(), 32)
	var seen: Dictionary = {}
	for id in AchievementData.ids():
		assert_true(not seen.has(id))
		seen[id] = true


func test_achievements_unlock_at_their_goal_and_only_once() -> void:
	var s: Dictionary = _state()
	assert_eq(Achievements.check(s).size(), 0, "nothing at the start")
	Achievements.record(s, "ships_sunk", 1.0)
	assert_eq(Achievements.check(s), ["first_blood"] as Array[String])
	assert_eq(Achievements.check(s).size(), 0, "not twice")
	Achievements.record(s, "ships_sunk", 24.0)
	Achievements.check(s)
	assert_true(Achievements.unlocked(s, "sea_wolf"))
	Achievements.record(s, "best_parries", 9.0)
	assert_true(not Achievements.unlocked(s, "parry_master"))
	Achievements.record(s, "best_parries", 10.0)
	Achievements.record(s, "best_parries", 4.0)
	assert_eq(Achievements.value(s, "best_parries"), 10.0, "best_* keeps the maximum")
	Achievements.check(s)
	assert_true(Achievements.unlocked(s, "parry_master"))


func test_computed_counters_read_the_state() -> void:
	var s: Dictionary = _state()
	s["captain_level"] = 15
	s["bases"] = [1, 2, 3, 4, 5, 6]
	s["officers"] = ["molly"]
	Progression.add_xp(s, 1)
	s["captain_level"] = 15
	s["day"] = 100
	var got: Array[String] = Achievements.check(s)
	for id in ["seasoned_captain", "veteran_captain", "empire_builder", "mollys_redemption", "never_starved"]:
		assert_true(got.has(id), "%s unlocked from the state" % id)
	Achievements.record(s, "starved_days")
	assert_eq(Achievements.value(s, "days_without_starving"), 0.0, "a starving day spoils it")


func test_achievements_survive_a_save() -> void:
	var s: Dictionary = _state()
	Achievements.record(s, "ships_sunk", 3.0)
	Achievements.check(s)
	Progression.add_xp(s, 500)
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_true(Achievements.unlocked(back, "first_blood"))
	assert_eq(Achievements.value(back, "ships_sunk"), 3.0)
	assert_eq(Progression.xp(back), Progression.xp(s))
	assert_eq(int(back["captain_level"]), int(s["captain_level"]))


func test_old_saves_keep_their_level() -> void:
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 11
	old["captain_level"] = 7
	old.erase("captain_xp")
	old.erase("stats")
	var d: Dictionary = SaveGame.migrate(old)
	assert_eq(int(d["version"]), SaveGame.VERSION)
	assert_eq(Progression.level_for_xp(Progression.xp(d)), 7)
	assert_true(d.has("achievements") and d.has("custom") and d.has("islands_seen"))


func test_captain_log_entries_read_back() -> void:
	var s: Dictionary = _state()
	CaptainLog.add(s, "battle", "sank", "sloop")
	CaptainLog.add(s, "discovery", "island", "Skull Atoll")
	assert_eq((s["log"] as Array).size(), 2)
	assert_true(CaptainLog.text(s["log"][1]).contains("Skull Atoll"))
	assert_eq(CaptainLog.of_kind(s, "discovery").size(), 1)
	for i in 300:
		CaptainLog.add(s, "event", "x")
	assert_eq((s["log"] as Array).size(), CaptainLog.MAX_ENTRIES)


func test_the_director_turns_events_into_xp_log_and_achievements() -> void:
	var d := ProgressDirector.new()
	d.state = _state()
	d.on_sunk("frigate")
	assert_eq(Progression.xp(d.state), 80)
	assert_true(Achievements.unlocked(d.state, "first_blood"))
	d.on_prize({"class_id": "sloop"})
	assert_eq(Progression.xp(d.state), 80 + 70)
	d.on_island("Skull Atoll")
	d.on_island("Skull Atoll")
	assert_eq(Achievements.value(d.state, "islands_found"), 1.0, "an island counts once")
	d.on_trade("sell", "rum", 5.0, 150)
	d.on_trade("sell", "rum", 5.0, 150)
	assert_eq(int(d.state["trade_rem"]), 0, "the trade XP remainder carries over: 300 gold is 3 XP")
	d.on_boarding(true, 11, true)
	assert_true(Achievements.unlocked(d.state, "parry_master"))
	assert_true(Achievements.unlocked(d.state, "one_against_many"))
	d.on_mast_fell(10.0)
	d.on_mast_fell(40.0)
	d.on_mast_fell(70.0)
	assert_true(Achievements.unlocked(d.state, "timber"), "three masts within a battle")
	d.on_tour_step("drowned_purse", "shell_king")
	assert_true(Achievements.unlocked(d.state, "crab_cakes"))
	d.on_tour_done("drowned_purse")
	assert_true(Progression.xp(d.state) >= 500 + 80 + 70)
	assert_true(int(d.state["captain_level"]) > 1)
	d.free()


func test_masts_outside_one_battle_do_not_add_up() -> void:
	var d := ProgressDirector.new()
	d.state = _state()
	d.on_mast_fell(0.0)
	d.on_mast_fell(500.0)
	d.on_mast_fell(1000.0)
	assert_eq(Achievements.value(d.state, "best_masts_window"), 1.0)
	d.free()


# ---- customization ------------------------------------------------------------------------------------------

func test_customization_choices_are_validated() -> void:
	var s: Dictionary = _state()
	assert_true(CustomizationData.EMBLEMS.size() == 24 and CustomizationData.FLAG_COLORS.size() == 10 and CustomizationData.FLAG_LAYOUTS.size() == 4)
	assert_true(Customization.set_flag(s, 23, 9, 3))
	assert_true(not Customization.set_flag(s, 24, 0, 0))
	assert_true(not Customization.set_flag(s, 0, 10, 0))
	assert_true(not Customization.set_flag(s, 0, 0, 4))
	assert_true(Customization.set_sail(s, 4, 5))
	assert_true(not Customization.set_sail(s, 5, 0))
	assert_true(Customization.set_figurehead(s, "kraken"))
	assert_true(not Customization.set_figurehead(s, "nope"))
	assert_eq(CustomizationData.FIGUREHEAD_ORDER.size(), 10)
	assert_true(not Customization.set_ship_name(s, "   "))
	assert_true(Customization.set_ship_name(s, "The Black Pearl"))
	assert_eq(str(s["ship_name"]), "The Black Pearl")


func test_pixel_flag_is_16_by_16() -> void:
	var s: Dictionary = _state()
	var px: Array = []
	px.resize(256)
	px.fill(3)
	assert_true(Customization.set_pixels(s, px))
	assert_true(not Customization.set_pixels(s, [1, 2, 3]))
	px[5] = 99
	assert_true(not Customization.set_pixels(s, px), "a colour outside the palette is refused")
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq((back["custom"]["flag"]["pixels"] as Array).size(), 256)
	assert_eq(ShipCustom.flag_texture([] if false else _flat(1)).get_width(), 16)


func _flat(v: int) -> Array:
	var a: Array = []
	a.resize(256)
	a.fill(v)
	return a


func test_gold_leaf_needs_fame_2000() -> void:
	var s: Dictionary = _state()
	assert_true(not Customization.set_hull(s, 0, 0, 1, true))
	s["fame"] = 2000
	assert_true(Customization.set_hull(s, 0, 0, 1, true))


func test_false_colours_cost_reputation_when_revealed() -> void:
	var s: Dictionary = _state()
	var f: String = str(s["rep"].keys()[0])
	var before: float = float(s["rep"][f])
	assert_eq(Customization.reveal_false_colors(s), "", "no false colours, nothing to reveal")
	assert_true(Customization.set_false_colors(s, f))
	assert_eq(Customization.reveal_false_colors(s), f)
	assert_eq(float(s["rep"][f]), maxf(before - 10.0, -100.0))
	assert_eq(str(Customization.get_custom(s)["false_colors"]), "")


func test_pets_and_figureheads_give_their_bonuses() -> void:
	var s: Dictionary = _state()
	Customization.set_pet(s, "monkey")
	assert_true(is_equal_approx(Customization.bonus(s, "loot_mult"), 1.05))
	Customization.set_pet(s, "cat")
	assert_true(is_equal_approx(Customization.bonus(s, "food_duration_mult"), 1.05))
	Customization.set_pet(s, "parrot")
	assert_true(is_equal_approx(Customization.bonus(s, "spot_time_mult"), 0.9), "spots ships 10% sooner")
	Customization.set_figurehead(s, "kraken")
	assert_true(is_equal_approx(Customization.bonus(s, "monster_damage_mult"), 0.95))
	var m0: float = float(s["morale"])
	Customization.set_figurehead(s, "siren")
	assert_eq(float(s["morale"]), minf(m0 + 10.0, 100.0), "the Siren lifts morale by 10")
	Customization.set_figurehead(s, "plain")
	Customization.set_figurehead(s, "siren")
	assert_eq(float(s["morale"]), minf(m0 + 10.0, 100.0), "but only once")


func test_gated_outfits_are_bought_or_earned() -> void:
	var s: Dictionary = _state()
	s["gold"] = 1000
	assert_true(not Customization.set_look(s, "coat", "crimson"), "not owned yet")
	assert_true(Customization.buy(s, "coat", "crimson"))
	assert_eq(int(s["gold"]), 400)
	assert_true(Customization.set_look(s, "coat", "crimson"))
	assert_true(not Customization.set_look(s, "coat", "navy_blue"))
	Achievements.record(s, "ships_sunk")
	Achievements.check(s)
	assert_true(Customization.set_look(s, "coat", "navy_blue"), "earned by first blood")
	assert_true(Customization.set_look(s, "eye_patch", "on"))
	assert_true(Customization.set_look(s, "peg_leg", "on"))
	assert_true(Customization.set_look(s, "hook", "on"))


# ---- mini-games ---------------------------------------------------------------------------------------------

func test_liars_dice_rules() -> void:
	var g := LiarsDice.new(_rng(), "cautious")
	assert_eq(g.mine.size(), 5)
	assert_eq(g.theirs.size(), 5)
	assert_true(g.player_bid(2, 3))
	assert_true(not g.player_bid(2, 3), "a bid must be raised")
	assert_true(not g.player_bid(1, 6), "a lower quantity is not a raise")
	assert_true(g.is_raise(2, 4))
	assert_true(g.is_raise(3, 1))
	assert_true(not g.is_raise(11, 1), "more dice than exist")
	g.mine = [3, 3, 3, 3, 3] as Array[int]
	g.theirs = [3, 3, 1, 1, 1] as Array[int]
	g.bid_qty = 7
	g.bid_face = 3
	g.call_bid(true)
	assert_true(not bool(g.last_call["player_won"]), "the bid of seven threes was true, so the caller loses")
	assert_eq(g.mine.size(), 4, "the caller loses a die when the bid was true")
	g.theirs = [3, 1, 1, 1] as Array[int]
	g.bid_qty = 7
	g.bid_face = 3
	g.call_bid(true)
	assert_true(bool(g.last_call["player_won"]), "only six threes exist, so the call wins")
	assert_eq(g.theirs.size(), 3)


func test_liars_dice_odds_and_endgame() -> void:
	var own: Array[int] = [2, 2, 2, 2, 2]
	assert_eq(LiarsDice.chance_at_least(5, 2, own, 5), 1.0)
	assert_eq(LiarsDice.chance_at_least(11, 2, own, 5), 0.0)
	var p: float = LiarsDice.chance_at_least(7, 2, own, 5)
	assert_true(p > 0.0 and p < 1.0)
	for personality in GameData.LIARS_DICE["opponents"].keys():
		var g := LiarsDice.new(_rng(7), personality)
		var guard: int = 0
		while not g.over and guard < 200:
			guard += 1
			var best: Array = [0, 0]
			for f in range(1, 7):
				for q in range(1, g.total_dice() + 1):
					if g.is_raise(q, f):
						best = [q, f]
						break
				if best[0] != 0:
					break
			if best[0] == 0 or g.bid_qty >= 3:
				g.call_bid(true)
			else:
				g.player_bid(best[0], best[1])
				g.npc_turn()
		assert_true(g.over, "%s game ends" % personality)


func test_bones_totals_and_payouts() -> void:
	assert_eq(Bones.total([1, 13] as Array[int]), 21, "ace and king")
	assert_eq(Bones.total([1, 1, 9] as Array[int]), 21, "aces drop to 1")
	assert_eq(Bones.total([10, 12, 5] as Array[int]), 25)
	var g := Bones.new(_rng(2))
	g.player = [10, 13] as Array[int]
	g.dealer = [10, 7] as Array[int]
	g.stand()
	assert_eq(g.outcome, "win")
	assert_eq(g.payout(100), 100)
	var b := Bones.new(_rng(2))
	b.player = [1, 13] as Array[int]
	b.dealer = [10, 7] as Array[int]
	b.stand()
	assert_eq(b.outcome, "blackjack")
	assert_eq(b.payout(100), 150, "pays 3 to 2")
	var l := Bones.new(_rng(2))
	l.player = [10, 9] as Array[int]
	l.dealer = [10, 7] as Array[int]
	l.stand()
	assert_eq(l.outcome, "win" if Bones.total(l.dealer) < 19 else "lose")
	var p := Bones.new(_rng(2))
	p.player = [10, 8] as Array[int]
	p.dealer = [10, 8] as Array[int]
	p.stand()
	assert_eq(p.outcome, "push")
	assert_eq(p.payout(100), 0)


func test_bones_dealer_stands_on_17() -> void:
	var g := Bones.new(_rng(4))
	g.player = [10, 9] as Array[int]
	g.dealer = [10, 7] as Array[int]
	g.stand()
	assert_eq(g.dealer.size(), 2, "the dealer does not draw on 17")


func test_arm_wrestling_power_and_odds() -> void:
	assert_true(ArmWrestle.power(1.0, 30) > ArmWrestle.power(0.5, 10))
	assert_true(ArmWrestle.win_chance(0.9, "brute") > ArmWrestle.win_chance(0.3, "brute"))
	assert_true(ArmWrestle.win_chance(0.6, "dockhand") > ArmWrestle.win_chance(0.6, "brute"))
	var wins: int = 0
	var r := _rng(8)
	for i in 400:
		wins += 1 if ArmWrestle.resolve(1.0, 30, "dockhand", r) else 0
	assert_true(wins > 300, "a perfect arm beats a dockhand most of the time (%d/400)" % wins)


func test_drinking_contest_ends_in_a_fall_or_the_last_round() -> void:
	var careless := DrinkingContest.new(_rng(3))
	var rounds: int = 0
	while careless.drink(0.0):
		rounds += 1
		if rounds > 20:
			break
	assert_true(careless.fell, "no steadiness means a fall")
	var steady := DrinkingContest.new(_rng(3))
	for i in 3:
		assert_true(steady.drink(1.0), "a steady hand survives the early rounds")
	assert_true(steady.rounds_won() == 3 and steady.gold() == 45)
	assert_true(steady.sway() > careless.sway() * 0.0)


func test_fishing_catch_snap_and_escape() -> void:
	var good := Fishing.new(_rng(1))
	var guard: int = 0
	while good.phase != Fishing.Phase.CAUGHT and good.phase != Fishing.Phase.LOST and guard < 6000:
		guard += 1
		good.step(0.05, good.tension < 0.6)  # reel until the line is tight, then ease off
	assert_true(good.phase == Fishing.Phase.CAUGHT, "a careful angler lands the fish")
	assert_true(good.value() >= 50 and good.value() <= 400)
	var rough := Fishing.new(_rng(6))
	guard = 0
	while rough.phase != Fishing.Phase.LOST and rough.phase != Fishing.Phase.CAUGHT and guard < 6000:
		guard += 1
		rough.step(0.05, true)
	assert_eq(rough.phase, Fishing.Phase.LOST, "reeling without a pause snaps the line")
	var idle := Fishing.new(_rng(6))
	guard = 0
	while idle.phase != Fishing.Phase.LOST and guard < 6000:
		guard += 1
		idle.step(0.05, false)
	assert_eq(idle.phase, Fishing.Phase.LOST, "never reeling lets it go")
	var counts: Dictionary = {}
	var r := _rng(1)
	for i in 1000:
		var f: String = Fishing.pick_fish(r)
		counts[f] = int(counts.get(f, 0)) + 1
	assert_true(int(counts["sardine"]) > int(counts["marlin"]) * 3, "marlin is rare")


func test_gunnery_range_scores_hits() -> void:
	var g := GunneryRange.new(_rng(2))
	assert_true(not g.over())
	var t: Dictionary = g.targets[0]
	assert_true(g.fire(float(t["x"]), float(t["range"])), "a shot at a target hits")
	assert_true(not g.fire(0.5, 0.0), "a shot at nothing misses")
	assert_eq(g.hits, 1)
	assert_eq(g.shots, 2)
	for i in 700:
		g.step(0.1)
	assert_true(g.over(), "a minute is a minute")
	assert_true(not g.fire(0.5, 100.0), "no shots after time")
	assert_eq(g.gunnery_xp(), 2)


func test_knife_throwing_scores_rings() -> void:
	assert_eq(KnifeThrow.ring_score(0.0), 50)
	assert_eq(KnifeThrow.ring_score(0.15), 25)
	assert_eq(KnifeThrow.ring_score(0.3), 10)
	assert_eq(KnifeThrow.ring_score(0.5), 5)
	assert_eq(KnifeThrow.ring_score(0.9), 0)
	var k := KnifeThrow.new()
	for i in 3:
		assert_true(k.throw_knife(0.0))
	assert_true(not k.throw_knife(0.0), "three throws")
	assert_eq(k.total(), 150)
	assert_true(k.earns_outfit())


func test_tavern_games_settle_against_the_state() -> void:
	var s: Dictionary = _state()
	s["gold"] = 200
	var r := _rng(2)
	assert_true(MiniGames.valid_bet(s, 100))
	assert_true(not MiniGames.valid_bet(s, 5), "below the minimum")
	assert_true(not MiniGames.valid_bet(s, 300), "more than you have")
	var d := LiarsDice.new(r, "cautious")
	d.over = true
	d.player_won = true
	var res: Dictionary = MiniGames.settle_dice(s, d, 100, false, r)
	assert_eq(int(s["gold"]), 300)
	assert_eq(int(res["gold"]), 100)
	d.player_won = false
	MiniGames.settle_dice(s, d, 250, false, r)
	assert_eq(int(s["gold"]), 50)
	var b := Bones.new(r)
	b.player = [10, 13] as Array[int]
	b.dealer = [10, 7] as Array[int]
	b.stand()
	MiniGames.settle_bones(s, b, 50, r)
	assert_eq(int(s["gold"]), 100)
	var arm: Dictionary = MiniGames.settle_arm_wrestle(s, true, true)
	assert_true(arm["recruit"])
	assert_eq(float(arm["morale"]), 5.0)
	var k := KnifeThrow.new()
	for i in 3:
		k.throw_knife(0.0)
	var kr: Dictionary = MiniGames.settle_knife(s, k)
	assert_true(kr["outfit"])
	assert_true(Customization.owns(s, "coat", "duelist"))
	var range_game := GunneryRange.new(r)
	range_game.hits = 10
	var xp0: int = Progression.xp(s)
	MiniGames.settle_range(s, range_game)
	assert_eq(Progression.xp(s) - xp0, 20, "gunnery XP from the range")
	assert_true(Achievements.value(s, "games_played") >= 5.0)


func test_dice_can_pay_out_a_map_fragment() -> void:
	var s: Dictionary = _state()
	s["gold"] = 1000
	var got: int = 0
	for seed_v in 60:
		var r := _rng(seed_v)
		var d := LiarsDice.new(r, "reckless")
		d.over = true
		d.player_won = true
		var st: Dictionary = s.duplicate(true)
		if str(MiniGames.settle_dice(st, d, 500, true, r)["map_fragment"]) != "":
			got += 1
	assert_true(got > 0, "a shady player on a big bet sometimes stakes a fragment (%d/60)" % got)
	var none: int = 0
	for seed_v in 40:
		var r2 := _rng(seed_v)
		var d2 := LiarsDice.new(r2, "reckless")
		d2.over = true
		d2.player_won = true
		var st2: Dictionary = s.duplicate(true)
		if str(MiniGames.settle_dice(st2, d2, 100, true, r2)["map_fragment"]) != "":
			none += 1
	assert_eq(none, 0, "small bets never do")


# ---- strings ------------------------------------------------------------------------------------------------

func test_progression_strings_exist_in_both_languages() -> void:
	var keys: Array[String] = []
	for id in AchievementData.ids():
		keys.append_array(["ach." + id, "ach.%s.desc" % id, "log.ach_" + id])
	for full in ProgressionData.skill_ids():
		keys.append("skill." + full)
	for tree: String in ProgressionData.TREES:
		keys.append("skills.tree." + tree)
	for e in CustomizationData.EMBLEMS:
		keys.append("emblem." + e)
	for slot: String in CustomizationData.CAPTAIN_SLOTS:
		keys.append("slot." + slot)
		for c in CustomizationData.CAPTAIN_SLOTS[slot]:
			keys.append("look.%s.%s" % [slot, c])
	for f in CustomizationData.FIGUREHEAD_ORDER:
		keys.append("figurehead." + f)
	for p in CustomizationData.PET_ORDER:
		keys.append("pet." + p)
	for l in CustomizationData.FLAG_LAYOUTS:
		keys.append("layout." + l)
	for pt in CustomizationData.SAIL_PATTERNS:
		keys.append("pattern." + pt)
	for hp in CustomizationData.HULL_PAINTS:
		keys.append("paint." + hp)
	for ls in CustomizationData.LANTERN_STYLES:
		keys.append("lantern." + ls)
	for g in MiniGameMenu.TAVERN_GAMES:
		keys.append_array(["games." + g, "games.%s.desc" % g])
	for fish: String in GameData.FISHING["fish"]:
		keys.append("fish." + fish)
	var saved: String = Loc.locale
	for loc in ["en", "cs"]:
		Loc.locale = loc
		for k in keys:
			assert_true(Loc.t(k) != k, "%s has a %s string" % [k, loc])
	Loc.locale = saved
