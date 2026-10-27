class_name Ship
extends RigidBody3D
## A sailing ship: buoyancy sampled on the Gerstner surface, wind sail thrust,
## quadratic hull drag, rudder yaw and wind heel. Forward is -Z, starboard is +X.

const RHO_REF_WIND_MS: float = 10.29  # 20 knots
const WATER_LATERAL_DAMP: float = 3.0
const ROLL_DAMP: float = 0.9
const PITCH_DAMP: float = 1.2
const RUDDER_TIME_S: float = 1.2
const HEEL_COEFF: float = 0.25
const POINT_COLUMNS: int = 4
const POINT_ROWS: int = 4

signal sank_signal
signal surrendered
signal hit_taken(result: Dictionary)

@export var stats: ShipStats

var ocean: WaveModel
var wind: WindModel

## Player or AI inputs.
var rudder_input: float = 0.0
var sail_level: int = 3

var rudder_actual: float = 0.0
var submerged_fraction: float = 0.0
var angle_off_wind: float = 90.0
var speed_forward_ms: float = 0.0

var damage: DamageModel
var crew: CrewState
var broadside: Broadside
var projectiles: ProjectileManager
var display_label: String = ""
var faction: String = "pirate"
var last_attacker: Node = null
var has_surrendered: bool = false
var ai: ShipAI

## Velocity at the start of the physics step, from before any contact changed it; collisions read this.
var prev_velocity: Vector3 = Vector3.ZERO
var grounding := Grounding.new()
var mast_drag_s: float = 0.0
var _mast_side: float = 1.0
var _bump_cool: float = 0.0
var _points: PackedVector3Array = PackedVector3Array()
var _k_point: float = 0.0
var _c_point: float = 0.0
var _k_drag: float = 0.0
var _f_ref: float = 0.0


func _ready() -> void:
	if stats == null:
		stats = load("res://data/ships/sloop.tres")
	mass = stats.mass_kg
	collision_layer = 2
	collision_mask = 2
	add_to_group("ships")
	damage = DamageModel.new(stats)
	crew = CrewState.new(stats)
	damage.mast_fell.connect(_on_mast_fell)
	damage.sank.connect(_on_sank)
	damage.magazine_exploded.connect(func() -> void:
		Vfx.explosion(get_parent(), global_position + Vector3.UP * 2.0)
		Sfx.play("explosion", global_position))
	damage.fire_started.connect(func(_i: int) -> void: Sfx.play("fire_crackle", global_position))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)
	# Replace the project-wide default damping; drag is modelled explicitly below.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = false
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_contact)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(stats.beam_m, stats.draft_m + stats.freeboard_m, stats.length_m)
	shape.shape = box
	shape.position = Vector3(0, (stats.freeboard_m - stats.draft_m) * 0.5, 0)
	add_child(shape)
	_build_points()
	_build_visuals()
	var vmax: float = MathUtils.knots_to_ms(stats.max_speed_kn)
	_k_drag = stats.mass_kg / (stats.accel_tau_s * vmax)
	_f_ref = _k_drag * vmax * vmax
	broadside = Broadside.new()
	broadside.ship = self
	broadside.gun_id = stats.gun_id
	add_child(broadside)


