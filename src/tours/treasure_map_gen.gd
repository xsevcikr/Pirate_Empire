class_name TreasureMapGen
extends RefCounted
## After the six handmade tours the hunt never ends: random treasure maps built from templates (clue type, two
## hazards, a dungeon layout and a guardian) with 1,000 to 8,000 gold. A generated map is found whole, so it
## enters the tours record as a tour of its own, with the same steps, hints and death rules.

const CLUES: Array[String] = ["riddle", "bearing", "star_chart", "landmark"]
const HAZARDS: Array[String] = ["storm", "patrol", "icebergs", "whirlpool", "reef_maze", "ghost_storm"]
const GUARDIANS: Array[String] = ["shell_king", "sea_serpent", "brass_colossus", "ice_leviathan"]
const ROOM_POOL: Array[String] = ["trap", "puzzle:sluice", "puzzle:mirrors", "puzzle:bells", "puzzle:ice", "puzzle:vents", "puzzle:cart", "puzzle:rhyme", "chest", "guard"]
const MIN_ROOMS: int = 3
const MAX_ROOMS: int = 6


## A dungeon layout of 3 to 6 rooms: always an entry, a way out, a puzzle and a chest between.
static func layout(rng: RandomNumberGenerator) -> Array:
	var rooms: Array = ["entry"]
	var inner: int = rng.randi_range(MIN_ROOMS, MAX_ROOMS) - 2
	var must: Array = ["puzzle:" + ["sluice", "mirrors", "bells", "ice", "vents", "cart", "rhyme"][rng.randi_range(0, 6)], "chest"]
	for i in inner:
		if i < must.size():
			rooms.append(must[i])
		else:
			rooms.append(ROOM_POOL[rng.randi_range(0, ROOM_POOL.size() - 1)])
	if inner == 1:
		rooms[1] = must[0]  # a three-room dungeon keeps the puzzle and forgoes the chest
	rooms.append("exit")
	return rooms


static func generate(state: Dictionary, rng: RandomNumberGenerator) -> String:
	var g: WorldGen = PortData.gen()
	var named: Array[String] = []
	for isl: Dictionary in g.islands:
		named.append(str(isl["name"]))
	var target: String = named[rng.randi_range(0, named.size() - 1)]
	var start: String = "Haven Rock"
	var clue: String = CLUES[rng.randi_range(0, CLUES.size() - 1)]
	var hz: Array[String] = []
	while hz.size() < 2:
		var h: String = HAZARDS[rng.randi_range(0, HAZARDS.size() - 1)]
		if not hz.has(h):
			hz.append(h)
	var guardian: String = GUARDIANS[rng.randi_range(0, GUARDIANS.size() - 1)]
	var reward: int = int(snappedf(rng.randf_range(TourData.RANDOM_REWARD[0], TourData.RANDOM_REWARD[1]), 100.0))
	var n: int = TourState.root(state).get("generated", {}).size() + 1
	var id: String = "treasure_map_%d" % n
	var steps: Array = [
		{"id": "read_map", "kind": "clue", "island": start, "text": "tour.gen.clue_" + clue, "clue": clue},
		{"id": "voyage_1", "kind": "sail", "island": target, "hazard": hz[0], "text": "tour.gen.voyage"},
		{"id": "voyage_2", "kind": "sail", "island": target, "hazard": hz[1], "text": "tour.gen.voyage"},
		{"id": "landing", "kind": "sail", "island": target, "text": "tour.gen.landing"},
		{"id": "dungeon", "kind": "dungeon", "island": target, "dungeon": "generated", "rooms": layout(rng), "text": "tour.gen.dungeon"},
		{"id": "guardian", "kind": "guardian", "island": target, "monster": guardian, "text": "tour.gen.guardian"},
		{"id": "escape", "kind": "escape", "island": start, "text": "tour.gen.escape"},
	]
	var tour: Dictionary = {"name": "tour.gen.name", "region": "any", "island": target, "reward": {"gold": reward, "perks": [], "pearls": 0}, "steps": steps, "generated": true, "title_n": n}
	var t: Dictionary = TourState.root(state)
	if not t.has("generated"):
		t["generated"] = {}
	t["generated"][id] = tour
	TourData.EXTRA[id] = tour
	return id
