class_name AiLogic
extends RefCounted
## Pure decision functions for ship AI, kept free of nodes so they can be unit tested.

enum State { PATROL, TRADE, ENGAGE, FLEE, SURRENDER }

const DIRECTIONS: int = 16

## flee below this strength ratio, by personality; surrender when hull < `surrender_hull`
const PERSONALITIES: Dictionary = {
	"cautious": {"flee_ratio": 0.5, "kite": true, "surrender_hull": 0.15},
	"aggressive": {"flee_ratio": 0.2, "kite": false, "surrender_hull": 0.10},
	"cunning": {"flee_ratio": 0.4, "kite": true, "surrender_hull": 0.15},
	"disciplined": {"flee_ratio": 0.35, "kite": false, "surrender_hull": 0.12},
	"greedy": {"flee_ratio": 0.5, "kite": false, "surrender_hull": 0.35},
}


## Strength rating S = hull% x (guns per side x gun damage) x crew% x (1 + armor / 100).
static func strength(hull_frac: float, guns_per_side: int, gun_damage: float, crew_frac: float, armor: float) -> float:
	return hull_frac * (guns_per_side * gun_damage) * crew_frac * (1.0 + armor / 100.0)


static func next_state(current: State, ctx: Dictionary) -> State:
	var hull: float = ctx["hull_frac"]
	var crew: float = ctx["crew_frac"]
	var p: Dictionary = PERSONALITIES[ctx.get("personality", "disciplined")]
	if current == State.SURRENDER:
		return State.SURRENDER
	if hull < p["surrender_hull"] and crew < 0.4:
		return State.SURRENDER
	var seen: bool = ctx["hostile_seen"]
	var dist: float = ctx["hostile_dist"]
	if ctx["is_merchant"]:
		if seen and dist < 900.0:
			return State.FLEE
		if current == State.FLEE and dist < 1500.0:
			return State.FLEE
		return State.TRADE
	if seen:
		if hull < 0.25 or ctx["ratio"] < p["flee_ratio"]:
			return State.FLEE
		if current == State.FLEE and dist < 1500.0 and ctx["ratio"] < p["flee_ratio"] + 0.15:
			return State.FLEE  # hysteresis
		return State.ENGAGE
	if current == State.FLEE and dist < 1500.0:
		return State.FLEE
	if current == State.ENGAGE and ctx.get("lost_s", 0.0) < 60.0:
		return State.ENGAGE
	return State.PATROL


## Where a shot should be aimed: target position advanced by its velocity over the ball's flight time.
static func lead_point(my_pos: Vector2, target_pos: Vector2, target_vel: Vector2, muzzle_speed: float) -> Vector2:
	var dist: float = my_pos.distance_to(target_pos)
	var t: float = dist / maxf(muzzle_speed, 1.0)
	return target_pos + target_vel * t


## Fire only when the side is lined up with the (lead) target and the target is in range.
static func should_fire(angle_err_deg: float, range_m: float, effective_range: float, loaded: int, guns: int, target_half_length: float = 9.0) -> bool:
	if range_m < 15.0 or range_m > effective_range * 1.15:
		return false
	if loaded * 2 < guns and loaded < 2:
		return false
	# The aim point must fall within the target's hull: half its length seen from here, at most 8 degrees.
	var tolerance: float = clampf(rad_to_deg(atan(target_half_length * 0.7 / maxf(range_m, 10.0))), 1.5, 8.0)
	return absf(angle_err_deg) <= tolerance


## Pick the unit direction closest to `desired` that stays out of the no-go wind arc and away from other ships.
## `threats` entries: {"rel": Vector2 (their position minus mine), "dist": float}.
static func steer_direction(desired: Vector2, wind_from: Vector2, no_go_deg: float, threats: Array, ignore_wind: bool = false) -> Vector2:
	var best: Vector2 = desired.normalized()
	var best_score: float = -INF
	var d: Vector2 = desired.normalized()
	for i in DIRECTIONS:
		var dir := Vector2.from_angle(TAU * i / DIRECTIONS)
		var interest: float = dir.dot(d)
		var danger: float = 0.0
		if not ignore_wind:
			var off: float = rad_to_deg(acos(clampf(dir.dot(wind_from), -1.0, 1.0)))
			if off < no_go_deg:
				danger = 1.0
		for t: Dictionary in threats:
			var rel: Vector2 = t["rel"]
			var dist: float = t["dist"]
			if dist > 120.0:
				continue
			var toward: float = dir.dot(rel.normalized())
			if toward > 0.3:
				danger = maxf(danger, toward * clampf((120.0 - dist) / 90.0, 0.0, 1.0))
		var score: float = interest - danger * 2.0
		if score > best_score:
			best_score = score
			best = dir
	return best


static func rudder_for(heading: Vector2, desired: Vector2) -> float:
	var err: float = rad_to_deg(heading.angle_to(desired))
	return clampf(err / 30.0, -1.0, 1.0)
