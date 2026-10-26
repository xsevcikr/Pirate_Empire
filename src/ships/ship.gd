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
	damage = DamageModel.new(stats)
	crew = CrewState.new(stats)
	damage.mast_fell.connect(_on_mast_fell)
	damage.sank.connect(_on_sank)
	damage.magazine_exploded.connect(func() -> void: Vfx.explosion(get_parent(), global_position + Vector3.UP * 2.0))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)
	# Replace the project-wide default damping; drag is modelled explicitly below.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = false
	can_sleep = false
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
		state.apply_central_force(-forward * _k_drag * speed_forward_ms * absf(speed_forward_ms))
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


func _physics_process(delta: float) -> void:
	if damage == null:
		return
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
	var info := HitInfo.new()
	var inv: Transform3D = global_transform.affine_inverse()
	info.local_position = inv * world_pos
	info.local_normal = (inv.basis * world_normal).normalized()
	info.direction = (inv.basis * world_dir).normalized()
	info.gun_id = gun_id
	info.ammo_id = ammo_id
	info.damage = GunData.damage_at_range(gun_id, distance, ammo_id)
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
	_update_damage_visuals()
	hit_taken.emit(result)
	return result


func _on_mast_fell(index: int) -> void:
	if visuals and index < visuals.mast_groups.size():
		var g: Node3D = visuals.mast_groups[index]
		Vfx.splinters(get_parent(), g.global_position + Vector3.UP * 4.0)
		Vfx.splinters(get_parent(), g.global_position + Vector3.UP * 9.0)
		visuals.set_mast_visible(index, false)


func _on_sank() -> void:
	sink_started = true
	sank_signal.emit()
	get_tree().create_timer(45.0).timeout.connect(queue_free)


var sink_started: bool = false
var visuals: ShipVisuals
var _hull_material: StandardMaterial3D


func _update_damage_visuals() -> void:
	if _hull_material:
		var f: float = damage.hull_fraction()
		_hull_material.albedo_color = Color.WHITE.lerp(Color(0.35, 0.3, 0.3), 1.0 - f)


func _process(delta: float) -> void:
	if visuals:
		visuals.update(delta)
