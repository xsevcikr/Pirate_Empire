extends TestCase
## Harbour towns: the plan keeps houses on the town ground, off the streets and the square and clear of each other;
## the chandler restocks a voyage; townsfolk keep to the streets through the square.


func _rect(h: Dictionary) -> Rect2:
	var along_u: bool = absf(float(h["yaw"])) < 1.0 or absf(float(h["yaw"]) - 180.0) < 1.0
	var w: float = float(h["w"]) if along_u else float(h["d"])
	var d: float = float(h["d"]) if along_u else float(h["w"])
	return Rect2(float(h["u"]) - w * 0.5, float(h["v"]) - d * 0.5, w, d)


func test_town_plan_is_tidy_for_every_tier() -> void:
	for tier in ["village", "town", "city", "capital"]:
		var half: float = PortScene.TOWN_HALF_BY_TIER[tier]
		var plan: Array[Dictionary] = PortScene.plan_town("test_" + tier, half, tier)
		var st: Dictionary = PortScene.streets("x", half, tier)
		assert_true(plan.size() >= 8, "%s has a real number of houses, got %d" % [tier, plan.size()])
		assert_true(plan.size() <= 64, "%s stays affordable to draw, got %d" % [tier, plan.size()])
		var rects: Array[Rect2] = []
		for h in plan:
			var r: Rect2 = _rect(h)
			assert_true(r.position.x >= -half and r.end.x <= half and r.position.y >= -half and r.end.y <= half - 5.0,
				"%s house inside the town ground and behind the sea wall: %s" % [tier, r])
			var sq := Rect2(-PortScene.SQUARE_HALF_M, -PortScene.SQUARE_HALF_M, PortScene.SQUARE_HALF_M * 2.0, PortScene.SQUARE_HALF_M * 2.0)
			assert_true(not r.intersects(sq), "%s house off the square: %s" % [tier, r])
			for u: float in st["u"]:
				assert_true(r.end.x <= u - PortScene.STREET_HALF_M + 0.01 or r.position.x >= u + PortScene.STREET_HALF_M - 0.01, "%s house off street u=%f: %s" % [tier, u, r])
			for v: float in st["v"]:
				assert_true(r.end.y <= v - PortScene.STREET_HALF_M + 0.01 or r.position.y >= v + PortScene.STREET_HALF_M - 0.01, "%s house off street v=%f: %s" % [tier, v, r])
			for o in rects:
				assert_true(not r.grow(-0.05).intersects(o), "%s houses do not overlap: %s %s" % [tier, r, o])
			rects.append(r)
	var cap: Array[Dictionary] = PortScene.plan_town("cap", 48.0, "capital")
	var warehouses: int = 0
	for h in cap:
		if h["kind"] == "warehouse":
			warehouses += 1
	assert_true(warehouses >= 2, "warehouses line the harbour road, got %d" % warehouses)


func test_bigger_towns_have_more_houses() -> void:
	var v: int = PortScene.plan_town("a", PortScene.TOWN_HALF_BY_TIER["village"], "village").size()
	var c: int = PortScene.plan_town("a", PortScene.TOWN_HALF_BY_TIER["capital"], "capital").size()
	assert_true(c > v * 2, "a capital (%d) is much bigger than a village (%d)" % [c, v])


func test_chandler_restocks_a_voyage() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 100000
	s["crew"] = 6
	var m := Market.new()
	var need: Dictionary = SupplyStore.shortfall(s, 14.0)
	assert_true(int(need["food"]) > 0 and int(need["water"]) > 0, "a fresh ship needs food and water for two weeks")
	var cost: int = SupplyStore.restock_cost(s, m, 14.0)
	assert_true(cost > 0, "restocking costs gold")
	var got: Dictionary = SupplyStore.restock(s, m, 14.0)
	assert_eq(int(got["food"]), int(need["food"]))
	for id in ["food", "water", "rum"]:
		assert_true(CrewLife.days_left(s, id) >= 13.99, "%s lasts two weeks now, %f" % [id, CrewLife.days_left(s, id)])
	assert_true(int(s["gold"]) < 100000, "gold was paid")
	var again: Dictionary = SupplyStore.shortfall(s, 14.0)
	assert_eq(int(again["food"]) + int(again["water"]) + int(again["rum"]), 0, "nothing more to buy")


func test_chandler_spreads_a_thin_purse() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["gold"] = 80
	s["crew"] = 30
	for id in ["food", "water", "rum"]:
		s["supplies"][id] = 0.0
	var got: Dictionary = SupplyStore.restock(s, Market.new(), 30.0)
	assert_true(int(got["food"]) > 0 and int(got["water"]) > 0 and int(got["rum"]) > 0, "some of each: %s" % got)
	assert_true(int(s["gold"]) >= 0, "never in debt")


func test_townsfolk_route_through_the_square() -> void:
	var w := TownWalker.new()
	var spots: Array[Vector3] = [Vector3(1.6, 0, -20), Vector3(-20, 0, 1.6), Vector3(1.6, 0, 20)]
	w.setup("peasant", 1, spots, 7)
	w.hub_routing = true
	w.hub = Vector3.ZERO
	for i in 10:
		var t: Vector3 = w.next_target()
		if i % 2 == 0:
			assert_true(t.length() < 3.0, "every other walk ends at the square, got %s" % t)
		else:
			assert_true(spots.has(t), "and the others at a street spot, got %s" % t)
	w.free()
