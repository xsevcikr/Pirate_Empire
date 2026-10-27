class_name DungeonPuzzle
extends RefCounted
## The three dungeon puzzles. sluice: pull three gates in the order the rising tide allows within 180 s (a
## wrong pull or running out of time drains the cave and starts over). mirrors: turn three mirrors upright.
## rhyme: tap four symbols in the order of the rhyme. Every puzzle has three hint levels and none can fail
## for good.

var kind: String
var solution: Array[int] = []
var progress: int = 0
var turns: Array[int] = []
var time_left_s: float = 0.0
var resets: int = 0
var hints_used: int = 0
var solved: bool = false


func _init(puzzle_kind: String, rng: RandomNumberGenerator) -> void:
	kind = puzzle_kind
	match kind:
		"sluice":
			solution = _perm(TourData.SLUICE_GATES, rng)
			time_left_s = TourData.SLUICE_TIME_S
		"rhyme":
			for i in TourData.RHYME_LEN:
				solution.append(rng.randi_range(0, 5))
		"mirrors":
			for i in TourData.MIRRORS:
				turns.append(rng.randi_range(0, 3))
			if MapFragments.is_joined(turns):
				turns[0] = 2


static func _perm(n: int, rng: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = []
	for i in n:
		a.append(i)
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func tick(delta: float) -> void:
	if kind == "sluice" and not solved:
		time_left_s -= delta
		if time_left_s <= 0.0:
			_reset()


func _reset() -> void:
	progress = 0
	resets += 1
	time_left_s = TourData.SLUICE_TIME_S


## A gate, symbol or mirror is chosen. Returns true when it was right (or turned a mirror).
func press(i: int) -> bool:
	if solved:
		return true
	if kind == "mirrors":
		MapFragments.rotate(turns, i)
		solved = MapFragments.is_joined(turns)
		return true
	if i == solution[progress]:
		progress += 1
		if progress >= solution.size():
			solved = true
		return true
	if kind == "sluice":
		_reset()
	else:
		progress = 0
		resets += 1
	return false


## Hint level 1 is a hint in words, 2 shows the next move, 3 the whole answer.
func hint(level: int) -> Dictionary:
	hints_used = maxi(hints_used, level)
	match level:
		1:
			return {"key": "puzzle.hint1." + kind}
		2:
			var next: int = MapFragments.next_piece(turns) if kind == "mirrors" else (solution[progress] if not solved else -1)
			return {"key": "puzzle.hint2." + kind, "next": next}
	return {"key": "puzzle.hint3." + kind, "answer": solution.duplicate() if kind != "mirrors" else turns.duplicate()}


## Solve it by following the hints; for tests.
func solve_with_hints() -> void:
	while not solved:
		var h: Dictionary = hint(2)
		press(int(h["next"]))