func _build_points() -> void:
	_points.clear()
	for r in POINT_ROWS:
		for c in POINT_COLUMNS:
			var x: float = lerpf(-0.5, 0.5, c / float(POINT_COLUMNS - 1)) * stats.beam_m * 0.9
			var z: float = lerpf(-0.5, 0.5, r / float(POINT_ROWS - 1)) * stats.length_m * 0.9
			_points.append(Vector3(x, -stats.draft_m, z))
	var n: float = float(_points.size())
	_k_point = stats.mass_kg * 9.81 / (n * stats.draft_m)
	var omega: float = sqrt(9.81 / stats.draft_m)
	_c_point = 2.0 * 0.6 * stats.mass_kg * omega / n


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if ocean == null or wind == null:
		return
	var dt: float = state.step
	var xf: Transform3D = state.transform
	var forward: Vector3 = -xf.basis.z
	var right: Vector3 = xf.basis.x
	var flat_fwd := Vector2(forward.x, forward.z)
	if flat_fwd.length() < 0.001:
		return
	var vel: Vector3 = state.linear_velocity
	prev_velocity = vel
	if grounding.stuck:
		state.linear_velocity = Vector3(0.0, vel.y, 0.0)
		state.angular_velocity = Vector3(0.0, state.angular_velocity.y * 0.5, 0.0)
		vel = state.linear_velocity

	# Buoyancy
	var wet: int = 0
	var max_depth: float = stats.draft_m * 2.0
	var flood: float = damage.flood_fraction()
	var buoyancy_scale: float = 0.04 if damage.sunk else 1.0 - 0.95 * flood
	for p in _points:
		var offset: Vector3 = xf.basis * p
		var world: Vector3 = xf.origin + offset
		var h: float = ocean.height_at(world.x, world.z)
		var depth: float = h - world.y
		if depth > 0.0:
			wet += 1
			var pv: Vector3 = state.get_velocity_at_local_position(offset)
			var f: float = (_k_point * minf(depth, max_depth) - _c_point * pv.y) * buoyancy_scale
			state.apply_force(Vector3.UP * maxf(f, 0.0), offset)
	submerged_fraction = float(wet) / float(_points.size())
	var in_water: bool = submerged_fraction > 0.25

	# Forward and lateral speeds
	var flat_vel := Vector3(vel.x, 0.0, vel.z)
	speed_forward_ms = flat_vel.dot(forward)
	var lateral: float = flat_vel.dot(right)

	if in_water:
		# Sail thrust: terminal speed = max_speed * wind_ratio * point-of-sail factor * sqrt(level).
		angle_off_wind = wind.angle_off_wind_deg(flat_fwd)
		var factor: float = SailModel.speed_factor(angle_off_wind, stats.square_rig)
		var level: float = SailModel.LEVELS[clampi(sail_level, 0, 3)]
		var ratio: float = minf(wind.speed_ms() / RHO_REF_WIND_MS, 1.5)
		var condition: float = damage.sail_health() * (1.0 - 0.8 * flood)
		var thrust: float = _f_ref * ratio * ratio * factor * factor * level * condition
		state.apply_central_force(forward * thrust)
		# Hull drag
		state.apply_central_force(-forward * _k_drag * speed_forward_ms * absf(speed_forward_ms) * (1.0 + (0.5 if mast_drag_s > 0.0 else 0.0)))
		if mast_drag_s > 0.0:  # a fallen mast dragging in the water turns the ship toward the side it fell
			state.apply_torque(Vector3.UP * _mast_side * stats.mass_kg * stats.length_m * 0.05)
		state.apply_central_force(-right * stats.mass_kg * WATER_LATERAL_DAMP * lateral)
		# Heel away from the wind
		var side: float = wind.direction.x * right.x + wind.direction.y * right.z
		var heel: float = HEEL_COEFF * _f_ref * ratio * ratio * level * side
		state.apply_torque(forward * heel * stats.length_m * 0.25)
		# Rudder
		rudder_actual = move_toward(rudder_actual, rudder_input, dt / RUDDER_TIME_S)
		var vmax: float = MathUtils.knots_to_ms(stats.max_speed_kn)
		var authority: float = clampf(absf(speed_forward_ms) / (0.35 * vmax), 0.0, 1.0) * clampf(damage.rudder_fraction() * 2.0, 0.5, 1.0)
		var desired: float = -rudder_actual * deg_to_rad(stats.turn_rate_deg_s) * authority
		var av: Vector3 = state.angular_velocity
		av.y = lerpf(av.y, desired, 1.0 - exp(-3.0 * dt))
		state.angular_velocity = av

	# Flooded compartments list the ship toward the heavier side
	if flood > 0.05:
		var heavy: float = 0.0
		for i in damage.section_count:
			heavy += damage.water_t[i] * (1.0 if damage.section_is_starboard(i) else -1.0)
		state.apply_torque(forward * heavy * 9.81 * stats.beam_m * 0.15)

	# Roll and pitch damping (local axes)
	var local_av: Vector3 = xf.basis.inverse() * state.angular_velocity
	local_av.x *= exp(-PITCH_DAMP * dt)
	local_av.z *= exp(-ROLL_DAMP * dt)
	state.angular_velocity = xf.basis * local_av


