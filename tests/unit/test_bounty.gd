extends TestCase
## The pirate reputation and bounty system: crimes raise a faction's bounty and the wanted stars, quiet days let it
## fade, governors pardon and haven clerks take bribes, four stars shut a flag's lawful ports, hunters come in waves,
## the navy pays for pirates, infamy climbs through the ranks, and the crew's shanties at sea.


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["day"] = 10
	return s


func test_crimes_raise_bounty_and_stars() -> void:
	var s: Dictionary = _state()
	assert_eq(Bounty.stars(s), 0)
	var moved: Vector2i = Bounty.crime(s, "navy", "sink")
	assert_eq(Bounty.value(s, "navy"), Bounty.CRIME["sink"])
	assert_eq(moved, Vector2i(0, 0))
	for i in 3:
		Bounty.crime(s, "navy", "capture")
	assert_eq(Bounty.stars(s), 1, "75 is one star")
	assert_eq(Bounty.top_faction(s), "navy")
	assert_eq(int(s["bounty_crime_day"]), 10)
	assert_true(int(s["fame"]) > 0, "sinking a lawful ship makes a name")
	for i in 40:
		Bounty.crime(s, "navy", "raze")
	assert_eq(Bounty.value(s, "navy"), Bounty.MAX, "capped")
	assert_eq(Bounty.stars(s), 5)


func test_pirates_post_no_bounty_and_marque_covers_its_enemy() -> void:
	var s: Dictionary = _state()
	Bounty.crime(s, "pirate", "sink")
	assert_eq(Bounty.stars(s), 0)
	assert_true(not s["bounty"].has("pirate"))
	s["marque"] = "iron_dominion"
	Bounty.crime(s, "iron_dominion", "sink")
	assert_eq(Bounty.value(s, "iron_dominion"), 0.0, "a letter of marque makes it lawful war")


func test_bounty_fades_after_a_quiet_day() -> void:
	var s: Dictionary = _state()
	Bounty.set_value(s, "merchant", 100.0)
	s["bounty_crime_day"] = 10
	Bounty.day_tick(s)
	assert_eq(Bounty.value(s, "merchant"), 100.0, "not on the day of the crime")
	s["day"] = 12
	Bounty.day_tick(s)
	assert_eq(Bounty.value(s, "merchant"), 100.0 - Bounty.DECAY_PER_DAY)


func test_pardon_needs_a_lawful_port_of_the_flag_and_tolerable_standing() -> void:
	var s: Dictionary = _state()
	Bounty.set_value(s, "navy", 60.0)
	s["gold"] = 100000
	assert_eq(Bounty.pardon_cost(s, "blackwater"), -1, "no governor at a haven")
	assert_eq(Bounty.pardon_cost(s, "meridian"), -1, "merchants cannot pardon the navy's bounty")
	s["rep"]["navy"] = -50.0
	assert_eq(Bounty.pardon_cost(s, "albion"), -1, "hostile navy will not deal")
	s["rep"]["navy"] = 0.0
	assert_eq(Bounty.pardon_cost(s, "albion"), 60 * Bounty.PARDON_GOLD_PER_POINT)
	assert_true(Bounty.pardon(s, "albion"))
	assert_eq(Bounty.value(s, "navy"), 0.0)
	assert_eq(int(s["gold"]), 100000 - 60 * Bounty.PARDON_GOLD_PER_POINT)


func test_haven_bribe_halves_any_flag() -> void:
	var s: Dictionary = _state()
	Bounty.set_value(s, "iron_dominion", 200.0)
	s["gold"] = 100000
	assert_eq(Bounty.bribe_cost(s, "albion", "iron_dominion"), -1, "no clerk to bribe at a lawful port")
	var cost: int = Bounty.bribe_cost(s, "blackwater", "iron_dominion")
	assert_eq(cost, 100 * Bounty.BRIBE_GOLD_PER_POINT)
	assert_true(Bounty.bribe(s, "blackwater", "iron_dominion"))
	assert_eq(Bounty.value(s, "iron_dominion"), 100.0)
	s["gold"] = 0
	assert_true(not Bounty.bribe(s, "blackwater", "iron_dominion"), "needs the gold")


func test_four_stars_shut_lawful_ports_of_that_flag() -> void:
	var s: Dictionary = _state()
	Bounty.set_value(s, "navy", 460.0)
	assert_eq(Bounty.stars(s), 4)
	assert_true(not Bounty.port_open(s, "albion"))
	assert_true(Bounty.port_open(s, "meridian"), "other flags still trade")
	assert_true(Bounty.port_open(s, "blackwater"), "havens never ask")


