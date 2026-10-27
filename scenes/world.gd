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
var player_controller: PlayerController
var hud: SailingHud
var convoys: ConvoyManager
var _last_market_h: float = -1.0
var _last_repair_h: float = -1.0
var _trade_rng := RandomNumberGenerator.new()
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
	player_controller = pc
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

	hud = SailingHud.new()
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
	convoys = ConvoyManager.new()
	convoys.world = self
	convoys.prizes = prizes
	add_child(convoys)
	ship.damage.sank.connect(_on_player_sunk, CONNECT_ONE_SHOT)
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


## Hourly markets, daily crew life and the carpenter's repairs, driven by the game clock.
func _game_tick() -> void:
	var now_h: float = GameClock.day * 24.0 + GameClock.hour
	if _last_market_h < 0.0:
		_last_market_h = now_h
		_last_repair_h = now_h
		return
	if now_h - _last_market_h >= 1.0:
		var hours: float = floorf(now_h - _last_market_h)
		TradeNetwork.spawn_due(Session.state, now_h, _trade_rng)
		TradeNetwork.advance(Session.state, now_h)
		PortService.advance_markets(Session.state, hours)
		_blockade_tick(hours)
		_last_market_h = now_h
	if (now_h - _last_repair_h) * 60.0 >= 1.0:
		_carpenter(( now_h - _last_repair_h) * 60.0)
		_last_repair_h = now_h
	while GameClock.day > int(Session.state["last_tick_day"]):
		Session.state["last_tick_day"] = int(Session.state["last_tick_day"]) + 1
		_daily_crew_tick()
		Finance.accrue(Session.state, 1.0)
		Blockade.heal_days(Session.state, 1.0)


## Armed ships that are hostile to a port's faction and parked within 1.5 km count towards a blockade.
func _blockade_tick(hours: float) -> void:
	var armed: Array[Vector2] = []
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s != null and s != ship and not s.damage.sunk and s.stats.guns_per_side > 0:
			armed.append(Vector2(s.global_position.x, s.global_position.z))
	var mine: Vector2 = Vector2(ship.global_position.x, ship.global_position.z)
	for id: String in PortData.PORTS:
		var n: int = Blockade.armed_near(id, armed)
		if mine.distance_to(PortData.PORTS[id]["dock"]) <= TradeData.BLOCKADE_RADIUS_M and ship.stats.guns_per_side > 0:
			n += 1
		if Blockade.tick(Session.state, id, n, hours):
			EventBus.toast.emit(Loc.t("trade.blockade") % PortData.PORTS[id]["name"])


func _on_player_sunk() -> void:
	var at := Vector2(ship.global_position.x, ship.global_position.z)
	var result: Dictionary = Finance.defeat(Session.state, at)
	EventBus.player_defeated.emit(result)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := DefeatScreen.new()
	screen.result = result
	layer.add_child(screen)
	get_tree().paused = true
	screen.continued.connect(func() -> void:
		layer.queue_free()
		get_tree().paused = false
		var dock: Vector2 = PortData.PORTS[result["port"]]["dock"]
		sync_player_ship()
		ship.global_position = Vector3(dock.x, 0.5, dock.y)
		ship.damage.sank.connect(_on_player_sunk, CONNECT_ONE_SHOT)
		Session.autosave(self))


func _carpenter(minutes: float) -> void:
	if CrewEffects.compute(Session.state["roster"])["repair_hp_per_min"] <= 0.0 or get_node_or_null("PortLayer") != null:
		return
	Session.state["ship_hull"] = ship.damage.hull_fraction()
	if CrewLife.carpenter_repair(Session.state, minutes) > 0.0:
		Session.apply_hull(ship)


func _daily_crew_tick() -> void:
	Session.reconcile_crew(ship)
	var near_port: bool = ship.global_position.distance_to(_dock_world) <= PortData.DOCK_RADIUS_M
	var faction: String = PortData.PORTS[PortData.START_PORT]["faction"]
	var ctx: Dictionary = {"in_port": near_port, "shore_leave": near_port and float(Session.state["rep"][faction]) >= 20.0, "day": GameClock.day}
	var report: Dictionary = CrewLife.daily_tick(Session.state, ctx)
	Session.apply_to_ship(ship)
	if report["no_food"]:
		EventBus.toast.emit(Loc.t("crew.no_food"))
	if report["no_water"]:
		EventBus.toast.emit(Loc.t("crew.no_water"))
	if report["wages_unpaid"]:
		EventBus.toast.emit(Loc.t("crew.unpaid"))
	if int(report["deaths"]) > 0:
		EventBus.toast.emit(Loc.t("crew.died_" + str(report["died_of"] if report["died_of"] != "" else "wounds")) % int(report["deaths"]))
	if int(report["deserted"]) > 0:
		EventBus.toast.emit(Loc.t("crew.deserted") % int(report["deserted"]))
	if report["mutiny"]:
		open_mutiny()


