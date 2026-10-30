extends TestCase
## New ship variants, the giant ships, and the beach landings on islands without a harbour.

const NEW: Array[String] = ["pinnace", "xebec", "corvette", "east_indiaman", "treasure_galleon", "dreadnought", "leviathan"]
const GIANTS: Array[String] = ["treasure_galleon", "dreadnought", "leviathan"]


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["fame"] = 99999
	return s


func test_every_class_on_sale_loads_and_is_named() -> void:
	for id in PortData.CLASS_ORDER:
		var st: ShipStats = PortService.ship_stats(id)
		assert_true(st != null, id + " loads")
		assert_eq(st.class_id, id)
		assert_true(Loc.t("ship." + id) != "ship." + id, id + " has a name")
		assert_true(Upgrades.CLASS_MULT.has(id), id + " has an upgrade multiplier")
		assert_true(GunData.GUNS.has(st.gun_id), id + " gun")


func test_giant_flag_matches_the_order() -> void:
	for id in PortData.CLASS_ORDER:
		assert_eq(PortService.ship_stats(id).giant, GIANTS.has(id), id)
		assert_eq(PortData.is_giant(id), GIANTS.has(id), id)


func test_giants_are_bigger_dearer_and_slower_than_the_man_o_war() -> void:
	var mow: ShipStats = PortService.ship_stats("man_o_war")
	for id in GIANTS:
		var g: ShipStats = PortService.ship_stats(id)
		assert_true(g.price > mow.price, id + " price")
		assert_true(g.length_m > mow.length_m, id + " length")
		assert_true(g.hull_hp > mow.hull_hp, id + " hull")
		assert_true(g.max_speed_kn <= mow.max_speed_kn, id + " speed")
		assert_true(g.turn_rate_deg_s < mow.turn_rate_deg_s, id + " handling")
		assert_true(g.infamy_required > mow.infamy_required, id + " fame")
		assert_eq(g.mast_count, 4, id + " masts")
	assert_true(PortService.ship_stats("treasure_galleon").cargo_t > 1000.0, "the treasure galleon is the big hauler")
	assert_true(PortService.ship_stats("leviathan").guns_per_side > PortService.ship_stats("dreadnought").guns_per_side)


func test_prices_rise_along_the_order() -> void:
	var last: int = 0
	for id in PortData.CLASS_ORDER:
		var p: int = PortService.ship_stats(id).price
		assert_true(p > last, "%s costs more than the class before it" % id)
		last = p


func test_giants_only_at_grand_shipyards() -> void:
	var yards: Array[String] = PortData.giant_yards()
	assert_true(yards.has("blackwater"), "Blackwater builds giants")
	assert_true(yards.size() >= 2 and yards.size() < PortData.PORTS.size())
	for port_id: String in PortData.PORTS:
		for id in GIANTS:
			assert_eq(PortData.can_sell_class(port_id, id), yards.has(port_id), "%s at %s" % [id, port_id])
	assert_true(PortData.can_sell_class("blackwater", "corvette"))
	assert_true(not PortData.can_sell_class("blackwater", "revenant"), "legendary ships are never for sale")


func test_village_sells_the_pinnace_town_the_xebec() -> void:
	var village: String = ""
	var town: String = ""
	for id: String in PortData.PORTS:
		if PortData.PORTS[id]["tier"] == "village" and village == "":
			village = id
		if PortData.PORTS[id]["tier"] == "town" and town == "":
			town = id
	assert_true(PortData.can_sell_class(village, "pinnace"))
	assert_true(not PortData.can_sell_class(village, "schooner"))
	assert_true(PortData.can_sell_class(town, "xebec"))
	assert_true(not PortData.can_sell_class(town, "corvette"))


func test_buy_a_giant_for_a_fortune() -> void:
	var s: Dictionary = _state()
	s["gold"] = 1000000
	s["ship_class"] = "man_o_war"
	s["ship_hull"] = 1.0
	var cost: int = PortService.ship_cost(s, "leviathan")
	assert_true(cost > 500000, "a giant costs a fortune even after trade-in")
	assert_true(PortService.buy_ship(s, "leviathan", "blackwater"))
	assert_eq(s["ship_class"], "leviathan")
	assert_eq(int(s["gold"]), 1000000 - cost)
	var poor: Dictionary = _state()
	poor["gold"] = 100000
	assert_true(not PortService.buy_ship(poor, "dreadnought", "blackwater"), "too poor")
	var rich_unknown: Dictionary = SaveGame.new_state()
	rich_unknown["gold"] = 1000000
	assert_true(not PortService.buy_ship(rich_unknown, "dreadnought", "blackwater"), "not famous enough")
	var s2: Dictionary = _state()
	s2["gold"] = 1000000
	assert_true(not PortService.buy_ship(s2, "dreadnought", "coral_landing"), "small yards cannot build giants")


func test_every_class_has_an_xp_tier_and_giant_upgrades_cost_more() -> void:
	for id in NEW:
		assert_true(ProgressionData.CLASS_TIER.has(id), id)
	assert_true(Upgrades.total_cost("leviathan") > Upgrades.total_cost("man_o_war"))


