class_name ShipAI
extends Node
## Hierarchical AI for one ship: strategic state (patrol, trade, engage, flee, surrender) plus tactical
## steering and gunnery. Obeys the same reload and turning rules as the player.

signal state_changed(new_state: int)

const THINK_HZ: float = 5.0

var ship: Ship
var personality: String = "disciplined"
var state: AiLogic.State = AiLogic.State.PATROL
var target: Ship
var detect_range: float = 1200.0
var waypoints: Array[Vector3] = []
var gunner_skill: float = 3.0
var rng := RandomNumberGenerator.new()

var _wp_index: int = 0
var _think_accum: float = 0.0
var _desired_dir: Vector2 = Vector2(0, -1)
var _side_pref: int = 1
var _lost_s: float = 0.0
var _threat_dist: float = 99999.0
var _acquire_delay: float = 0.0
var _chosen_dir: Vector2 = Vector2(0, -1)
var _kite_override: bool = false
var _engage_fresh: bool = true


func _ready() -> void:
	_think_accum = rng.randf() / THINK_HZ  # stagger across ships
	if waypoints.is_empty():
		waypoints.append(ship.global_position + Vector3(0, 0, -500))
	if ship.stats.class_id in ["sloop", "schooner", "brigantine"] and ship.faction == "merchant":
		state = AiLogic.State.TRADE
	if ship.faction == "merchant":
		state = AiLogic.State.TRADE


func _physics_process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship) or ship.damage.sunk:
		return
	if state == AiLogic.State.SURRENDER:
		ship.sail_level = 0
		ship.rudder_input = 0.0
		return
	_think_accum += delta
	if _think_accum >= 1.0 / THINK_HZ:
		_think_accum = 0.0
		_think()
	_apply_steering()
	if state == AiLogic.State.ENGAGE:
		_gunnery(delta)
	_acquire_delay = maxf(_acquire_delay - delta, 0.0)


func _ships() -> Array[Ship]:
	var out: Array[Ship] = []
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s != null and s != ship and is_instance_valid(s) and not s.damage.sunk:
			out.append(s)
	return out


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _think() -> void:
	var my_pos: Vector2 = _flat(ship.global_position)
	# Sense: nearest hostile in range (or whoever shot at us)
	var best: Ship = null
	var best_d: float = detect_range
	for s in _ships():
		if not FactionRel.hostile(ship.faction, s.faction):
			continue
		var d: float = my_pos.distance_to(_flat(s.global_position))
		if d < best_d or s == target and d < detect_range * 1.3:
			best = s
			best_d = d
	if ship.last_attacker is Ship and is_instance_valid(ship.last_attacker) and best == null:
		var a: Ship = ship.last_attacker
		if not a.damage.sunk and FactionRel.hostile(ship.faction, a.faction):
			best = a
			best_d = my_pos.distance_to(_flat(a.global_position))
	var seen: bool = best != null
	if seen:
		if best != target:
			_acquire_delay = float(Difficulty.value("reaction_s"))
		target = best
		_lost_s = 0.0
		_threat_dist = best_d
	else:
		_lost_s += 1.0 / THINK_HZ
		_threat_dist = 99999.0 if _lost_s > 5.0 else _threat_dist
	var ratio: float = 1.0
	if target:
		ratio = ship.strength_rating() / maxf(target.strength_rating(), 1.0)
	var ctx: Dictionary = {
		"hull_frac": ship.damage.hull_fraction(), "crew_frac": float(ship.crew.count) / float(ship.stats.crew_max),
		"hostile_seen": seen, "hostile_dist": _threat_dist, "ratio": ratio, "is_merchant": ship.faction == "merchant",
		"personality": personality, "lost_s": _lost_s,
	}
	var next: AiLogic.State = AiLogic.next_state(state, ctx)
	if next != state:
		state = next
		state_changed.emit(int(state))
		if state == AiLogic.State.SURRENDER:
			ship.surrender()
		elif state == AiLogic.State.ENGAGE:
			_engage_fresh = true
			ship.crew.focus = CrewState.Focus.GUNS
		elif state == AiLogic.State.FLEE:
			ship.crew.focus = CrewState.Focus.SAILS if ship.damage.hull_fraction() > 0.5 else CrewState.Focus.REPAIR
		else:
			ship.crew.focus = CrewState.Focus.BALANCED
	_plan(my_pos)


func _plan(my_pos: Vector2) -> void:
	match state:
		AiLogic.State.PATROL, AiLogic.State.TRADE:
			var wp: Vector2 = _flat(waypoints[_wp_index])
			if my_pos.distance_to(wp) < 60.0:
				_wp_index = (_wp_index + 1) % waypoints.size()
				wp = _flat(waypoints[_wp_index])
			_desired_dir = (wp - my_pos).normalized()
			ship.sail_level = 2 if state == AiLogic.State.PATROL else 3
		AiLogic.State.FLEE:
			if target and is_instance_valid(target):
				_desired_dir = (my_pos - _flat(target.global_position)).normalized()
			ship.sail_level = 3
		AiLogic.State.ENGAGE:
			if target and is_instance_valid(target):
				_plan_engage(my_pos)


