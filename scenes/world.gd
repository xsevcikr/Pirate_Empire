extends Node3D
## M1 sailing scene: ocean, sky, wind, one sloop and a chase camera.

const SLOOP: ShipStats = preload("res://data/ships/sloop.tres")

var wind := WindModel.new()
var ocean: Ocean
var ship: Ship
var day_night := DayNight.new()
var rig: CameraRig
var projectiles: ProjectileManager
var target: Ship
var _markers: Array[MeshInstance3D] = []
var _last_sea_state: float = -1.0


func _ready() -> void:
	GameInput.register()
	wind.direction = Vector2(0.0, 1.0).rotated(deg_to_rad(-90.0))  # wind blows toward +X (from port)
	wind.speed_kn = 16.0

	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_density = 0.0006
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)

	ocean = Ocean.new()
	ocean.model = WaveModel.new(wind.sea_state(), wind.direction)
	add_child(ocean)

	ship = Ship.new()
	ship.stats = SLOOP
	ship.ocean = ocean.model
	ship.wind = wind
	ship.position = Vector3(0, 0.0, 0)
	ship.rotation_degrees.y = 0.0
	add_child(ship)
	ocean.follow = ship

	projectiles = ProjectileManager.new()
	projectiles.ocean = ocean.model
	add_child(projectiles)
	ship.broadside.projectiles = projectiles

	target = Ship.new()
	target.stats = load("res://data/ships/brigantine.tres")
	target.ocean = ocean.model
	target.wind = wind
	target.sail_level = 0
	target.position = Vector3(110, 0.5, -30)
	target.rotation_degrees.y = 90.0
	add_child(target)
	target.broadside.projectiles = projectiles

	for side in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 2.2
		torus.outer_radius = 2.6
		ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.3, 1.0, 0.4, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_markers.append(ring)

	var pc := PlayerController.new()
	pc.ship = ship
	pc.wind = wind
	add_child(pc)

	rig = CameraRig.new()
	rig.target = ship
	add_child(rig)

	day_night.sun = sun
	day_night.env = env
	day_night.sky_material = sky_mat
	day_night.ocean = ocean
	add_child(day_night)

	var hud := SailingHud.new()
	hud.ship = ship
	hud.wind = wind
	hud.target = target
	hud.clock = get_node_or_null("/root/GameClock")
	add_child(hud)


func _physics_process(delta: float) -> void:
	wind.update(delta)
	var ss: float = snappedf(wind.sea_state(), 0.1)
	if absf(ss - _last_sea_state) > 0.05:
		_last_sea_state = ss
		ocean.set_sea_state(ss, wind.direction)


func _update_markers() -> void:
	for side in 2:
		var land: Vector3 = ship.broadside.predicted_landing(side)
		var h: float = ocean.model.height_at(land.x, land.z)
		_markers[side].global_position = Vector3(land.x, h + 0.15, land.z)
		var ready: bool = ship.broadside.ready_count(side) == ship.broadside.gun_count()
		(_markers[side].material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.6) if ready else Color(1.0, 0.35, 0.2, 0.6)


func _process(_delta: float) -> void:
	_update_markers()
	var clock: Node = get_node_or_null("/root/GameClock")
	var hour: float = clock.hour if clock else 17.3
	if Input.is_action_pressed("time_fast") and clock:
		clock.time_scale = 40.0
	elif clock:
		clock.time_scale = 1.0
	day_night.apply_hour(hour)