func open_mutiny() -> void:
	if get_node_or_null("MutinyLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "MutinyLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 55
	add_child(layer)
	var screen := MutinyScreen.new()
	layer.add_child(screen)
	screen.resolved.connect(func() -> void:
		Session.apply_to_ship(ship)
		layer.queue_free())


## After port: put the state's crew, ammo and hull on the ship, or build a new ship if a different class was bought.
func sync_player_ship() -> void:
	if ship.stats.class_id != Session.state["ship_class"] or not _upgrades_applied():
		_replace_player_ship()
	Session.apply_to_ship(ship)


func _upgrades_applied() -> bool:
	var expect: ShipStats = Session.player_stats()
	return is_equal_approx(ship.stats.hull_hp, expect.hull_hp) and is_equal_approx(ship.stats.max_speed_kn, expect.max_speed_kn) and ship.stats.crew_max == expect.crew_max and is_equal_approx(ship.stats.turn_rate_deg_s, expect.turn_rate_deg_s)


func _replace_player_ship() -> void:
	var old: Ship = ship
	var fresh := Ship.new()
	fresh.stats = Session.player_stats()
	fresh.ocean = ocean.model
	fresh.wind = wind
	fresh.position = old.position
	fresh.rotation = old.rotation
	fresh.sail_level = old.sail_level
	fresh.faction = old.faction
	add_child(fresh)
	fresh.broadside.projectiles = projectiles
	ship = fresh
	ocean.follow = fresh
	rig.target = fresh
	player_controller.ship = fresh
	hud.ship = fresh
	if prizes != null:
		prizes.player = fresh
	if tutorial != null:
		tutorial.ship = fresh
	old.queue_free()


## Docking: inside the dock zone and slow, Space opens the port menu.
func can_dock() -> bool:
	return ship.global_position.distance_to(_dock_world) <= PortData.DOCK_RADIUS_M and ship.speed_knots() <= PortData.DOCK_MAX_SPEED_KN


## Tonnage in the hold times the fee, at lawful ports only.
func _docking_fee(port_id: String) -> int:
	if not bool(PortData.PORTS[port_id]["lawful"]):
		return 0
	return mini(int(PortService.cargo_used(Session.state) * PortData.DOCK_FEE_PER_TONNE), int(Session.state["gold"]))


func open_port() -> void:
	if get_node_or_null("PortLayer") != null:
		return
	var menu := PortMenu.new()
	var inspect: bool = Smuggling.rolled(Session.state, menu.port_id, _trade_rng)
	var fee: int = _docking_fee(menu.port_id)
	if fee > 0:
		Session.state["gold"] = int(Session.state["gold"]) - fee
		EventBus.toast.emit(Loc.t("trade.dock_fee") % fee)
	var layer := CanvasLayer.new()
	layer.name = "PortLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 50
	add_child(layer)
	layer.add_child(menu)
	menu.world = self
	menu.closed.connect(func() -> void:
		sync_player_ship()
		Session.autosave(self)
		layer.queue_free())
	Session.state["docked_at"] = menu.port_id
	EventBus.port_docked.emit(menu.port_id)
	if inspect:
		var screen := InspectionScreen.new()
		screen.port_id = menu.port_id
		screen.rng = _trade_rng
		screen.leadership_rank = int(CrewEffects.compute(Session.state["roster"]).get("leadership_rank", 0))
		layer.add_child(screen)
		screen.resolved.connect(func(choice: int, _o: Dictionary) -> void:
			EventBus.inspection_resolved.emit(menu.port_id, choice)
			if choice == Smuggling.Choice.FIGHT:
				menu.close())


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
		_game_tick()
	if overlay != null:
		overlay.set_dock_hint(Loc.t("hud.dock_hint") if can_dock() else "")
		var st: Dictionary = Session.state
		overlay.set_info(Loc.t("hud.status") % [int(st["gold"]), CrewLife.days_left(st, "food"), CrewLife.days_left(st, "water"), PortService.cargo_used(st), PortService.cargo_capacity(st), int(st["morale"]), Loc.t("morale." + Morale.band(float(st["morale"])))])
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
