extends TestCase


func test_chests_follow_the_gold() -> void:
	assert_eq(ShipInterior.chest_count(0), 1)
	assert_eq(ShipInterior.chest_count(1500), 1)
	assert_eq(ShipInterior.chest_count(1501), 2)
	assert_eq(ShipInterior.chest_count(9200), 7)
	assert_eq(ShipInterior.chest_count(500000), ShipInterior.MAX_CHESTS)


func test_cargo_pieces_grow_with_cargo() -> void:
	assert_eq(ShipInterior.cargo_pieces({}), 0)
	assert_true(ShipInterior.cargo_pieces({"sugar": 20.0, "rum": 8.0}) > ShipInterior.cargo_pieces({"sugar": 4.0}))


func test_interior_has_every_gun_and_the_right_chests() -> void:
	var stats: ShipStats = load("res://data/ships/galleon.tres")
	var state: Dictionary = SaveGame.new_state()
	state["gold"] = 4000
	var root: Node3D = ShipInterior.build(stats, state)
	var guns: int = 0
	var chests: int = 0
	for c in root.get_children():
		if c.get_meta("kind", "") == "gun":
			guns += 1
		if c.get_meta("kind", "") == "chest":
			chests += 1
	assert_eq(guns, stats.guns_per_side * 2)
	assert_eq(chests, 3)
	root.free()


func test_crew_skins_are_stable_and_fit_the_kind() -> void:
	var f := FighterState.new()
	f.kind = "captain_player"
	assert_eq(DeckFighterView.skin_for(f), "p", "the player captain is the eyepatch pirate")
	f.kind = "brute"
	f.id = 5
	assert_eq(DeckFighterView.skin_for(f), DeckFighterView.skin_for(f))
	assert_true(DeckFighterView.skin_for(f) in ["o", "a"])
	var seen: Dictionary = {}
	for i in 40:
		var g := FighterState.new()
		g.kind = "crew"
		g.id = i
		seen[DeckFighterView.skin_for(g)] = true
	assert_true(seen.size() >= 3, "a crew is not all one face")


func test_palm_variants_build_geometry() -> void:
	for v in 3:
		var m: ArrayMesh = PalmMesh.build(v, 5)
		var arrays: Array = m.surface_get_arrays(0)
		assert_true((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 600, "variant %d" % v)


func test_town_walkers_meet_and_turn_to_each_other() -> void:
	var spots: Array[Vector3] = [Vector3.ZERO]
	var a := TownWalker.new()
	var b := TownWalker.new()
	a.setup("peasant", 1, spots, 3)
	b.setup("townswoman", 2, spots, 4)
	a.fighter.pos = Vector2(0, 0)
	b.fighter.pos = Vector2(1.5, 0)
	a._wait = 4.0
	b._wait = 4.0
	var list: Array[TownWalker] = [a, b]
	assert_eq(TownWalker.pair_up(list), 1, "two people standing close together start talking")
	assert_eq(a.talking_to, b)
	assert_eq(b.talking_to, a)
	var far := TownWalker.new()
	far.setup("guard", 3, spots, 5)
	far.fighter.pos = Vector2(40, 0)
	far._wait = 3.0
	var more: Array[TownWalker] = [far, a]
	assert_eq(TownWalker.pair_up(more), 0, "far apart or already talking: nobody pairs")
	far.free()
	a.free()
	b.free()


func test_camp_needs_a_big_enough_island() -> void:
	var small := Island.make(60.0, 3, "tropical")
	var rng := RandomNumberGenerator.new()
	assert_true(not IslandCamp.wants_camp(small, rng))
	small.free()


func test_every_boss_arena_with_a_model_builds_one() -> void:
	for id in BossModel.KINDS:
		assert_true(BossArena.ARENAS.has(id), "%s has an arena" % id)
	var m := BossModel.make("kraken")
	assert_eq(m.name, "Boss_kraken")
	m.free()
	assert_true(not BossModel.has_model("valcourt"), "fleet bosses are ships, not models")
