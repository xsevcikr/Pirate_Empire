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
var prizes: PrizeFlow
var overlay: GameOverlay
var tutorial: Tutorial
var _last_market_h: float = -1.0
var _dock_world: Vector3 = Vector3(PortData.PORTS[PortData.START_PORT]["dock"].x, 0.0, PortData.PORTS[PortData.START_PORT]["dock"].y)


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

	var gen := WorldGen.new()
	for i in gen.islands.size():
		var isl: Dictionary = gen.islands[i]
		if (isl["pos"] as Vector2).length() > 3500.0:
			continue
		var node := Island.make(isl["radius"], 100 + i)
		node.position = Vector3(isl["pos"].x, 0.0, isl["pos"].y)
		add_child(node)

	ship = Ship.new()
	ship.stats = Session.player_stats()
	ship.ocean = ocean.model
	ship.wind = wind
	ship.position = Vector3(0, 0.0, 420)
	ship.rotation_degrees.y = -90.0
	add_child(ship)
	ocean.follow = ship

	projectiles = ProjectileManager.new()
	projectiles.ocean = ocean.model
	add_child(projectiles)
	ship.broadside.projectiles = projectiles

	if not Session.has_state():  # the original demo scene: a brigantine to shoot at
		target = Ship.new()
		target.stats = load("res://data/ships/brigantine.tres")
		target.ocean = ocean.model
		target.wind = wind
		target.sail_level = 0
		target.position = Vector3(110, 0.5, 390)
		target.rotation_degrees.y = 90.0
		add_child(target)
		target.broadside.projectiles = projectiles
	add_child(PortScene.new())

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

	Session.apply(self)
	Game.change_state(Game.State.PLAYING)
	if Session.has_state():
		_start_game_layer()


func _start_game_layer() -> void:
	overlay = GameOverlay.new()
	add_child(overlay)
	prizes = PrizeFlow.new()
	prizes.player = ship
	add_child(prizes)
	tutorial = Tutorial.new()
	tutorial.ship = ship
	tutorial.prompt_changed.connect(overlay.set_prompt)
	add_child(tutorial)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step)
	EventBus.quest_taken.connect(func(id: String) -> void: spawn_quest_ship(id))
	_on_tutorial_step(Session.state["tutorial"])
	for id: String in Session.state["quests"]:
		spawn_quest_ship(id)


func _on_tutorial_step(step_id: String) -> void:
	if step_id == "hunt_lugger":
		spawn_lugger()


func _make_ship(stats: ShipStats, pos: Vector3, yaw: float, faction: String) -> Ship:
	var s := Ship.new()
	s.stats = stats
	s.ocean = ocean.model
	s.wind = wind
	s.faction = faction
	s.position = pos
	s.rotation_degrees.y = yaw
	add_child(s)
	s.broadside.projectiles = projectiles
	return s


## Old Finn's fishing lugger: three fishermen, no guns, drifting off the harbour mouth.
func spawn_lugger() -> Ship:
	for t in prizes.targets:
		if is_instance_valid(t) and t.get_meta("tutorial", "") == "lugger":
			return t
	var l: Ship = _make_ship(load("res://data/ships/lugger.tres"), Vector3(-420, 0.5, 520), 200.0, "merchant")
	l.sail_level = 1
	l.crew.count = 3
	l.crew.quality = 0.6
	l.set_meta("tutorial", "lugger")
	l.set_meta("rep_faction", "merchant")
	l.set_meta("loot_seed", 11)
	l.set_meta("loot", {"gold": [60, 90], "supplies": {"food": 6}, "cargo": {"fish": 10}})
	prizes.add_target(l)
	return l


## The ship a quest asks the player to raid, placed near its island.
func spawn_quest_ship(id: String) -> Ship:
	var job: Dictionary = QuestData.JOBS[id]
	for t in prizes.targets:
		if is_instance_valid(t) and t.get_meta("quest", "") == id:
			return t
	var gen := WorldGen.new()
	var island: Dictionary = gen.islands[job["island"]]
	var at: Vector2 = island["pos"] + Vector2(island["radius"] + 260.0, 0.0)
	var spec: Dictionary = job["ship"]
	var stats: ShipStats = load("res://data/ships/%s.tres" % spec["class"]).duplicate()
	stats.guns_per_side = spec["guns_per_side"]
	stats.hull_hp = spec["hull_hp"]
	var m: Ship = _make_ship(stats, Vector3(at.x, 0.5, at.y), 90.0, spec["faction"])
	m.sail_level = 2
	m.crew.count = spec["crew"]
	m.set_meta("quest", id)
	m.set_meta("rep_faction", spec["faction"])
	m.set_meta("loot_seed", 23)
	m.set_meta("loot", job["loot"])
	var ai := ShipAI.new()
	ai.ship = m
	ai.waypoints = [Vector3(at.x + 400.0, 0, at.y), Vector3(at.x, 0, at.y + 400.0)]
	m.ai = ai
	m.add_child(ai)
	prizes.add_target(m)
	return m


## Docking: inside the dock zone and slow, Space opens the port menu.
func can_dock() -> bool:
	return ship.global_position.distance_to(_dock_world) <= PortData.DOCK_RADIUS_M and ship.speed_knots() <= PortData.DOCK_MAX_SPEED_KN


func open_port() -> void:
	if get_node_or_null("PortLayer") != null:
		return
	var menu := PortMenu.new()
	var layer := CanvasLayer.new()
	layer.name = "PortLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 50
	add_child(layer)
	layer.add_child(menu)
	menu.world = self
	menu.closed.connect(func() -> void:
		Session.autosave(self)
		layer.queue_free())
	Session.state["docked_at"] = menu.port_id
	EventBus.port_docked.emit(menu.port_id)


func _unhandled_input(event: InputEvent) -> void:
	if Session.has_state() and event.is_action_pressed("interact") and can_dock() and get_node_or_null("PauseMenu") == null:
		open_port()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and get_node_or_null("PauseMenu") == null:
		var menu := PauseMenu.new()
		menu.name = "PauseMenu"
		menu.world = self
		var layer := CanvasLayer.new()
		layer.name = "PauseMenu"
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.layer = 50
		add_child(layer)
		layer.add_child(menu)
		menu.closed.connect(layer.queue_free)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	Session.playtime_s += delta
	if Session.has_state():
		var now_h: float = GameClock.day * 24.0 + GameClock.hour
		if _last_market_h < 0.0:
			_last_market_h = now_h
		elif now_h - _last_market_h >= 1.0:
			PortService.advance_markets(Session.state, floorf(now_h - _last_market_h))
			_last_market_h = now_h
	if overlay != null:
		overlay.set_dock_hint(Loc.t("hud.dock_hint") if can_dock() else "")
		overlay.set_info(Loc.t("hud.status") % [int(Session.state["gold"]), PortService.food_days(Session.state), PortService.cargo_used(Session.state), PortService.cargo_capacity(Session.state)])
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