## Heading as a flat unit vector (x, z).
func heading() -> Vector2:
	var f: Vector3 = -global_transform.basis.z
	return Vector2(f.x, f.z).normalized()


func speed_knots() -> float:
	return MathUtils.ms_to_knots(linear_velocity.length())


func heel_deg() -> float:
	return rad_to_deg(asin(clampf(global_transform.basis.x.y, -1.0, 1.0)))


func pitch_deg() -> float:
	return rad_to_deg(asin(clampf(-global_transform.basis.z.y, -1.0, 1.0)))


func _build_visuals() -> void:
	visuals = ShipVisuals.new()
	visuals.build(self)
	_hull_material = visuals.hull_material


const CUT_LOOSE_S: float = 10.0


func _physics_process(delta: float) -> void:
	if damage == null:
		return
	_bump_cool = maxf(_bump_cool - delta, 0.0)
	if mast_drag_s > 0.0:
		mast_drag_s -= delta * maxf(float(crew.count) / 6.0, 0.25)  # more hands cut it loose sooner
		if mast_drag_s <= 0.0:
			var debris: DebrisManager = get_tree().get_first_node_in_group("debris") as DebrisManager
			if debris != null:
				debris.spawn_spar(global_position + global_transform.basis.x * _mast_side * stats.beam_m, stats.length_m * 0.5)
	var rc: float = crew.repair_crew()
	damage.tick(delta, rc)
	_fire_fx_timer += delta
	if _fire_fx_timer >= 0.5:
		_fire_fx_timer = 0.0
		for i in damage.section_count:
			if damage.fire_level[i] > 0:
				Vfx.flames(get_parent(), to_global(section_center(i) + Vector3(0, 1.0, 0)))
	if damage.sunk:
		sail_level = 0
		rudder_input = 0.0


var _fire_fx_timer: float = 0.0


func section_center(i: int) -> Vector3:
	var l: float = stats.length_m
	if damage.section_count == 4:
		match i:
			0: return Vector3(0, 0.5, -0.4 * l)
			1: return Vector3(-stats.beam_m * 0.3, 0.5, 0.0)
			2: return Vector3(stats.beam_m * 0.3, 0.5, 0.0)
			_: return Vector3(0, 0.5, 0.4 * l)
	if i == 0:
		return Vector3(0, 0.5, -0.45 * l)
	if i == 7:
		return Vector3(0, 0.5, 0.45 * l)
	var band: int = (i - 1) / 2
	var side: float = 1.0 if (i - 1) % 2 == 1 else -1.0
	return Vector3(side * stats.beam_m * 0.3, 0.5, lerpf(-0.27, 0.27, band / 2.0) * l)