func test_four_masts_from_the_widest_gap() -> void:
	# the livery table only names real classes, and every one of them has a livery
	for id: String in ShipLivery.LIVERIES:
		assert_true(PortData.CLASS_ORDER.has(id), id)
	for id in NEW:
		assert_true(ShipLivery.has_livery(id), id + " has a livery")
	assert_eq(ShipLivery.gun_decks(PortService.ship_stats("leviathan")), 3)
	assert_eq(ShipLivery.gun_decks(PortService.ship_stats("corvette")), 1)


func test_ai_roster_respects_fame() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen: Dictionary = {}
	for i in 400:
		seen[ShipRoster.navy(rng, 0)] = true
		seen["m_" + ShipRoster.merchant(rng, 0)] = true
	assert_true(not seen.has("dreadnought") and not seen.has("m_treasure_galleon") and not seen.has("m_east_indiaman"), "no giants for a nobody")
	assert_true(seen.has("corvette") and seen.has("frigate"))
	seen.clear()
	for i in 400:
		seen[ShipRoster.navy(rng, 20000)] = true
		seen["m_" + ShipRoster.merchant(rng, 20000)] = true
	assert_true(seen.has("dreadnought") and seen.has("m_treasure_galleon") and seen.has("m_east_indiaman"), "a famous captain meets giants")
	assert_eq(ShipRoster.convoy(0, 5), "east_indiaman")
	assert_eq(ShipRoster.convoy(0, 2), TradeData.CONVOY_STATS[0])
	assert_eq(ShipRoster.ai_crew(PortService.ship_stats("frigate")), 14)
	assert_eq(ShipRoster.ai_crew(PortService.ship_stats("leviathan")), 300)


func test_rivals_late_ships_are_known_classes() -> void:
	for rid: String in RivalData.RIVALS:
		var d: Dictionary = RivalData.RIVALS[rid]
		if d.has("ship_late"):
			assert_true(PortService.ship_stats(str(d["ship_late"])) != null, rid)


# ---- harbours and landings -----------------------------------------------------------------------

func test_only_some_islands_have_harbours() -> void:
	var g: WorldGen = PortData.gen()
	var harbours: int = g.city_islands().size()
	assert_true(harbours > 0 and harbours < g.islands.size(), "some islands, not all")
	var landings: Array[int] = Landings.islands(g)
	assert_eq(harbours + landings.size() + Landings.RESERVED.size(), g.islands.size(), "every other island has a landing or is the lagoon")
	for i in landings:
		assert_eq(str(g.islands[i]["city"]), "", "a landing island has no harbour")
		assert_true(not Landings.RESERVED.has(str(g.islands[i]["name"])))
		var a: Vector2 = Landings.anchorage(g, i)
		assert_true(not g.is_land(a), "%s anchorage is in open water" % g.islands[i]["name"])
		assert_eq(Landings.near(g, a), i)
		assert_eq(PortData.port_near(a), "", "a landing is not a port")


func test_go_ashore_gives_supplies_once_per_cooldown() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["ship_class"] = "frigate"
	s["day"] = 10
	s["wounded"] = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var water: float = float(s["supplies"]["water"])
	var gold: int = int(s["gold"])
	var r: Dictionary = Landings.go_ashore(s, "Frostmourn", rng)
	assert_true(r["ok"])
	assert_eq(float(s["supplies"]["water"]), water + 6.0)
	assert_eq(int(s["gold"]), gold + int(r["gold"]))
	var again: Dictionary = Landings.go_ashore(s, "Frostmourn", rng)
	assert_true(not again["ok"])
	assert_eq(int(again["wait"]), Landings.COOLDOWN_DAYS)
	s["day"] = 10 + Landings.COOLDOWN_DAYS
	assert_true(Landings.go_ashore(s, "Frostmourn", rng)["ok"], "the beach is worth a visit again")
	var hot: Dictionary = Landings.go_ashore(s, "Cinder Bay", rng)
	assert_eq(int(hot["healed"]), 3)
	assert_eq(int(s["wounded"]), 0)
	assert_true(not Landings.go_ashore(s, "Skull Atoll", rng)["ok"], "the lagoon is not a landing")
	assert_true(not Landings.go_ashore(s, "Haven Rock", rng)["ok"], "a harbour island is not a landing")
	assert_true(Landings.summary(hot, "Cinder Bay").contains("Cinder Bay"))


func test_go_ashore_respects_the_hold() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["ship_class"] = "cutter"
	s["cargo"] = {"sugar": ceilf(PortService.cargo_capacity(s) / float(Goods.DATA["sugar"]["weight"]))}
	var before: float = float(s["supplies"]["timber"])
	var rng := RandomNumberGenerator.new()
	var r: Dictionary = Landings.go_ashore(s, "Bonefield Shoals", rng)
	assert_true(r["ok"])
	assert_eq(float(s["supplies"]["timber"]), before, "a full hold takes nothing aboard")


func test_save_v13_keeps_landing_visits() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["landings"] = {"Frostmourn": 7}
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(int(back["landings"]["Frostmourn"]), 7)
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 12
	old.erase("landings")
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(m["landings"], {})
	assert_eq(int(m["version"]), SaveGame.VERSION)
