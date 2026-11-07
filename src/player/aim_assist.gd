class_name AimAssist
extends RefCounted
## Easy-mode aiming help for young captains. At sea the guns lay themselves for the range of the nearest enemy on
## the side that fires, and the shot spread is tighter. On deck the captain's pistol swings onto the nearest foe
## roughly in front of him. Off on every other difficulty.

const EASY: int = 0
const SPREAD_MULT: float = 0.6  ## Easy broadsides scatter this much less
const SEA_ARC_DEG: float = 40.0  ## an enemy this close to abeam counts as "on that side" for the auto-aim
const DECK_SNAP_DEG: float = 35.0  ## the pistol snaps onto a foe within this angle of where the captain faces
const DECK_SPREAD_MULT: float = 0.4


static func enabled(state: Dictionary) -> bool:
	return not state.is_empty() and int(state.get("difficulty", 1)) == EASY


## The nearest enemy on `side` within reach and SEA_ARC_DEG of abeam, or null.
static func sea_target(ship: Ship, side: int, ships: Array) -> Ship:
	var best: Ship = null
	var best_d: float = INF
	var right: Vector3 = ship.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() * (1.0 if side == Broadside.Side.STARBOARD else -1.0)
	var reach: float = float(GunData.GUNS[ship.broadside.gun_id]["max"]) * float(GunData.AMMO[ship.broadside.ammo_id]["range"])
	for n: Variant in ships:
		var s: Ship = n as Ship
		if not CrewOrders.is_enemy(ship, s):
			continue
		var d: Vector3 = s.global_position - ship.global_position
		d.y = 0.0
		var dist: float = d.length()
		if dist < 1.0 or dist > reach or rad_to_deg(right.angle_to(d)) > SEA_ARC_DEG:
			continue
		if dist < best_d:
			best_d = dist
			best = s
	return best


## Lays the guns of `side` for the nearest enemy there. Returns the enemy aimed at, or null (elevation untouched).
static func lay_guns(ship: Ship, side: int, ships: Array) -> Ship:
	var t: Ship = sea_target(ship, side, ships)
	if t == null:
		return null
	var dist: float = Vector2(t.global_position.x - ship.global_position.x, t.global_position.z - ship.global_position.z).length()
	ship.broadside.set_elevation(ship.broadside.elevation_for_range(side, dist))
	return t


## The side (0 port, 1 starboard) whose nearest enemy is closest, or -1 when none bears.
static func best_side(ship: Ship, ships: Array) -> int:
	var best: int = -1
	var best_d: float = INF
	for side in 2:
		var t: Ship = sea_target(ship, side, ships)
		if t != null:
			var d: float = t.global_position.distance_to(ship.global_position)
			if d < best_d:
				best_d = d
				best = side
	return best


## On deck: the aim swung onto the nearest standing foe within DECK_SNAP_DEG of `aim` and range, or `aim` itself.
static func deck_aim(from: Vector2, aim: Vector2, foes: Array, range_m: float) -> Vector2:
	var a: Vector2 = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	var best: Vector2 = a
	var best_d: float = INF
	for p: Variant in foes:
		var d: Vector2 = (p as Vector2) - from
		var dist: float = d.length()
		if dist < 0.01 or dist > range_m or absf(rad_to_deg(a.angle_to(d))) > DECK_SNAP_DEG:
			continue
		if dist < best_d:
			best_d = dist
			best = d.normalized()
	return best
