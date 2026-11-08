class_name Autopilot
extends RefCounted
## Auto drive for the player's ship. With a mark set on the chart it sails the chart's island-free route to it and
## stops on arrival; without one it holds the heading it was given. Either way it looks ahead and turns away from
## islands and other ships, so the captain can leave the helm and walk the deck.
## Pure logic: the caller feeds it the ship's flat position and heading and applies the rudder and sails it returns.

enum Mode { OFF, HOLD, COURSE }

const DIRECTIONS: int = 36
const LOOKAHEAD_MIN_M: float = 160.0
const LOOKAHEAD_S: float = 40.0  ## look this many seconds of sailing ahead
const ISLAND_CLEARANCE_M: float = 60.0
const SHIP_RANGE_M: float = 140.0
const WAYPOINT_REACHED_M: float = 70.0
const ARRIVE_M: float = 90.0
const SLOW_M: float = 320.0  ## reef the sails to half this close to the mark
const STICKY: float = 0.08  ## preference for the direction chosen last time, so the bow does not hunt

var mode: Mode = Mode.OFF
var hold_dir: Vector2 = Vector2(0, -1)
var goal: Vector2 = Vector2.INF
var route: PackedVector2Array = PackedVector2Array()
var leg: int = 0
var chosen: Vector2 = Vector2(0, -1)
var islands: Array = []  ## {pos: Vector2, radius: float}
var _chart: Chart


func _init(island_list: Array = []) -> void:
	islands = island_list


func is_on() -> bool:
	return mode != Mode.OFF


## Switches auto drive on. `course` is the chart mark ([x, z] or empty); without one the current heading is held.
func engage(pos: Vector2, heading: Vector2, course: Array = []) -> void:
	hold_dir = heading.normalized() if heading.length() > 0.01 else Vector2(0, -1)
	chosen = hold_dir
	route = PackedVector2Array()
	leg = 0
	goal = Vector2.INF
	if course.size() == 2:
		goal = Vector2(float(course[0]), float(course[1]))
		route = _route(pos, goal)
		if route.is_empty():
			route = PackedVector2Array([goal])
		mode = Mode.COURSE
	else:
		mode = Mode.HOLD


func disengage() -> void:
	mode = Mode.OFF
	route = PackedVector2Array()
	goal = Vector2.INF


func _route(a: Vector2, b: Vector2) -> PackedVector2Array:
	if islands.is_empty():
		return PackedVector2Array([b])
	if _chart == null:
		_chart = Chart.new()
	return _chart.route(a, b)


## Metres left to the mark along the route, or -1 when holding a heading.
func distance_left(pos: Vector2) -> float:
	if mode != Mode.COURSE:
		return -1.0
	var d: float = 0.0
	var at: Vector2 = pos
	for i in range(leg, route.size()):
		d += at.distance_to(route[i])
		at = route[i]
	return d


## The direction the route wants right now (before avoidance).
func desired_dir(pos: Vector2) -> Vector2:
	if mode == Mode.COURSE:
		while leg < route.size() - 1 and pos.distance_to(route[leg]) < WAYPOINT_REACHED_M:
			leg += 1
		var to: Vector2 = route[leg] - pos
		return to.normalized() if to.length() > 0.01 else hold_dir
	return hold_dir


## One steering step. `others` are the flat positions of nearby ships. Returns
## {rudder: float, sail: int (-1 keeps the current sails), arrived: bool, blocked: bool}.
func steer(pos: Vector2, heading: Vector2, speed_ms: float, others: Array = []) -> Dictionary:
	var out: Dictionary = {"rudder": 0.0, "sail": -1, "arrived": false, "blocked": false}
	if mode == Mode.OFF:
		return out
	var want: Vector2 = desired_dir(pos)
	if mode == Mode.COURSE:
		var left: float = distance_left(pos)
		if left < ARRIVE_M:
			out["arrived"] = true
			out["sail"] = 0
			return out
		if left < SLOW_M:
			out["sail"] = 1
	var look: float = maxf(LOOKAHEAD_MIN_M, absf(speed_ms) * LOOKAHEAD_S)
	var best: Vector2 = want
	var best_score: float = -INF
	var best_danger: float = 1.0
	for i in DIRECTIONS:
		var dir := Vector2.from_angle(TAU * float(i) / float(DIRECTIONS))
		var danger: float = maxf(island_danger(pos, dir, look), ship_danger(pos, dir, others))
		var score: float = dir.dot(want) - danger * 3.0 + (STICKY if dir.dot(chosen) > 0.99 else 0.0)
		if score > best_score:
			best_score = score
			best = dir
			best_danger = danger
	chosen = best
	out["blocked"] = best_danger > 0.9  # every way out is shut: the caller takes the helm back
	out["rudder"] = AiLogic.rudder_for(heading, best)
	return out


## 0 when the line `look` metres ahead along `dir` is open water, rising toward 1 the closer an island lies on it.
func island_danger(pos: Vector2, dir: Vector2, look: float) -> float:
	var worst: float = 0.0
	for isl: Dictionary in islands:
		var c: Vector2 = isl["pos"]
		var r: float = float(isl["radius"]) + ISLAND_CLEARANCE_M
		var rel: Vector2 = c - pos
		if rel.length() - r > look:
			continue
		if rel.length() < r:  # already inside the margin: only heading out is safe
			worst = maxf(worst, clampf(dir.dot(rel.normalized()) + 0.2, 0.0, 1.0))
			continue
		var along: float = rel.dot(dir)
		if along <= 0.0:
			continue
		var side: float = absf(rel.cross(dir))
		if side > r:
			continue
		var hit_at: float = along - sqrt(maxf(r * r - side * side, 0.0))
		if hit_at < look:
			worst = maxf(worst, clampf(1.0 - hit_at / look, 0.25, 1.0))
	return worst


func ship_danger(pos: Vector2, dir: Vector2, others: Array) -> float:
	var worst: float = 0.0
	for o: Vector2 in others:
		var rel: Vector2 = o - pos
		var dist: float = rel.length()
		if dist > SHIP_RANGE_M or dist < 0.01:
			continue
		var toward: float = dir.dot(rel / dist)
		if toward > 0.3:
			worst = maxf(worst, toward * clampf((SHIP_RANGE_M - dist) / 100.0, 0.0, 1.0))
	return worst


## Compass word for a flat heading (x east, z south), as the HUD shows it.
static func compass_key(dir: Vector2) -> String:
	var names: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
	var bearing: float = fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0)
	return "compass." + names[int(round(bearing / 45.0)) % 8]
