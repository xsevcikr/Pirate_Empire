extends TestCase


func test_six_pounder_row() -> void:
	var g: Dictionary = GunData.GUNS["6pdr"]
	assert_eq(g["damage"], 40.0)
	assert_eq(g["velocity"], 330.0)
	assert_eq(g["effective"], 200.0)
	assert_eq(g["max"], 420.0)
	assert_eq(g["reload"], 6.0)


func test_damage_falloff() -> void:
	assert_near(GunData.damage_at_range("6pdr", 100.0), 40.0, 0.001)
	assert_near(GunData.damage_at_range("6pdr", 200.0), 40.0, 0.001)
	assert_near(GunData.damage_at_range("6pdr", 420.0), 16.0, 0.001, "40% at max range")
	assert_near(GunData.damage_at_range("6pdr", 310.0), 28.0, 0.01, "linear in between")


func test_ammo_multipliers_match_spec() -> void:
	assert_eq(GunData.AMMO["chain"]["sail"], 2.0)
	assert_eq(GunData.AMMO["grape"]["crew"], 3.0)
	assert_eq(GunData.AMMO["heated"]["fire"], 0.25)
	assert_eq(GunData.AMMO["explosive"]["hull"], 1.4)


func test_ship_class_table() -> void:
	var expect: Dictionary = {
		"sloop": [1200.0, 4, 14.0, 2000], "schooner": [2000.0, 6, 15.5, 9000],
		"brigantine": [3400.0, 9, 13.0, 22000], "frigate": [6000.0, 16, 12.5, 55000],
		"galleon": [8500.0, 20, 10.0, 85000], "man_o_war": [13000.0, 32, 9.5, 160000],
	}
	for id: String in expect:
		var s: ShipStats = load("res://data/ships/%s.tres" % id)
		assert_eq(s.hull_hp, expect[id][0], id + " hull")
		assert_eq(s.guns_per_side, expect[id][1], id + " guns")
		assert_eq(s.max_speed_kn, expect[id][2], id + " speed")
		assert_eq(s.price, expect[id][3], id + " price")
