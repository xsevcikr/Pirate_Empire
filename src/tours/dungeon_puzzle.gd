class_name DungeonPuzzle
extends RefCounted
## The dungeon puzzles. sluice: pull three gates in order within 180 s (a wrong pull or the clock drains the cave
## and starts over). mirrors: turn mirrors upright. rhyme, bells, cart: tap a sequence. vents: pass three steam
## vents while they are closed. ice: slide across an ice floor to the exit. Each has three hint levels and none
## can fail for good.

const SLIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var kind: String
var solution: Array[int] = []
var progress: int = 0
var turns: Array[int] = []
var time_left_s: float = 0.0
var clock_s: float = 0.0
var resets: int = 0
var burns: int = 0
var hints_used: int = 0
var solved: bool = false
var rocks: Array[Vector2i] = []
var pos := Vector2i.ZERO
var goal := Vector2i.ZERO


func _init(puzzle_kind: String, rng: RandomNumberGenerator) -> void:
	kind = puzzle_kind
	if TourData.SEQUENCES.has(kind):
		var spec: Array = TourData.SEQUENCES[kind]
		for i in int(spec[0]):
			solution.append(rng.randi_range(0, int(spec[1]) - 1))
		if kind == "bells":
			solution = _perm(4, rng)
		return
	match kind:
		"sluice":
			solution = _perm(TourData.SLUICE_GATES, rng)
			time_left_s = TourData.SLUICE_TIME_S
		"mirrors":
			for i in TourData.MIRRORS:
				turns.append(rng.randi_range(0, 3))
			if MapFragments.is_joined(turns):
				turns[0] = 2
		"vents":
			solution = [0, 1, 2]
		"ice":
			_make_ice(rng)


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


func symbol_count() -> int:
	if TourData.SEQUENCES.has(kind):
		return int(TourData.SEQUENCES[kind][1])
	return {"sluice": TourData.SLUICE_GATES, "mirrors": TourData.MIRRORS, "vents": TourData.VENTS, "ice": 4}.get(kind, 3)


func tick(delta: float) -> void:
	clock_s += delta
	if kind == "sluice" and not solved:
		time_left_s -= delta
		if time_left_s <= 0.0:
			_reset()


func _reset() -> void:
	progress = 0
	resets += 1
	time_left_s = TourData.SLUICE_TIME_S


## Vent i is blowing steam when it is within the open part of its six-second cycle; the vents are staggered.
func vent_open(i: int) -> bool:
	return fmod(clock_s + float(i) * 2.0, TourData.VENT_PERIOD_S) < TourData.VENT_OPEN_S


## A gate, symbol, mirror, vent or slide direction is chosen. Returns true when it was right (or turned a mirror).
func press(i: int) -> bool:
	if solved:
		return true
	if kind == "mirrors":
		MapFragments.rotate(turns, i)
		solved = MapFragments.is_joined(turns)
		return true
	if kind == "ice":
		pos = _slide(pos, i)
		solved = pos == goal
		return true
	if kind == "vents":
		if i != solution[progress]:
			return false
		if vent_open(i):
			burns += 1
			return false
		progress += 1
		solved = progress >= solution.size()
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


# ---- the ice floor ----------------------------------------------------------------------------------

func _blocked(c: Vector2i) -> bool:
	return c.x < 0 or c.y < 0 or c.x >= TourData.ICE_GRID or c.y >= TourData.ICE_GRID or rocks.has(c)


func _slide(from: Vector2i, dir: int) -> Vector2i:
	var p: Vector2i = from
	while not _blocked(p + SLIDES[dir]):
		p += SLIDES[dir]
	return p


## Breadth-first search over slides: the first move of a shortest path from `from` to the goal, -1 when none.
func _path(from: Vector2i) -> Array[int]:
	var came: Dictionary = {from: [-1, from]}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			break
		for d in 4:
			var n: Vector2i = _slide(c, d)
			if not came.has(n):
				came[n] = [d, c]
				queue.append(n)
	var out: Array[int] = []
	if not came.has(goal):
		return out
	var cur: Vector2i = goal
	while cur != from:
		out.push_front(int(came[cur][0]))
		cur = came[cur][1]
	return out


func _make_ice(rng: RandomNumberGenerator) -> void:
	while true:
		rocks.clear()
		while rocks.size() < TourData.ICE_ROCKS:
			var c := Vector2i(rng.randi_range(0, TourData.ICE_GRID - 1), rng.randi_range(0, TourData.ICE_GRID - 1))
			if c != Vector2i.ZERO and not rocks.has(c):
				rocks.append(c)
		pos = Vector2i.ZERO
		# the goal is the farthest cell reachable by sliding, at least three slides away
		var depth: Dictionary = {pos: 0}
		var queue: Array[Vector2i] = [pos]
		var head: int = 0
		var best: Vector2i = pos
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			for d in 4:
				var n: Vector2i = _slide(c, d)
				if not depth.has(n):
					depth[n] = int(depth[c]) + 1
					queue.append(n)
					if int(depth[n]) > int(depth[best]):
						best = n
		if int(depth[best]) >= 3:
			goal = best
			solution = _path(pos)
			return


## Hint level 1 is a hint in words, 2 shows the next move, 3 the whole answer.
func hint(level: int) -> Dictionary:
	hints_used = maxi(hints_used, level)
	match level:
		1:
			return {"key": "puzzle.hint1." + kind}
		2:
			var next: int = -1
			if not solved:
				if kind == "mirrors":
					next = MapFragments.next_piece(turns)
				elif kind == "ice":
					var p: Array[int] = _path(pos)
					next = p[0] if not p.is_empty() else -1
				else:
					next = solution[progress]
			return {"key": "puzzle.hint2." + kind, "next": next}
	return {"key": "puzzle.hint3." + kind, "answer": solution.duplicate() if kind != "mirrors" else turns.duplicate()}


## Solve it by following the hints; for tests.
func solve_with_hints() -> void:
	var guard: int = 0
	while not solved and guard < 200:
		guard += 1
		var h: Dictionary = hint(2)
		if kind == "vents":
			var tries: int = 0
			while vent_open(int(h["next"])) and tries < 100:
				tick(0.25)
				tries += 1
		press(int(h["next"]))