## Called by the projectile manager when a cannonball touches the hull.
func receive_cannonball(world_pos: Vector3, world_normal: Vector3, world_dir: Vector3, gun_id: String,
		ammo_id: String, distance: float, source: Node) -> Dictionary:
	if has_meta("ghost") and ammo_id != "heated" and ammo_id != "blessed":
		return {"killed": 0, "ricochet": false, "ghost": true}  # the shot passes through the ghost hull
	var info := HitInfo.new()
	var inv: Transform3D = global_transform.affine_inverse()
	info.local_position = inv * world_pos
	info.local_normal = (inv.basis * world_normal).normalized()
	info.direction = (inv.basis * world_dir).normalized()
	info.gun_id = gun_id
	info.ammo_id = ammo_id
	info.damage = GunData.damage_at_range(gun_id, distance, ammo_id)
	if faction == "player":
		info.damage *= float(Difficulty.value("damage_taken"))
	if source != null and source != self:
		last_attacker = source
	info.source = source
	var water_y: float = ocean.height_at(world_pos.x, world_pos.z) if ocean else 0.0
	info.below_waterline = world_pos.y < water_y
	var result: Dictionary = damage.apply_hit(info)
	if result["killed"] > 0:
		crew.kill(result["killed"])
	var parent: Node = get_parent()
	if result["ricochet"]:
		Vfx.burst(parent, world_pos, Color(1, 0.9, 0.5), 8, 8.0, 0.4, 0.06, -9.8, 60.0, world_normal)
	else:
		Vfx.splinters(parent, world_pos)
		Sfx.play("wood_impact", world_pos)
		Sfx.play("splinter", world_pos)
	_update_damage_visuals()
	hit_taken.emit(result)
	return result


func _on_mast_fell(index: int) -> void:
	Sfx.play("mast_snap", global_position)
	if faction == "player":
		Sfx.bark("mast_down")
	mast_drag_s = CUT_LOOSE_S
	_mast_side = 1.0 if index % 2 == 0 else -1.0
	if visuals and index < visuals.mast_groups.size():
		var g: Node3D = visuals.mast_groups[index]
		Vfx.splinters(get_parent(), g.global_position + Vector3.UP * 4.0)
		Vfx.splinters(get_parent(), g.global_position + Vector3.UP * 9.0)
		visuals.set_mast_visible(index, false)


## Two bodies touched. Turns the closing speed into hull damage, leaks, a broken mast, men overboard,
## floating crates and (on sand) running aground.
func _on_contact(body: Node) -> void:
	if damage == null or damage.sunk or _bump_cool > 0.0:
		return
	var other_mass: float = 0.0
	var v2: Vector3 = Vector3.ZERO
	var material: String = "ship"
	var away: Vector3 = global_position - (body as Node3D).global_position
	if body is Ship:
		other_mass = (body as Ship).mass
		v2 = (body as Ship).prev_velocity
	elif body.has_meta("island"):
		material = _island_material(body as Island)
	else:
		return
	away.y = 0.0
	var n: Vector3 = (-away).normalized()  # from us towards the other body
	var rel: Vector3 = prev_velocity - v2
	var closing: float = maxf(rel.dot(n), 0.0)
	if closing < 0.6:
		return
	_bump_cool = 0.5
	var player: bool = ai == null
	var rams: bool = player and Session.has_state() and int(Session.state["upgrades"].get("ram", 0)) > 0 and (-global_transform.basis.z).dot(n) > 0.8
	var e: float = CollisionModel.impact_energy(mass, other_mass, closing)
	var dmg: float = CollisionModel.hull_damage(e, material, rams, false)
	if body is Ship:
		var theirs: Ship = body as Ship
		var their_ram: bool = theirs.ai == null and Session.has_state() and int(Session.state["upgrades"].get("ram", 0)) > 0
		dmg = CollisionModel.hull_damage(e, material, rams, their_ram)
	var verdict: String = "bump"
	if material in ["sand", "rock", "ice", "reef"]:
		var tide: float = OceanCurrent.tide_m(_game_hours())
		verdict = grounding.touch(material, MathUtils.ms_to_knots(closing), tide, Vector2(away.x, away.z).normalized())
		if verdict == "stuck":
			EventBus_toast("ship.aground" if player else "")
	var local_contact: Vector3 = to_local(global_position + n * stats.length_m * 0.45)
	var section: int = damage.section_for(local_contact)
	var cons: Dictionary = CollisionModel.consequences(dmg, stats.hull_hp, crew.count, stats.cargo_t if player else 0.0, damage.rng)
	var res: Dictionary = damage.apply_impact(section, dmg, CollisionModel.LEAK_T_PER_S if cons["leak"] else (CollisionModel.hole_leak() if verdict == "hole" else 0.0), cons["mast_breaks"])
	if int(cons["overboard"]) > 0:
		crew.kill(int(cons["overboard"]))
		if player:
			EventBus_toast("ship.overboard", int(cons["overboard"]))
	_drop_crates(int(cons["crates"]), player)
	Vfx.splinters(get_parent(), global_position + n * stats.length_m * 0.4 + Vector3.UP)
	if body is Ship:  # the other ship feels it too, scaled by who has the ram
		var other: Ship = body as Ship
		var their: float = CollisionModel.hull_damage(e, "ship", false, rams)
		if rams:
			their = CollisionModel.hull_damage(e, "ship", true, false)
		var their_section: int = other.damage.section_for(other.to_local(other.global_position - n * other.stats.length_m * 0.45))
		other.damage.apply_impact(their_section, their, CollisionModel.LEAK_T_PER_S if their / other.stats.hull_hp > CollisionModel.LEAK_FRACTION else 0.0, false)
		other._bump_cool = 0.5
	hit_taken.emit({"collision": true, "hull": dmg, "section": section, "verdict": verdict, "mast": res["mast_fell"]})
	_update_damage_visuals()


