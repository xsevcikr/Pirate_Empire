extends TestCase
## City guards: the watch a harbour sends out when the player fires on it, and the war chest for beating it.


func test_bigger_cities_send_more_guards() -> void:
	var last: int = 0
	for tier: String in ["village", "town", "city", "capital"]:
		var n: int = CityGuardData.wave_for(tier).size()
		assert_true(n >= last, "%s sends at least as many boats as a smaller city" % tier)
		last = n
		for class_id: String in CityGuardData.wave_for(tier):
			assert_true(ResourceLoader.exists("res://data/ships/%s.tres" % class_id), "guard class %s exists" % class_id)


func test_rewards_grow_with_city_size() -> void:
	var lo: Dictionary = CityGuardData.reward_for("village")
	var hi: Dictionary = CityGuardData.reward_for("capital")
	for k: String in ["gold", "round", "pistol_shots", "rum"]:
		assert_true(float(hi[k]) > float(lo[k]), "a capital pays more %s than a village" % k)


func test_pay_adds_gold_ammo_and_rum() -> void:
	var s: Dictionary = SaveGame.new_state()
	var gold0: int = int(s["gold"])
	var round0: int = int(s["ammo"]["round"])
	var shots0: int = int(s["pistol_shots"])
	var rum0: float = float(s["supplies"]["rum"])
	var r: Dictionary = CityGuardData.pay(s, "city")
	assert_eq(int(s["gold"]), gold0 + int(r["gold"]))
	assert_eq(int(s["ammo"]["round"]), round0 + int(r["round"]))
	assert_eq(int(s["pistol_shots"]), shots0 + int(r["pistol_shots"]))
	assert_near(float(s["supplies"]["rum"]), rum0 + float(r["rum"]), 0.001)


func test_one_watch_at_a_time_and_a_cooldown_after_defeat() -> void:
	assert_true(CityGuardData.can_launch("blackwater", 5, {}, {}))
	assert_true(not CityGuardData.can_launch("blackwater", 5, {"blackwater": []}, {}), "a watch already out")
	assert_true(not CityGuardData.can_launch("blackwater", 5, {}, {"blackwater": 4}), "just beaten")
	assert_true(CityGuardData.can_launch("blackwater", 4 + CityGuardData.COOLDOWN_DAYS, {}, {"blackwater": 4}), "raised again later")


func test_guards_launch_seaward_of_the_dock() -> void:
	var dock := Vector2(0, 360)
	var island := Vector2(0, 0)
	var pts: Array[Vector2] = CityGuardData.launch_points(dock, island, 3)
	assert_eq(pts.size(), 3)
	for p in pts:
		assert_true(p.distance_to(island) > dock.distance_to(island), "boat starts out to sea")
	assert_true(pts[0].distance_to(pts[2]) > 1.0, "boats are spread out")
	assert_true(FactionRel.aggressive_toward(CityGuardData.GUARD_FACTION, "player"), "guards attack the player")


func test_guards_do_not_launch_on_top_of_the_player() -> void:
	var player := Vector2(0, 480)
	var pts: Array[Vector2] = CityGuardData.launch_points(Vector2(0, 360), Vector2.ZERO, 3, player)
	for p in pts:
		assert_true(p.distance_to(player) >= CityGuardData.CLEAR_OF_PLAYER_M, "boat starts clear of the player")
