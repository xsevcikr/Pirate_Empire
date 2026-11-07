extends TestCase
## The rail fishing moment and the sea-life meshes (auto drive itself is tested in test_autopilot.gd).


# ---- fishing ----------------------------------------------------------------------------------------

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return r


func test_fishing_cast_bite_catch() -> void:
	var f := DeckFishing.new(_rng())
	assert_true(not f.is_out())
	f.cast()
	assert_eq(f.phase, DeckFishing.Phase.WAITING)
	assert_true(not f.pull(), "pulling before the bite catches nothing")
	assert_eq(f.phase, DeckFishing.Phase.WAITING, "and does not spoil the cast")
	for i in 600:
		f.tick(1.0 / 60.0)
		if f.phase == DeckFishing.Phase.BITE:
			break
	assert_eq(f.phase, DeckFishing.Phase.BITE, "a bite comes within ten seconds")
	assert_true(f.pull())
	assert_eq(f.phase, DeckFishing.Phase.CAUGHT)
	assert_true(DeckFishing.FOOD.has(f.fish), "a known fish")


func test_fishing_slow_hand_misses_then_recasts() -> void:
	var f := DeckFishing.new(_rng())
	f.cast()
	f.tick(DeckFishing.WAIT_MAX_S + 0.1)
	assert_eq(f.phase, DeckFishing.Phase.BITE)
	f.tick(DeckFishing.BITE_WINDOW_S + 0.1)
	assert_eq(f.phase, DeckFishing.Phase.MISSED)
	f.tick(DeckFishing.SHOW_S + 0.1)
	assert_eq(f.phase, DeckFishing.Phase.WAITING, "the line goes back in by itself")


func test_catch_feeds_the_crew() -> void:
	var s: Dictionary = SaveGame.new_state()
	s["supplies"]["food"] = 2.0
	var food: int = DeckFishing.land(s, "tuna")
	assert_eq(food, 3)
	assert_near(float(s["supplies"]["food"]), 5.0, 0.0001)
	assert_true(DeckFishing.food_for("marlin") > DeckFishing.food_for("sardine"), "bigger fish, more food")


func test_every_fish_has_a_name_and_food() -> void:
	for id: String in GameData.FISHING["fish"]:
		assert_true(DeckFishing.FOOD.has(id), id)


# ---- art --------------------------------------------------------------------------------------------

func test_sea_life_meshes_build_and_share() -> void:
	for m: Mesh in [SeaLifeArt.dolphin(), SeaLifeArt.whale(), SeaLifeArt.flying_fish(), SeaLifeArt.gull_body(),
			SeaLifeArt.gull_wing(), SeaLifeArt.bobber(), SeaLifeArt.catch_fish()]:
		assert_true(m != null and m.get_surface_count() == 1, "mesh built")
	assert_true(SeaLifeArt.dolphin() == SeaLifeArt.dolphin(), "built once and shared")
	var whale_len: float = SeaLifeArt.whale().get_aabb().size.z
	var dolphin_len: float = SeaLifeArt.dolphin().get_aabb().size.z
	assert_true(whale_len > dolphin_len * 3.0, "a whale is much bigger than a dolphin")
