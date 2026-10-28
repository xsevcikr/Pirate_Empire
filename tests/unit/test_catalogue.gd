extends TestCase
## Shop catalogues: the shipyard and outfitter sources, and the screen drawing a source it has never seen.


class FakeLagoon:
	extends CatalogueSource
	var sold: Array[String] = []

	func title_key() -> String:
		return "cat.title"

	func categories() -> PackedStringArray:
		return PackedStringArray(["cat.ships", "cat.supplies"])

	func items(s: Dictionary) -> Array[CatalogueItem]:
		var out: Array[CatalogueItem] = []
		out.append(CatalogueItem.make("rum", "cat.supplies", "Rum", "pirate/barrel", 30).stat("Heals", "50"))
		out.append(CatalogueItem.make("dock", "cat.supplies", "Dock", "", 5000).lock("needs a bigger lagoon"))
		var flag := CatalogueItem.make("flag", "cat.supplies", "Flag", "proc/sail", 10)
		if sold.has("flag"):
			flag.status = CatalogueItem.Status.OWNED
		out.append(flag)
		out.append(CatalogueItem.make("boat", "cat.ships", "Boat", "pirate/ship-pirate-small", 100))
		return out

	func buy(s: Dictionary, item: CatalogueItem) -> bool:
		s["gold"] = int(s["gold"]) - item.price
		sold.append(item.id)
		return true


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 100000
	return s


func _item(items: Array[CatalogueItem], id: String) -> CatalogueItem:
	for it in items:
		if it.id == id:
			return it
	return null


func test_money_has_thousands_commas() -> void:
	assert_eq(CatalogueScreen.money(0), "0")
	assert_eq(CatalogueScreen.money(950), "950")
	assert_eq(CatalogueScreen.money(12500), "12,500")
	assert_eq(CatalogueScreen.money(1234567), "1,234,567")
	assert_eq(CatalogueScreen.money(-4200), "-4,200")


func test_can_buy_needs_gold_and_an_open_card() -> void:
	var it := CatalogueItem.make("x", "cat.ships", "X", "", 50)
	assert_true(it.can_buy(50))
	assert_true(not it.can_buy(49))
	it.lock("nope")
	assert_true(not it.can_buy(1000))
	assert_eq(it.requirement, "nope")


func test_every_category_and_icon_is_ready() -> void:
	var s: Dictionary = _state()
	for src: CatalogueSource in [ShipyardCatalogue.new(), OutfitterCatalogue.new()]:
		var cats: PackedStringArray = src.categories()
		assert_true(Loc.t(src.title_key()) != src.title_key(), "title translated")
		for c in cats:
			assert_true(Loc.t(c) != c, "category %s translated" % c)
		for it: CatalogueItem in src.items(s):
			assert_true(cats.has(it.category), "%s sits in a known tab" % it.id)
			assert_true(Loc.t(it.action_key) != it.action_key, "%s button translated" % it.id)
			assert_true(not it.title.begins_with("cat.") and not it.blurb.begins_with("cat."), "%s text translated" % it.id)
			assert_true(src.icon_list().has(it.icon), "%s icon %s is listed for the icon tool" % [it.id, it.icon])
	for icon in CatalogueIcons.all():
		assert_true(ResourceLoader.exists(CatalogueIcons.path_of(icon)), "icon %s rendered" % icon)


func test_shipyard_upgrade_spends_gold_and_climbs_a_tier() -> void:
	var s: Dictionary = _state()
	var src := ShipyardCatalogue.new()
	src.port_id = PortData.START_PORT
	var hull: CatalogueItem = _item(src.items(s), "upg:hull")
	assert_eq(hull.tier, 0)
	assert_eq(hull.price, Upgrades.cost("hull", 1, s["ship_class"]))
	assert_true(src.buy(s, hull))
	assert_eq(int(s["gold"]), 100000 - hull.price)
	assert_eq(_item(src.items(s), "upg:hull").tier, 1)


func test_shipyard_last_tier_needs_a_big_yard_and_then_maxes() -> void:
	var s: Dictionary = _state()
	var src := ShipyardCatalogue.new()
	s["upgrades"] = {"ram": 4, "hull": 5}
	for port_id: String in PortData.PORTS:
		src.port_id = port_id
		var ram: CatalogueItem = _item(src.items(s), "upg:ram")
		var big: bool = int(PortData.PORTS[port_id]["shipyard_level"]) >= ShipyardCatalogue.FULL_TIER_YARD
		assert_eq(ram.status, CatalogueItem.Status.AVAILABLE if big else CatalogueItem.Status.LOCKED, port_id)
		assert_eq(_item(src.items(s), "upg:hull").status, CatalogueItem.Status.MAXED)


