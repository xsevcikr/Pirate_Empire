class_name MapFragments
extends RefCounted
## Treasure map fragments: where they drop, what a part-built map shows and the rotate-to-match puzzle that
## joins three pieces into a map.


## The fragment a defeated ship drops, or "" for none. Fragments go to the first tour that is still missing one.
static func roll_drop(state: Dictionary, source: String, rng: RandomNumberGenerator) -> String:
	var rate: float = float(TourData.DROP_RATE.get(source, 0.0))
	if rate <= 0.0 or rng.randf() >= rate:
		return ""
	return next_missing(state)


static func next_missing(state: Dictionary) -> String:
	var have: Array = state["map_fragments"]
	for tour: String in TourData.tour_ids():
		if TourState.is_done(state, tour) or not TourState.available(state, tour):
			continue
		for n in range(1, TourData.FRAGMENTS_PER_TOUR + 1):
			var id: String = TourData.fragment_id(tour, n)
			if not have.has(id):
				return id
	return ""


static func owned(state: Dictionary, tour_id: String) -> int:
	if TourData.is_generated(tour_id):
		return TourData.FRAGMENTS_PER_TOUR  # a generated map is found whole
	var c: int = 0
	for n in range(1, TourData.FRAGMENTS_PER_TOUR + 1):
		if state["map_fragments"].has(TourData.fragment_id(tour_id, n)):
			c += 1
	return c


## Adds a fragment once. Returns true when it was new.
static func add(state: Dictionary, id: String) -> bool:
	if id == "" or state["map_fragments"].has(id):
		return false
	state["map_fragments"].append(id)
	return true


## 0 nothing, 1 a coastline sketch, 2 the region, 3 the full map and the first clue.
static func view_level(state: Dictionary, tour_id: String) -> int:
	return owned(state, tour_id)


# ---- the rotate puzzle --------------------------------------------------------------------------------

## Fresh puzzle: each piece turned by a random quarter turn, never all upright.
static func scramble(tour_id: String, rng: RandomNumberGenerator) -> Array[int]:
	var turns: Array[int] = []
	for i in TourData.FRAGMENTS_PER_TOUR:
		turns.append(rng.randi_range(0, 3))
	if turns.all(func(t: int) -> bool: return t == 0):
		turns[0] = 1
	return turns


static func rotate(turns: Array[int], piece: int) -> void:
	turns[piece] = (turns[piece] + 1) % 4


static func is_joined(turns: Array[int]) -> bool:
	return turns.all(func(t: int) -> bool: return t == 0)


## The hint for the puzzle: which piece to turn next.
static func next_piece(turns: Array[int]) -> int:
	for i in turns.size():
		if turns[i] != 0:
			return i
	return -1
