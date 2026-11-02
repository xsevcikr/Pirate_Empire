class_name Autopilot
extends RefCounted
## Holds the ship on the course she had when the captain let go of the wheel, so he can walk the deck or fish.
## It looks ahead along the course and, when an island is in the way, picks the nearest clear heading to the side
## until the coast is passed, then comes back to the old course. Plain functions so the steering is testable.

const LOOK_AHEAD_M: Array[float] = [50.0, 110.0, 180.0, 260.0]
const SHORE_MARGIN_M: float = 60.0  ## how far off a coast the ship keeps
const TRY_STEP_DEG: float = 20.0
const TRY_MAX_DEG: float = 160.0

var engaged: bool = false
var course: Vector2 = Vector2(0, -1)  ## the flat heading (x, z) to hold
var steering_to: Vector2 = Vector2(0, -1)  ## the heading being steered right now (the course, or a way round land)
var _side: float = 1.0  ## which way the last detour went, so it does not flip from side to side


func engage(heading: Vector2) -> void:
	engaged = true
	course = heading.normalized() if heading.length() > 0.01 else Vector2(0, -1)
	steering_to = course


func disengage() -> void:
	engaged = false


## True when sailing `dir` from `pos` would run onto any island ({pos: Vector2, radius: float}) within the look-ahead.
static func blocked(pos: Vector2, dir: Vector2, islands: Array) -> bool:
	for isl: Dictionary in islands:
		var c: Vector2 = isl["pos"]
		var r: float = float(isl["radius"]) + SHORE_MARGIN_M
		if pos.distance_to(c) > r + LOOK_AHEAD_M[-1] + 10.0:
			continue
		for d in LOOK_AHEAD_M:
			if (pos + dir * d).distance_to(c) < r:
				return true
	return false


## The heading to steer: the course itself when it is clear, else the smallest turn to either side that is clear.
func pick_heading(pos: Vector2, islands: Array) -> Vector2:
	if not blocked(pos, course, islands):
		return course
	var a: float = TRY_STEP_DEG
	while a <= TRY_MAX_DEG:
		for s in [_side, -_side]:
			var dir: Vector2 = course.rotated(deg_to_rad(a) * s)
			if not blocked(pos, dir, islands):
				_side = s
				return dir
		a += TRY_STEP_DEG
	return -course  # boxed in: turn round


## Rudder input (-1 port .. 1 starboard) for this frame.
func rudder(pos: Vector2, heading: Vector2, islands: Array) -> float:
	if not engaged:
		return 0.0
	steering_to = pick_heading(pos, islands)
	return AiLogic.rudder_for(heading, steering_to)
