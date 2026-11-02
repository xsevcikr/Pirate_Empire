extends TestCase
## Visible ship upgrades: sails, flags and cannons bought at the shipyard and shown on the ship.


func _state(gold: int = 100000) -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = gold
	return s


func _ship(class_id: String) -> Ship:
	var ship := Ship.new()
	ship.stats = PortService.ship_stats(class_id)
	ship.faction = "player"
	var v := ShipVisuals.new()
	v.build(ship)
	ship.visuals = v
	return ship


func _count(n: Node, kind: String) -> int:
	var c: int = 1 if n.has_meta("kind") and str(n.get_meta("kind")) == kind else 0
	for ch in n.get_children():
		c += _count(ch, kind)
	return c


func test_new_game_starts_plain_and_old_saves_load() -> void:
	var s: Dictionary = _state()
	for line in ShipLooks.LINES:
		assert_eq(ShipLooks.tier(s, line), 0, line)
	var old: Dictionary = SaveGame.new_state()
	old.erase("looks")
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(old))
	assert_eq(ShipLooks.tier(back, "flags"), 0)


func test_buying_climbs_tiers_costs_gold_and_cheers_the_crew() -> void:
	var s: Dictionary = _state(1000)
	s["morale"] = 60.0
	assert_true(ShipLooks.buy(s, "flags"))
	assert_eq(int(s["gold"]), 1000 - ShipLooks.COST["flags"][0])
	assert_eq(ShipLooks.tier(s, "flags"), 1)
	assert_near(float(s["morale"]), 60.0 + ShipLooks.CHEER_MORALE, 0.001)
	assert_true(not ShipLooks.buy(s, "cannons") or ShipLooks.tier(s, "cannons") == 1)
	var poor: Dictionary = _state(10)
	assert_true(not ShipLooks.buy(poor, "sails"), "too poor")
	assert_eq(int(poor["gold"]), 10)
	assert_true(not ShipLooks.buy(s, "hull"), "not a look")


func test_lines_stop_at_the_top_tier_and_survive_a_save() -> void:
	var s: Dictionary = _state()
	for i in ShipLooks.TIERS:
		assert_true(ShipLooks.buy(s, "cannons"))
	assert_true(not ShipLooks.buy(s, "cannons"), "maxed")
	assert_eq(ShipLooks.next_cost(s, "cannons"), 0)
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(ShipLooks.tier(back, "cannons"), ShipLooks.TIERS)


func test_every_look_has_a_name_in_both_languages() -> void:
	for line in ShipLooks.LINES:
		assert_eq((ShipLooks.COST[line] as Array).size(), ShipLooks.TIERS, line)
		for t in ShipLooks.TIERS + 1:
			assert_true(Loc.t(ShipLooks.name_key(line, t)) != ShipLooks.name_key(line, t), ShipLooks.name_key(line, t))


func test_shipyard_sells_looks_on_its_own_tab() -> void:
	var src := ShipyardCatalogue.new()
	src.port_id = PortData.START_PORT
	assert_true(src.categories().has("cat.looks"))
	var s: Dictionary = _state(5000)
	var flags: CatalogueItem = null
	for it in src.items(s):
		if it.id == "look:flags":
			flags = it
	assert_true(flags != null)
	assert_eq(flags.category, "cat.looks")
	assert_eq(flags.price, ShipLooks.COST["flags"][0])
	assert_true(src.buy(s, flags))
	assert_eq(ShipLooks.tier(s, "flags"), 1)
	assert_true(src.icon_list().has("pirate/flag-pirate"))


func test_looks_change_the_ship() -> void:
	var ship: Ship = _ship("brigantine")
	var v: ShipVisuals = ship.visuals
	var s: Dictionary = _state()
	ShipLooks.apply(v, s)
	assert_eq(_count(v.root, "look_gun"), 0)
	assert_true(v.gun_nodes.size() > 0)
	assert_true(v.gun_nodes[0].visible)
	for i in ShipLooks.TIERS:
		for line in ShipLooks.LINES:
			ShipLooks.buy(s, line)
	ShipLooks.apply(v, s)
	ShipLooks.apply(v, s)  # applying twice must not stack a second set
	assert_eq(v.root.get_children().filter(func(n: Node) -> bool: return n.name == "Looks").size(), 1)
	var looks: Node = v.root.get_node("Looks")
	assert_eq(_count(looks, "look_gun"), v.gun_nodes.size())
	assert_true(not v.gun_nodes[0].visible, "kit guns hidden")
	assert_eq(_count(looks, "swivel"), 4)
	assert_eq(_count(looks, "bow_chaser"), 2)
	assert_eq(_count(looks, "bunting"), 1)
	assert_eq(_count(looks, "streamer"), v.flag_nodes.size() - 1)
	assert_eq(_count(looks, "finial"), v.flag_nodes.size() - 1)
	assert_near(v.flag_nodes[v.flag_nodes.size() - 1].scale.x, ShipLooks.ENSIGN_SCALE[ShipLooks.TIERS], 0.001)
	var sail: ShaderMaterial = v.sail_materials[0]
	assert_true(bool(sail.get_shader_parameter("custom")))
	assert_eq(int(sail.get_shader_parameter("pattern")), int(ShipLooks.SAILS[ShipLooks.TIERS]["pattern"]))
	ship.free()


func test_own_sail_colours_win_over_bought_sails() -> void:
	var ship: Ship = _ship("sloop")
	var v: ShipVisuals = ship.visuals
	var s: Dictionary = _state()
	var custom: Dictionary = Customization.get_custom(s)
	custom["sail"] = {"pattern": 1, "color": 4}
	ShipCustom.apply(ship, custom)
	ShipLooks.buy(s, "sails")
	ShipLooks.buy(s, "sails")
	ShipLooks.buy(s, "sails")
	ShipLooks.apply(v, s)
	var sail: ShaderMaterial = v.sail_materials[0]
	assert_eq(int(sail.get_shader_parameter("pattern")), 1, "the captain's own pattern stays")
	assert_near(float(sail.get_shader_parameter("trim_width")), float(ShipLooks.SAILS[3]["trim"]), 0.001)
	ship.free()
