extends TestCase
## F near a harbour ties the ship up and takes the captain and crew ashore.


func test_only_near_a_harbour_and_slow() -> void:
	assert_true(Mooring.can_disembark("albion", false, 2.0), "slow in a dock zone")
	assert_true(Mooring.can_disembark("", true, 1.0), "slow off the lagoon piers")
	assert_true(not Mooring.can_disembark("", false, 0.0), "open sea: F lowers the guns instead")
	assert_true(not Mooring.can_disembark("albion", false, 6.0), "too fast to tie up")


func test_blocked_reason_only_shown_near_a_harbour() -> void:
	assert_eq(Mooring.blocked_reason("", false, 9.0), "")
	assert_eq(Mooring.blocked_reason("albion", false, 9.0), "moor.too_fast")
	assert_eq(Mooring.blocked_reason("albion", false, 1.0), "")


func test_berth_lies_alongside_the_pier_bow_to_sea() -> void:
	for id: String in PortData.PORTS:
		var port: Dictionary = PortData.PORTS[id]
		var dock: Vector2 = port["dock"]
		var isl: Vector2 = PortData.gen().islands[port["island"]]["pos"]
		var b: Dictionary = Mooring.berth(id, 30.0, 8.0)
		var pos: Vector2 = b["pos"]
		var to_island: Vector2 = (isl - dock).normalized()
		var off: Vector2 = pos - dock
		var across: float = absf(off.dot(Vector2(to_island.y, -to_island.x)))
		assert_near(across, PortScene.PIER_WIDTH_M * 0.5 + Mooring.PIER_GAP_M + 4.0, 0.01, "%s: hull clear of the planks" % id)
		var yaw: float = b["yaw"]
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		assert_true(fwd.dot(-to_island) > 0.99, "%s: bow points out to sea" % id)
		assert_true(PortData.port_near(pos) == id, "%s: still in the dock zone" % id)


func test_shore_party_follows_the_roster_and_is_capped() -> void:
	var roster: Array = []
	assert_eq(Mooring.shore_party(roster).size(), 0)
	for i in 12:
		roster.append({"type": "gunner" if i % 2 == 0 else "swordsman"})
	var party: Array[String] = Mooring.shore_party(roster)
	assert_eq(party.size(), Mooring.PARTY_MAX)
	assert_eq(party[0], "gunner")
	assert_eq(party[1], "swordsman")


func test_f_is_bound_to_disembark() -> void:
	assert_true(GameInput.ACTIONS.has("disembark"))
	assert_eq(GameInput.ACTIONS["disembark"][0], KEY_F)
	assert_true(Loc.t("moor.too_fast") != "moor.too_fast", "string is translated")
