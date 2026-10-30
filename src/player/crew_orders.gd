class_name CrewOrders
extends RefCounted
## Orders the captain gives his crew at sea from the order buttons: fight the guns at will, load and hold, fire now,
## run for it, or patch the ship. Each order sets the crew's focus (how hands split between guns, sails and repair);
## "Attack" also lets the gun crews fire a full battery at any enemy that bears.

enum Order { NONE, ATTACK, LOAD, FIRE, RETREAT, REPAIR }

const KEYS: Array[String] = ["", "orders.attack", "orders.load", "orders.fire", "orders.retreat", "orders.repair"]
const BEAM_ARC_DEG: float = 22.0  ## an enemy this close to straight abeam is one the guns can bear on
const RANGE_SLACK: float = 0.15  ## a shot that falls this close (as a share of the distance) is worth firing


## Apply an order to `ship`; returns the order that stays in force (Fire is one shot and leaves the last one).
static func give(ship: Ship, order: Order, current: Order) -> Order:
	match order:
		Order.ATTACK, Order.LOAD:
			ship.crew.focus = CrewState.Focus.GUNS
		Order.FIRE:
			fire_both(ship)
			return current
		Order.RETREAT:
			ship.crew.focus = CrewState.Focus.SAILS
			ship.sail_level = 3
		Order.REPAIR:
			ship.crew.focus = CrewState.Focus.REPAIR
	return order


## Fire every loaded gun on both sides. Returns how many went off.
static func fire_both(ship: Ship) -> int:
	return ship.broadside.fire(Broadside.Side.PORT) + ship.broadside.fire(Broadside.Side.STARBOARD)


## Whether `other` is a ship our crew should shoot at: a hostile flag, a ship hunting us, or one we already hit.
static func is_enemy(ship: Ship, other: Ship) -> bool:
	if other == null or other == ship or not is_instance_valid(other) or other.damage.sunk or other.has_surrendered:
		return false
	if other.ai != null and other.ai.target == ship:
		return true
	if other.last_attacker == ship:
		return true
	return FactionRel.hostile(other.faction, "player")


## The nearest enemy abeam on `side` (0 port, 1 starboard) within reach of the guns, or null.
static func target_on_side(ship: Ship, side: int, ships: Array) -> Ship:
	var best: Ship = null
	var best_d: float = INF
	var right: Vector3 = ship.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() * (1.0 if side == Broadside.Side.STARBOARD else -1.0)
	var reach: float = float(GunData.GUNS[ship.broadside.gun_id]["max"]) * float(GunData.AMMO[ship.broadside.ammo_id]["range"])
	for n: Variant in ships:
		var s: Ship = n as Ship
		if not is_enemy(ship, s):
			continue
		var d: Vector3 = s.global_position - ship.global_position
		d.y = 0.0
		var dist: float = d.length()
		if dist < 1.0 or dist > reach:
			continue
		if rad_to_deg(right.angle_to(d)) > BEAM_ARC_DEG:
			continue
		if dist < best_d:
			best_d = dist
			best = s
	return best


## "Attack": when a whole battery is loaded and an enemy bears on that side, lay the guns for his range and fire.
## Returns the guns fired this step.
static func fight_at_will(ship: Ship, ships: Array) -> int:
	var fired: int = 0
	var b: Broadside = ship.broadside
	for side in 2:
		if b.ready_count(side) < b.gun_count():
			continue
		var t: Ship = target_on_side(ship, side, ships)
		if t == null:
			continue
		var dist: float = Vector2(t.global_position.x - ship.global_position.x, t.global_position.z - ship.global_position.z).length()
		b.set_elevation(b.elevation_for_range(side, dist))
		var land: Vector3 = b.predicted_landing(side)
		var short: float = absf(Vector2(land.x - ship.global_position.x, land.z - ship.global_position.z).length() - dist)
		if short <= dist * RANGE_SLACK:
			fired += b.fire(side)
	return fired