func _plan_engage(my_pos: Vector2) -> void:
	var t_pos: Vector2 = _flat(target.global_position)
	var t_vel: Vector2 = _flat(target.linear_velocity)
	var lead: Vector2 = AiLogic.lead_point(my_pos, t_pos, t_vel, ship.broadside.muzzle_speed())
	var to_t: Vector2 = lead - my_pos
	var dist: float = to_t.length()
	var b: Vector2 = to_t.normalized()
	var eff: float = GunData.GUNS[ship.broadside.gun_id]["effective"]
	var kite: bool = AiLogic.PERSONALITIES[personality]["kite"] or ship.stats.max_speed_kn > target.stats.max_speed_kn + 1.0
	var pref: float = eff * (0.9 if kite else 0.6)
	# Commit to a side so the ship settles into a steady beam-on course; only switch when the target
	# has moved well behind the current side and is nearly abeam on the other.
	var heading_now: Vector2 = ship.heading()
	var right_now: Vector2 = Vector2(-heading_now.y, heading_now.x)
	var err_s: float = absf(rad_to_deg(right_now.angle_to(b)))
	var err_p: float = absf(rad_to_deg((-right_now).angle_to(b)))
	if _engage_fresh:
		_side_pref = 1 if err_s <= err_p else 0
		_engage_fresh = false
	else:
		var cur: float = err_s if _side_pref == 1 else err_p
		var other: float = err_p if _side_pref == 1 else err_s
		if cur > 135.0 and other < cur - 40.0:
			_side_pref = 1 - _side_pref
	var h: Vector2 = Vector2(b.y, -b.x) if _side_pref == 1 else Vector2(-b.y, b.x)
	# Close or open the range by turning toward or away from the target
	var alpha: float = clampf((dist - pref) / pref, -1.0, 1.0) * deg_to_rad(55.0)
	var sgn: float = signf(h.cross(b))
	if sgn == 0.0:
		sgn = 1.0
	h = h.rotated(sgn * alpha)
	_desired_dir = h.normalized()
	ship.sail_level = 3 if dist > 250.0 else 2


func _apply_steering() -> void:
	var my_pos: Vector2 = _flat(ship.global_position)
	var threats: Array = []
	for s in _ships():
		var rel: Vector2 = _flat(s.global_position) - my_pos
		if s == target and state == AiLogic.State.ENGAGE and rel.length() > 45.0:
			continue  # the enemy we are circling is not an obstacle until it is very close
		threats.append({"rel": rel, "dist": rel.length()})
	# No wind mechanics: every heading is open, so only other ships are steered around.
	_chosen_dir = AiLogic.steer_direction(_desired_dir, Vector2.ZERO, 0.0, threats, true)
	ship.rudder_input = AiLogic.rudder_for(ship.heading(), _chosen_dir)


func _gunnery(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.damage.sunk or _acquire_delay > 0.0:
		return
	var b: Broadside = ship.broadside
	var my_pos: Vector2 = _flat(ship.global_position)
	var lead: Vector2 = AiLogic.lead_point(my_pos, _flat(target.global_position), _flat(target.linear_velocity), b.muzzle_speed())
	var to_t: Vector2 = lead - my_pos
	var range_m: float = to_t.length()
	var heading: Vector2 = ship.heading()
	var right: Vector2 = Vector2(-heading.y, heading.x)
	var eff: float = GunData.GUNS[b.gun_id]["effective"]
	# Ammunition choice
	if bool(Difficulty.value("ammo_switching")):
		if range_m < 90.0 and int(b.ammo["grape"]) > 0:
			b.set_ammo("grape")
		elif target.stats.max_speed_kn > ship.stats.max_speed_kn + 0.5 and target.damage.sail_health() > 0.5 and int(b.ammo["chain"]) > 0:
			b.set_ammo("chain")
		else:
			b.set_ammo("round")
	# Aim error shrinks with gunner skill and difficulty; never zero
	b.spread_scale = float(Difficulty.value("aim_error")) * (1.0 - gunner_skill / 20.0) * 2.0
	for side in 2:
		var normal: Vector2 = right if side == Broadside.Side.STARBOARD else -right
		var err: float = rad_to_deg(normal.angle_to(to_t))
		if AiLogic.should_fire(err, range_m, eff, b.ready_count(side), b.gun_count(), target.stats.length_m * 0.5):
			b.set_elevation(b.elevation_for_range(side, range_m) + rng.randfn(0.0, 0.25 * float(Difficulty.value("aim_error"))))
			b.fire(side)
