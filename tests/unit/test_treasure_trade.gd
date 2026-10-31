extends TestCase
## Buried treasure maps (BuriedTreasure) and trade routes between cities (TradeRoutes).


func _rng(s: int = 3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _state() -> Dictionary:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 5000
	s["ship_class"] = "brigantine"
	return s


# ---- treasure maps ----------------------------------------------------------------------------------------

func test_every_x_lies_in_open_water_off_its_own_island() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(11)
	var g: WorldGen = PortData.gen()
	for n in 60:
		var m: Dictionary = BuriedTreasure.make_map(s, "common", r)
		assert_true(m["island"] != "Skull Atoll", "never the player's lagoon")
		var idx: int = g.index_of(m["island"])
		var isl: Dictionary = g.islands[idx]
		var d: float = BuriedTreasure.spot(m).distance_to(isl["pos"])
		assert_near(d, float(isl["radius"]) + BuriedTreasure.SHORE_OFFSET_M, 1.0, "X just off the shore")
		assert_true(BuriedTreasure.SHORES.has(m["shore"]), "shore named")
	assert_eq(int(BuriedTreasure.root(s)["seq"]), 60)


func test_shore_names_follow_the_chart() -> void:
	assert_eq(BuriedTreasure.shore_of(Vector2(0, -1)), "n")
	assert_eq(BuriedTreasure.shore_of(Vector2(1, 0)), "e")
	assert_eq(BuriedTreasure.shore_of(Vector2(0, 1)), "s")
	assert_eq(BuriedTreasure.shore_of(Vector2(-1, -1).normalized()), "nw")


func test_tavern_sells_one_map_a_window_and_charges_for_it() -> void:
	var s: Dictionary = _state()
	var tier: String = BuriedTreasure.offer_tier(s, "blackwater")
	assert_true(tier == "common" or tier == "rich")
	var price: int = BuriedTreasure.offer_price(s, "blackwater")
	var m: Dictionary = BuriedTreasure.buy_offer(s, "blackwater")
	assert_true(not m.is_empty(), "bought")
	assert_eq(int(s["gold"]), 5000 - price)
	assert_eq(BuriedTreasure.offer_tier(s, "blackwater"), "", "sold out until the next window")
	assert_true(BuriedTreasure.buy_offer(s, "blackwater").is_empty())
	s["day"] = BuriedTreasure.OFFER_DAYS
	assert_true(BuriedTreasure.offer_tier(s, "blackwater") != "", "a new map days later")


func test_chart_case_holds_three_maps() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng()
	for n in 5:
		BuriedTreasure.add_map(s, BuriedTreasure.make_map(s, "rich", r))
	assert_eq(BuriedTreasure.maps(s).size(), BuriedTreasure.MAX_HELD)
	assert_true(BuriedTreasure.roll_drop(s, "rival", r).is_empty(), "no drop when the case is full")
	s["gold"] = 100000
	assert_true(BuriedTreasure.buy_offer(s, "meridian").is_empty(), "cannot buy when full")


func test_held_maps_point_at_different_islands() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(5)
	for n in 3:
		BuriedTreasure.add_map(s, BuriedTreasure.make_map(s, "common", r))
	var names: Array = []
	for m: Dictionary in BuriedTreasure.maps(s):
		assert_true(not names.has(m["island"]), "island used twice")
		names.append(m["island"])


func test_digging_at_the_x_pays_out_and_uses_the_map() -> void:
	var s: Dictionary = _state()
	var r: RandomNumberGenerator = _rng(9)
	var m: Dictionary = BuriedTreasure.make_map(s, "rich", r)
	BuriedTreasure.add_map(s, m)
	var x: Vector2 = BuriedTreasure.spot(m)
	assert_eq(BuriedTreasure.near(s, x + Vector2(30, 0)), 0, "within reach")
	assert_eq(BuriedTreasure.near(s, x + Vector2(400, 0)), -1, "too far")
	var gold0: int = int(s["gold"])
	var res: Dictionary = BuriedTreasure.dig(s, 0, r)
	assert_true(bool(res["ok"]))
	var t: Dictionary = BuriedTreasure.TIERS["rich"]
	assert_true(int(res["gold"]) >= int(t["gold"][0]) - 10 and int(res["gold"]) <= int(t["gold"][1]) + 10, "gold in range")
	assert_eq(int(s["gold"]), gold0 + int(res["gold"]))
	assert_true(float(s["cargo"].get("gems", 0.0)) >= 1.0, "a rich chest holds gems")
	assert_eq(BuriedTreasure.maps(s).size(), 0, "map used up")
	assert_eq(int(BuriedTreasure.root(s)["dug"]), 1)
	assert_true(BuriedTreasure.summary(res).length() > 10)


func test_a_full_hold_leaves_goods_on_the_beach_but_takes_the_gold() -> void:
	var s: Dictionary = _state()
	s["cargo"]["timber"] = floorf(PortService.cargo_free(s) / 0.1)
	var r: RandomNumberGenerator = _rng(2)
	BuriedTreasure.add_map(s, BuriedTreasure.make_map(s, "common", r))
	var res: Dictionary = BuriedTreasure.dig(s, 0, r)
	assert_true(int(res["gold"]) > 0)
	assert_true(float(res["left"]) > 0.0, "goods left behind")


func test_boarded_ships_drop_maps_at_their_rate() -> void:
	var r: RandomNumberGenerator = _rng(21)
	var got: int = 0
	var tiers: Dictionary = {}
	for n in 400:
		var s: Dictionary = _state()
		var m: Dictionary = BuriedTreasure.roll_drop(s, "pirate", r)
		if not m.is_empty():
			got += 1
			tiers[m["tier"]] = int(tiers.get(m["tier"], 0)) + 1
	assert_true(got > 30 and got < 90, "about 14%% of pirates carry a map, got %d" % got)
	assert_true(tiers.has("common") and tiers.has("rich"))
	assert_true(BuriedTreasure.roll_drop(_state(), "nobody", r).is_empty())


# ---- trade routes -----------------------------------------------------------------------------------------

func _two_ports() -> Array[String]:
	return ["blackwater", "albion"]  # Blackwater makes rum, Port Regal drinks twice its share


func test_price_book_records_only_ports_visited() -> void:
	var s: Dictionary = _state()
	assert_eq(TradeRoutes.known_ports(s).size(), 0)
	TradeRoutes.record(s, "blackwater")
	assert_eq(TradeRoutes.known_ports(s), ["blackwater"] as Array[String])
	assert_true(not (TradeRoutes.book(s)["blackwater"]["buy"] as Dictionary).has("gunpowder"), "only legal goods")
	s["day"] = 4
	assert_eq(TradeRoutes.age_days(s, "blackwater"), 4)


func test_ledger_finds_buy_low_sell_high_between_two_ports() -> void:
	var s: Dictionary = _state()
	var m: Market = PortService.market_of(s, "blackwater")
	m.stock["rum"] = m.target["rum"] * 2.5  # a glut of rum
	PortService.store_market(s, "blackwater", m)
	var m2: Market = PortService.market_of(s, "albion")
	m2.stock["rum"] = m2.target["rum"] * 0.2  # and a thirsty navy
	PortService.store_market(s, "albion", m2)
	for p in _two_ports():
		TradeRoutes.record(s, p)
	var routes: Array[Dictionary] = TradeRoutes.best(s, 100.0, 7.0)
	assert_true(not routes.is_empty(), "a route was found")
	var rum: Dictionary = {}
	for rt in routes:
		if rt["good"] == "rum" and rt["from"] == "blackwater":
			rum = rt
	assert_true(not rum.is_empty(), "rum from Blackwater to Port Regal is listed")
	assert_true(float(rum["sell"]) > float(rum["buy"]))
	assert_near(float(rum["profit"]), float(rum["margin"]) * float(rum["units"]), 0.01)
	for i in range(1, routes.size()):
		assert_true(float(routes[i - 1]["profit"]) >= float(routes[i]["profit"]), "sorted best first")
	for rt in TradeRoutes.best(s, 100.0, 7.0, "albion"):
		assert_eq(rt["from"], "albion", "from-here filter")


func test_fleet_ship_on_a_route_earns_and_moves_both_markets() -> void:
	var s: Dictionary = _state()
	var m: Market = PortService.market_of(s, "blackwater")
	m.stock["rum"] = m.target["rum"] * 2.5
	PortService.store_market(s, "blackwater", m)
	var m2: Market = PortService.market_of(s, "albion")
	m2.stock["rum"] = m2.target["rum"] * 0.2
	PortService.store_market(s, "albion", m2)
	s["fleet"] = [{"class": "schooner", "name": "Gull", "crew": 4, "hull": 1.0}]
	assert_true(not TradeRoutes.assign(s, 0, "blackwater", "albion", "rum", 0.0), "prices unknown yet")
	for p in _two_ports():
		TradeRoutes.record(s, p)
	assert_true(not TradeRoutes.assign(s, 0, "blackwater", "albion", "gunpowder", 0.0), "no smuggling routes")
	assert_true(TradeRoutes.assign(s, 0, "blackwater", "albion", "rum", 0.0))
	assert_eq(TradeRoutes.idle_ship(s), -1)
	assert_true(TradeRoutes.predicted(s, s["fleet"][0]) > 0.0)
	var trip: float = TradeRoutes.round_trip_hours("blackwater", "albion")
	assert_eq(TradeRoutes.advance(s, trip * 0.5, _rng()).size(), 0, "still at sea")
	var stock_a: float = PortService.market_of(s, "blackwater").stock["rum"]
	var stock_b: float = PortService.market_of(s, "albion").stock["rum"]
	var gold0: int = int(s["gold"])
	var r: RandomNumberGenerator = _rng(4)
	var reports: Array[Dictionary] = TradeRoutes.advance(s, trip * 3.0 + 0.1, r)
	assert_eq(reports.size(), 3, "three round trips home")
	var route: Dictionary = s["fleet"][0]["route"]
	assert_eq(int(route["trips"]), 3)
	assert_eq(int(s["gold"]) - gold0, int(route["earned"]))
	var profits: int = 0
	for rep in reports:
		assert_true(TradeRoutes.report_text(rep).length() > 5)
		if rep["result"] == "profit":
			profits += 1
	if profits > 0:
		assert_true(int(route["earned"]) > 0)
		assert_true(PortService.market_of(s, "blackwater").stock["rum"] < stock_a, "buying drains the producer")
		assert_true(PortService.market_of(s, "albion").stock["rum"] > stock_b, "selling fills the consumer")


func test_a_long_absence_settles_only_a_few_trips() -> void:
	var s: Dictionary = _state()
	s["fleet"] = [{"class": "sloop", "name": "Tern", "crew": 2, "hull": 1.0}]
	for p in _two_ports():
		TradeRoutes.record(s, p)
	TradeRoutes.assign(s, 0, "blackwater", "albion", "rum", 0.0)
	var reports: Array[Dictionary] = TradeRoutes.advance(s, 24.0 * 365.0, _rng())
	assert_eq(reports.size(), TradeRoutes.MAX_CATCH_UP)
	assert_true(float(s["fleet"][0]["route"]["next_h"]) > 24.0 * 365.0)


func test_recall_and_take_command_end_the_route() -> void:
	var s: Dictionary = _state()
	s["fleet"] = [{"class": "sloop", "name": "Tern", "crew": 2, "hull": 1.0}, {"class": "sloop", "name": "Wren", "crew": 2, "hull": 1.0}]
	for p in _two_ports():
		TradeRoutes.record(s, p)
	TradeRoutes.assign(s, 0, "blackwater", "albion", "rum", 0.0)
	TradeRoutes.assign(s, 1, "albion", "blackwater", "rum", 0.0)
	assert_true(TradeRoutes.recall(s, 0))
	assert_true(not TradeRoutes.on_route(s["fleet"][0]))
	assert_true(Lagoon.take_command(s, 1))
	assert_true(not TradeRoutes.on_route(s["fleet"][1]), "the old flagship comes back without a route")


func test_save_round_trip_keeps_maps_book_and_routes() -> void:
	var s: Dictionary = _state()
	BuriedTreasure.add_map(s, BuriedTreasure.make_map(s, "legendary", _rng()))
	s["fleet"] = [{"class": "sloop", "name": "Tern", "crew": 2, "hull": 1.0}]
	for p in _two_ports():
		TradeRoutes.record(s, p)
	TradeRoutes.assign(s, 0, "blackwater", "albion", "rum", 0.0)
	var back: Dictionary = SaveGame.from_json(SaveGame.to_json(s))
	assert_eq(BuriedTreasure.maps(back).size(), 1)
	assert_near(BuriedTreasure.spot(BuriedTreasure.maps(back)[0]).x, BuriedTreasure.spot(BuriedTreasure.maps(s)[0]).x, 0.01)
	assert_eq(TradeRoutes.known_ports(back).size(), 2)
	assert_true(TradeRoutes.on_route(back["fleet"][0]))
	assert_eq(TradeRoutes.advance(back, 1.0, _rng()).size(), 0)


func test_old_save_migrates_to_v18() -> void:
	var old: Dictionary = SaveGame.new_state()
	old["version"] = 17
	old.erase("buried")
	old.erase("price_book")
	var m: Dictionary = SaveGame.migrate(old)
	assert_eq(int(m["version"]), SaveGame.VERSION)
	assert_true(m["buried"] is Dictionary and m["price_book"] is Dictionary)
	assert_eq(BuriedTreasure.maps(m).size(), 0)


func test_every_new_string_has_both_languages() -> void:
	var keys: Array[String] = ["buried.clue", "buried.hint", "buried.seller", "troute.title", "troute.row", "troute.trip_profit"]
	for t: String in BuriedTreasure.TIER_ORDER:
		keys.append("buried.tier." + t)
	for sh: String in BuriedTreasure.SHORES:
		keys.append("buried.shore." + sh)
	for k in keys:
		assert_true(Loc.t(k) != k, "missing " + k)