func _island_material(isl: Island) -> String:
	if isl.biome == "ice":
		return "ice"
	var toward: Vector3 = isl.global_position - global_position
	var local := Vector2(-toward.x, -toward.z)  # our position relative to the island centre
	var probe: Vector2 = local - local.normalized() * 10.0
	return "sand" if isl.ground_y(probe) < 3.0 else "rock"


func _game_hours() -> float:
	var clock: Node = get_node_or_null("/root/GameClock")
	return (float(clock.day) * 24.0 + float(clock.hour)) if clock != null else 0.0


func _drop_crates(n: int, player: bool) -> void:
	if n <= 0:
		return
	var debris: DebrisManager = get_tree().get_first_node_in_group("debris") as DebrisManager
	if debris == null:
		return
	for i in n:
		var cargo: Dictionary = {}
		if player and Session.has_state():
			var best: String = ""
			for g: String in Session.state["cargo"]:
				if best == "" or float(Session.state["cargo"][g]) > float(Session.state["cargo"][best]):
					best = g
			if best != "":
				var take: float = minf(float(Session.state["cargo"][best]), 10.0)
				Session.state["cargo"][best] = float(Session.state["cargo"][best]) - take
				cargo[best] = take
		if cargo.is_empty():
			cargo = {"timber": 5.0}
		debris.spawn_crate(global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), cargo)


func EventBus_toast(key: String, arg: int = -1) -> void:
	if key == "":
		return
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(Loc.t(key) % arg if arg >= 0 else Loc.t(key))


func _on_sank() -> void:
	var debris: DebrisManager = get_tree().get_first_node_in_group("debris") as DebrisManager
	if debris != null:
		var cargo: Dictionary = Session.state["cargo"].duplicate() if (ai == null and Session.has_state()) else {}
		debris.break_up(global_position, stats, cargo)
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.ship_sunk.emit(Vector2(global_position.x, global_position.z), stats.class_id)
	sink_started = true
	sank_signal.emit()
	get_tree().create_timer(45.0).timeout.connect(queue_free)


var sink_started: bool = false
var visuals: ShipVisuals
var _hull_material: ShaderMaterial


func _update_damage_visuals() -> void:
	if _hull_material:
		var f: float = damage.hull_fraction()
		_hull_material.set_shader_parameter("tint", Color.WHITE.lerp(Color(0.35, 0.3, 0.3), 1.0 - f))


func _process(delta: float) -> void:
	if visuals:
		visuals.update(delta)


func strength_rating() -> float:
	var gun_damage: float = GunData.GUNS[broadside.gun_id]["damage"]
	return AiLogic.strength(damage.hull_fraction(), stats.guns_per_side, gun_damage,
		float(crew.count) / float(stats.crew_max), stats.armor)


func surrender() -> void:
	if has_surrendered:
		return
	has_surrendered = true
	sail_level = 0
	surrendered.emit()