func test_shipyard_ships_lock_on_fame_and_buy_with_trade_in() -> void:
	var s: Dictionary = _state()
	s["fame"] = 0
	var src := ShipyardCatalogue.new()
	src.port_id = PortData.START_PORT
	var items: Array[CatalogueItem] = src.items(s)
	assert_eq(_item(items, "ship:" + s["ship_class"]).status, CatalogueItem.Status.OWNED)
	for it in items:
		if it.data.get("kind", "") == "ship":
			var locked: bool = PortService.ship_stats(it.data["class"]).infamy_required > 0
			assert_eq(it.status == CatalogueItem.Status.LOCKED, locked, it.id)
			assert_eq(it.price, PortService.ship_cost(s, it.data["class"]))
	var sloop: CatalogueItem = _item(items, "ship:sloop")
	assert_true(src.buy(s, sloop))
	assert_eq(s["ship_class"], "sloop")


func test_shipyard_services_repair_and_insure() -> void:
	var s: Dictionary = _state()
	var src := ShipyardCatalogue.new()
	s["ship_hull"] = 1.0
	assert_eq(_item(src.items(s), "svc:repair").status, CatalogueItem.Status.MAXED)
	s["ship_hull"] = 0.5
	var repair: CatalogueItem = _item(src.items(s), "svc:repair")
	assert_true(repair.price > 0 and repair.status == CatalogueItem.Status.AVAILABLE)
	assert_true(src.buy(s, repair))
	assert_eq(float(s["ship_hull"]), 1.0)
	s["insured"] = false
	assert_true(src.buy(s, _item(src.items(s), "svc:insure")))
	assert_eq(_item(src.items(s), "svc:insure").status, CatalogueItem.Status.OWNED)


func test_outfitter_weapons_ammo_and_small_arms() -> void:
	var s: Dictionary = _state()
	var src := OutfitterCatalogue.new()
	var musket: CatalogueItem = _item(src.items(s), "weapon:musket")
	assert_eq(musket.price, int(WeaponData.WEAPONS["musket"]["price"]))
	assert_true(src.buy(s, musket))
	assert_eq(_item(src.items(s), "weapon:musket").status, CatalogueItem.Status.OWNED)
	var before: int = int(s["ammo"].get("chain", 0))
	assert_true(src.buy(s, _item(src.items(s), "ammo:chain")))
	assert_eq(int(s["ammo"]["chain"]), before + 10)
	s["supplies"]["small_arms"] = 0.0
	assert_eq(_item(src.items(s), "svc:small_arms").status, CatalogueItem.Status.LOCKED)
	s["supplies"]["small_arms"] = 2.0
	var shots: int = int(s["pistol_shots"])
	assert_true(src.buy(s, _item(src.items(s), "svc:small_arms")))
	assert_eq(int(s["pistol_shots"]), shots + 2 * WeaponData.SHOTS_PER_SMALL_ARMS_UNIT)


func test_screen_draws_any_source_and_buys_through_it() -> void:
	var old: Dictionary = Session.state
	Session.state = _state()
	Session.state["gold"] = 40
	var src := FakeLagoon.new()
	var screen := CatalogueScreen.with_source(src)
	screen.category = "cat.supplies"
	screen._title_key = src.title_key()
	screen._rebuild()
	var cards: Array = screen.find_children("Card_*", "PanelContainer", true, false)
	assert_eq(cards.size(), 3, "three cards on the supplies tab")
	var rum_btn: Button = screen.find_child("Buy_rum", true, false)
	var dock_btn: Button = screen.find_child("Buy_dock", true, false)
	assert_true(rum_btn != null and not rum_btn.disabled, "rum is affordable")
	assert_true(dock_btn != null and dock_btn.disabled, "locked dock cannot be bought")
	assert_true(screen.buy_id("rum"))
	assert_eq(int(Session.state["gold"]), 10)
	assert_true(not screen.buy_id("dock"), "locked item refused")
	assert_true(not screen.buy_id("rum"), "cannot afford a second rum")
	screen.select("cat.ships")
	var grids: Array = screen.find_children("Grid", "GridContainer", true, false)
	assert_eq((grids[-1] as Node).get_child_count(), 1, "the ships tab has one card")  # old pages are only queued for deletion
	screen.free()
	Session.state = old