func test_hunters_come_in_waves() -> void:
	var s: Dictionary = _state()
	assert_true(not Bounty.hunters_due(s, 100.0))
	Bounty.set_value(s, "navy", 160.0)
	var wave: Dictionary = Bounty.hunters(Bounty.stars(s))
	assert_eq(int(wave["count"]), 2)
	assert_true(not Bounty.hunters_due(s, 100.0), "a head start first")
	assert_true(not Bounty.hunters_due(s, 100.0 + float(wave["interval_h"]) - 1.0))
	assert_true(Bounty.hunters_due(s, 100.0 + float(wave["interval_h"])))
	assert_true(not Bounty.hunters_due(s, 101.0 + float(wave["interval_h"])), "then the next interval")
	for row: Array in Bounty.HUNTER_CLASSES:
		for cls: String in row:
			assert_true(ResourceLoader.exists("res://data/ships/%s.tres" % cls), "hunter class " + cls)


func test_navy_pays_for_pirates_and_posters() -> void:
	var s: Dictionary = _state()
	var plain: int = Bounty.pirate_taken(s, 4000)
	assert_eq(plain, clampi(roundi(4000.0 * Bounty.PIRATE_REWARD_SHARE), Bounty.PIRATE_REWARD_RANGE.x, Bounty.PIRATE_REWARD_RANGE.y))
	var crew: String = PirateCrews.alive_ids(s)[0]
	var with_poster: int = Bounty.pirate_taken(s, 4000, crew)
	assert_eq(with_poster, plain + Bounty.poster_reward(s, crew))
	assert_eq(int(s["bounty_claims"]), plain + with_poster)
	assert_true(not Bounty.can_collect(s, "blackwater"), "havens do not pay navy rewards")
	var gold: int = int(s["gold"])
	assert_eq(Bounty.collect(s, "albion"), plain + with_poster)
	assert_eq(int(s["gold"]), gold + plain + with_poster)
	assert_eq(int(s["bounty_claims"]), 0)
	assert_eq(Bounty.posters(s).size(), PirateCrews.alive_ids(s).size())


func test_infamy_ranks_and_their_perks() -> void:
	assert_eq(Bounty.rank_id(0), "nobody")
	assert_eq(Bounty.rank_id(130), "buccaneer")
	assert_eq(Bounty.rank_id(5000), "pirate_lord")
	assert_eq(Bounty.to_next_rank(130), 300 - 130)
	assert_eq(Bounty.to_next_rank(5000), 0)
	var s: Dictionary = _state()
	s["fame"] = 700
	assert_near(Bounty.fear(s), 4.0 * Bounty.FEAR_PER_RANK, 0.0001)
	assert_true(Bounty.hire_mult(s, "blackwater") < 1.0 and Bounty.hire_mult(s, "albion") == 1.0)
	for r: Array in Bounty.RANKS:
		for k in ["rank." + str(r[1]), "rank.desc_" + str(r[1])]:
			assert_true(Loc.t(k) != k, "string " + k)


func test_fear_makes_merchants_strike_sooner() -> void:
	var ctx: Dictionary = {"hull_frac": 0.2, "crew_frac": 0.3, "hostile_seen": true, "hostile_dist": 300.0, "ratio": 0.5,
		"is_merchant": true, "personality": "disciplined", "lost_s": 0.0}
	assert_true(AiLogic.next_state(AiLogic.State.FLEE, ctx) != AiLogic.State.SURRENDER)
	ctx["fear"] = 0.1
	assert_eq(AiLogic.next_state(AiLogic.State.FLEE, ctx), AiLogic.State.SURRENDER)


func test_sea_shanty() -> void:
	var s: Dictionary = _state()
	s["morale"] = 30.0
	assert_eq(SeaShanty.refusal(s, false), "morale")
	s["morale"] = 60.0
	assert_eq(SeaShanty.refusal(s, true), "fight")
	assert_eq(SeaShanty.refusal(s, false), "")
	var a: Dictionary = SeaShanty.sing(s, 10)
	assert_eq(float(s["morale"]), 60.0 + SeaShanty.MORALE_GAIN, "the day's first song lifts morale")
	var b: Dictionary = SeaShanty.sing(s, 10)
	assert_eq(float(b["morale"]), 0.0, "once a day")
	assert_true(a["track"] != b["track"], "the next song is another one")
	assert_true(FileAccess.file_exists(AudioData.music_path(a["track"])))
	for sh: String in AudioData.SHANTIES:
		assert_true(Loc.t("tavern.sung_" + sh) != "tavern.sung_" + sh, "string for " + sh)
	assert_true(FileAccess.file_exists(AudioData.music_path(AudioData.MENU_TRACK)), "title music")


func test_save_v18_round_trip() -> void:
	var s: Dictionary = _state()
	Bounty.set_value(s, "navy", 120.0)
	s["bounty_claims"] = 300
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(int(back["version"]), SaveGame.VERSION)
	assert_eq(Bounty.value(back, "navy"), 120.0)
	assert_eq(int(back["bounty_claims"]), 300)
	var old: Dictionary = {"version": 17, "gold": 5, "bounty": {"navy": 70.0}}
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(int(m["version"]), SaveGame.VERSION)
	assert_eq(int(m["bounty_claims"]), 0)
	assert_eq(Bounty.stars(m), 1, "old bounties stand")
