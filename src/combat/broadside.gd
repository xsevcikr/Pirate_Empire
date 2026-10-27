class_name Broadside
extends Node
## A ship's port and starboard gun batteries: reloads, ammo, elevation, firing and aim prediction.

enum Side { PORT, STARBOARD }

const RIPPLE_S: float = 0.06
const RECOIL_SCALE: float = 1.0

signal fired(side: int, count: int)

var ship: Ship
var gun_id: String = "6pdr"
var ammo_id: String = "round"
var ammo: Dictionary = {"round": 300, "chain": 60, "grape": 60, "heated": 0, "explosive": 0}
var elevation_deg: float = 3.0
var spread_scale: float = 1.0
var projectiles: ProjectileManager
var shots_fired: int = 0

var _timers: Array[PackedFloat32Array] = []
var _queue: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for side in 2:
		var arr := PackedFloat32Array()
		for i in gun_count():
			arr.append(0.0)
		_timers.append(arr)


func gun_count() -> int:
	return ship.stats.guns_per_side


func reload_time() -> float:
	return GunData.GUNS[gun_id]["reload"] * ship.crew.understaffed_multiplier() / ship.crew.guns_efficiency()


func ready_count(side: int) -> int:
	var n: int = 0
	for t in _timers[side]:
		if t <= 0.0:
			n += 1
	return n


func reload_fraction(side: int) -> float:
	# 1.0 = all guns loaded
	var total: float = 0.0
	var rt: float = maxf(reload_time(), 0.01)
	for t in _timers[side]:
		total += 1.0 - clampf(t / rt, 0.0, 1.0)
	return total / maxf(gun_count(), 1)


func set_ammo(id: String) -> void:
	if id == ammo_id or not GunData.AMMO.has(id):
		return
	ammo_id = id
	for side in 2:
		for i in gun_count():
			_timers[side][i] = reload_time()


func set_elevation(deg: float) -> void:
	elevation_deg = clampf(deg, GunData.MIN_ELEVATION_DEG, GunData.MAX_ELEVATION_DEG)


func muzzle_local(side: int, idx: int) -> Vector3:
	var n: int = gun_count()
	var z: float = lerpf(-0.3, 0.3, 0.5 if n == 1 else idx / float(n - 1)) * ship.stats.length_m
	var x: float = (ship.stats.beam_m * 0.5 + 0.3) * (1.0 if side == Side.STARBOARD else -1.0)
	return Vector3(x, ship.stats.freeboard_m - 0.6, z)


func _aim_direction(side: int, elevation: float) -> Vector3:
	var side_dir: Vector3 = ship.global_transform.basis.x * (1.0 if side == Side.STARBOARD else -1.0)
	side_dir.y = 0.0
	side_dir = side_dir.normalized()
	var el: float = deg_to_rad(elevation)
	return (side_dir * cos(el) + Vector3.UP * sin(el)).normalized()


func muzzle_speed() -> float:
	return GunData.GUNS[gun_id]["velocity"] * sqrt(GunData.AMMO[ammo_id]["range"])


## Number of guns that will fire (loaded and in ammo).
func fire(side: int) -> int:
	if ship.damage.sunk:
		return 0
	var count: int = 0
	for i in gun_count():
		if _timers[side][i] <= 0.0 and int(ammo.get(ammo_id, 0)) > count:
			_timers[side][i] = reload_time() + count * RIPPLE_S
			_queue.append({"delay": count * RIPPLE_S, "side": side, "idx": i})
			count += 1
	if count > 0:
		fired.emit(side, count)
	return count


func _physics_process(delta: float) -> void:
	for side in _timers.size():
		for i in _timers[side].size():
			if _timers[side][i] > 0.0:
				_timers[side][i] = maxf(_timers[side][i] - delta, 0.0)
	var j: int = _queue.size() - 1
	while j >= 0:
		_queue[j]["delay"] -= delta
		if _queue[j]["delay"] <= 0.0:
			_shoot(_queue[j]["side"], _queue[j]["idx"])
			_queue.remove_at(j)
		j -= 1


func _shoot(side: int, idx: int) -> void:
	if int(ammo.get(ammo_id, 0)) <= 0 or projectiles == null:
		return
	ammo[ammo_id] = int(ammo[ammo_id]) - 1
	shots_fired += 1
	var dir: Vector3 = _aim_direction(side, elevation_deg)
	var spread: float = GunData.GUNS[gun_id]["spread"] * spread_scale
	if spread > 0.0:
		dir = dir.rotated(Vector3.UP, deg_to_rad(_rng.randfn(0.0, spread * 0.5)))
		dir = dir.rotated(dir.cross(Vector3.UP).normalized(), deg_to_rad(_rng.randfn(0.0, spread * 0.5)))
	var muzzle_world: Vector3 = ship.to_global(muzzle_local(side, idx))
	var vel: Vector3 = dir * muzzle_speed() + ship.linear_velocity
	projectiles.fire(muzzle_world, vel, gun_id, ammo_id, ship)
	Vfx.muzzle(ship.get_parent(), muzzle_world, dir)
	var ball_mass: float = GunData.GUNS[gun_id]["damage"] / 40.0 * 2.7
	ship.apply_impulse(-dir * ball_mass * muzzle_speed() * RECOIL_SCALE, ship.to_global(muzzle_local(side, idx)) - ship.global_position)


## Flat-water landing point for a shot from the centre gun of a side.
func predicted_landing(side: int) -> Vector3:
	var dir: Vector3 = _aim_direction(side, elevation_deg)
	var origin: Vector3 = ship.to_global(muzzle_local(side, gun_count() / 2))
	var vel: Vector3 = dir * muzzle_speed() + ship.linear_velocity
	return Ballistics.landing_point(origin, vel, GunData.shot_gravity(gun_id), 0.0)


## Elevation in degrees that lands a flat-water shot at `range_m` (bisection, clamped).
func elevation_for_range(side: int, range_m: float) -> float:
	var lo: float = GunData.MIN_ELEVATION_DEG
	var hi: float = GunData.MAX_ELEVATION_DEG
	var origin: Vector3 = ship.to_global(muzzle_local(side, gun_count() / 2))
	var g: float = GunData.shot_gravity(gun_id)
	var v: float = muzzle_speed()
	for _i in 18:
		var mid: float = (lo + hi) * 0.5
		var dir: Vector3 = _aim_direction(side, mid)
		var land: Vector3 = Ballistics.landing_point(origin, dir * v + ship.linear_velocity, g, 0.0)
		var d: float = Vector2(land.x - origin.x, land.z - origin.z).length()
		if d < range_m:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
