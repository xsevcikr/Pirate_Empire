extends Node3D
## M1 sailing scene: ocean, sky, wind, one sloop and a chase camera.

const DOCK_HIT_RADIUS_M: float = 28.0
const FISH_MAX_KN: float = 2.0
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
var tours: TourDirector
var rivals: RivalDirector
var crews: CrewDirector
var progress: ProgressDirector
var world_audio: WorldAudio
var streamer: WorldStreamer
var debris: DebrisManager
var _dock_hit_cool: float = 0.0
var discovery: Discovery
var _discover_accum: float = 99.0
var _drift_log: Dictionary = {}
var _last_market_h: float = -1.0
var _last_repair_h: float = -1.0
var _trade_rng := RandomNumberGenerator.new()


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
	# The Kenney starter-scene recipe: strong tinted ambient, filmic tone mapping, soft AO and a little bloom, plus a
	# touch of colour grading so everything reads bright and flat-coloured.
	env.fog_enabled = true
	Look.apply_environment(env)
	env.fog_density = 0.0006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	Look.apply_sun(sun, 250.0)
	add_child(sun)

	ocean = Ocean.new()
	ocean.model = WaveModel.new(wind.sea_state(), wind.direction)
	add_child(ocean)

	streamer = WorldStreamer.new()
	streamer.world = self
	add_child(streamer)
	streamer.building_destroyed.connect(_on_building_destroyed)

	ship = Ship.new()
	ship.stats = Session.player_stats()
	ship.ocean = ocean.model
	ship.wind = wind
	ship.position = Vector3(0, 0.0, 420)
	ship.rotation_degrees.y = -90.0
	add_child(ship)
	ocean.follow = ship
	streamer.player = ship
	debris = DebrisManager.new()
	debris.ocean = ocean.model
	debris.player = ship
	debris.picked_up.connect(_on_debris_picked_up)
	add_child(debris)
	EventBus.ship_sunk.connect(_on_ship_sunk)
	streamer.load_all_near(Vector2(ship.position.x, ship.position.z))

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
	var clouds := CloudLayer.new()
	add_child(clouds)
	day_night.clouds = clouds
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
	tours = TourDirector.new()
	tours.ship = ship
	tours.world = self
	tours.state = Session.state
	add_child(tours)
	rivals = RivalDirector.new()
	rivals.ship = ship
	rivals.world = self
	rivals.state = Session.state
	add_child(rivals)
	crews = CrewDirector.new()
	crews.ship = ship
	crews.world = self
	crews.state = Session.state
	add_child(crews)
	progress = ProgressDirector.new()
	progress.ship = ship
	progress.state = Session.state
	add_child(progress)
	tours.step_completed.connect(progress.on_tour_step)
	tours.tour_completed.connect(progress.on_tour_done)
	world_audio = WorldAudio.new()
	world_audio.world = self
	add_child(world_audio)
	apply_customization()
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


## Three ghost sloops rise round a point; only heated or blessed shot hurts them.
func spawn_ghost_sloops(at: Vector2) -> Array[Ship]:
	var out: Array[Ship] = []
	for i in TourHazards.GHOST_SLOOPS:
		var s: Ship = _make_ship(load("res://data/ships/sloop.tres"), Vector3(at.x + 260.0 * (i + 1), 0.5, at.y + 120.0 * i), 90.0, "pirate")
		s.set_meta("ghost", true)
		s.sail_level = 2
		s.crew.count = 12
		var ai := ShipAI.new()
		ai.ship = s
		ai.waypoints = [Vector3(at.x, 0, at.y), Vector3(at.x + 500.0, 0, at.y + 500.0)]
		s.ai = ai
		s.add_child(ai)
		out.append(s)
	return out


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
	var island: Dictionary = gen.islands[gen.index_of(job["island_name"])]
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
		_rebuild_tick()


## Buildings destroyed three or more days ago are rebuilt.
func _rebuild_tick() -> void:
	var now: int = int(Session.state["day"])
	for id: String in Session.state["destroyed"].keys():
		if float(now - int(Session.state["destroyed"][id])) >= DestructionData.REBUILD_DAYS:
			Session.state["destroyed"].erase(id)
	for id: String in streamer.ports:
		streamer.ports[id].rebuild_due()


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
	var here: String = dock_port()
	var near_port: bool = here != ""
	var faction: String = PortData.PORTS[here if near_port else PortData.START_PORT]["faction"]
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
## The port whose dock zone the ship is in, or "".
func dock_port() -> String:
	return PortData.port_near(Vector2(ship.global_position.x, ship.global_position.z))


func can_dock() -> bool:
	return dock_port() != "" and ship.speed_knots() <= PortData.DOCK_MAX_SPEED_KN


## Tonnage in the hold times the fee, at lawful ports only.
func _docking_fee(port_id: String) -> int:
	if not bool(PortData.PORTS[port_id]["lawful"]):
		return 0
	return mini(int(PortService.cargo_used(Session.state) * PortData.DOCK_FEE_PER_TONNE), int(Session.state["gold"]))


func open_port() -> void:
	if get_node_or_null("PortLayer") != null:
		return
	var menu := PortMenu.new()
	menu.port_id = dock_port() if dock_port() != "" else PortData.START_PORT
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
	if Session.has_state() and event.is_action_pressed("tour_journal"):
		open_journal()
		get_viewport().set_input_as_handled()
		return
	if Session.has_state() and event.is_action_pressed("interior"):
		open_interior()
		get_viewport().set_input_as_handled()
		return
	for pair: Array in [["skills", "open_skills"], ["captain_log", "open_log"], ["customize", "open_customize"], ["fish", "open_fishing"]]:
		if Session.has_state() and event.is_action_pressed(pair[0]):
			call(pair[1])
			get_viewport().set_input_as_handled()
			return
	if Session.has_state() and event.is_action_pressed("rivals"):
		open_rivals()
		get_viewport().set_input_as_handled()
		return
	if Session.has_state() and event.is_action_pressed("world_map"):
		open_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and get_node_or_null("PauseMenu") == null and get_node_or_null("MapLayer") == null:
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


## Reveal the chart around the ship, learn the streams it sails, and let the water carry every ship.
func _navigate(delta: float) -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	var hours: float = (float(clock.day) * 24.0 + float(clock.hour)) if clock != null else 0.0
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s.damage.sunk:
			continue
		var drift: Vector2 = OceanCurrent.velocity_at(Vector2(s.global_position.x, s.global_position.z), hours)
		s.global_position += Vector3(drift.x, 0.0, drift.y) * delta
	_discover_accum += delta
	if _discover_accum < 1.0 or not Session.has_state():
		return
	_discover_accum = 0.0
	var at := Vector2(ship.global_position.x, ship.global_position.z)
	if discovery == null:
		discovery = SaveGame.restore_discovery(str(Session.state["discovery"]))
	var before: int = discovery.count()
	var mult: float = float(CrewEffects.compute(Session.state["roster"])["reveal_radius_mult"])
	discovery.reveal_around(at, 1500.0 * mult)
	if discovery.count() != before:
		Session.state["discovery"] = SaveGame.capture_discovery(discovery)
	for id in OceanCurrent.streams_at(at):
		if not Session.state["streams_known"].has(id):
			Session.state["streams_known"].append(id)
			EventBus.toast.emit(Loc.t("map.stream_learned"))
	if overlay != null:
		var v: Vector2 = OceanCurrent.velocity_at(at, hours)
		overlay.set_nav(Loc.t("hud.nav") % [v.length() / OceanCurrent.KN_TO_MS, _compass(v), OceanCurrent.tide_m(hours), Loc.t("tide.rising" if OceanCurrent.tide_rising(hours) else "tide.falling")])


static func _compass(v: Vector2) -> String:
	if v.length() < 0.05:
		return "-"
	var names: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]  # x east, y south
	return names[int(round(fposmod(v.angle(), TAU) / (TAU / 8.0))) % 8]


## A fort part or harbour building fell: the owner's standing drops, a harbour building thins the port's stock.
func _on_building_destroyed(b: DestructibleBuilding, by_player: bool) -> void:
	EventBus.building_destroyed.emit(b.port_id, b.kind, by_player)
	if not by_player or not Session.has_state() or not PortData.PORTS.has(b.port_id):
		return
	var faction: String = PortData.PORTS[b.port_id]["faction"]
	Session.state["rep"][faction] = clampf(float(Session.state["rep"][faction]) + DestructionData.rep_cost(b.kind), -100.0, 100.0)
	if not DestructionData.is_fort_part(b.kind):
		Blockade.building_destroyed(Session.state, b.port_id)
	EventBus.toast.emit(Loc.t("destroy.fell") % [Loc.t("building." + b.kind), PortData.PORTS[b.port_id]["name"]])


func _on_ship_sunk(pos: Vector2, class_id: String) -> void:
	if not Session.has_state():
		return
	var wrecks: Array = Session.state["wrecks"]
	wrecks.append({"x": pos.x, "y": pos.y, "class": class_id, "day": int(Session.state["day"])})
	while wrecks.size() > 60:
		wrecks.pop_front()


func _on_debris_picked_up(kind: String, payload: Dictionary) -> void:
	var s: Dictionary = Session.state
	if payload.has("cargo"):
		for g: String in payload["cargo"]:
			var room: float = PortService.cargo_free(s)
			var units: float = minf(float(payload["cargo"][g]), floorf(maxf(room, 0.0) / Goods.DATA[g]["weight"]))
			if units > 0.0:
				s["cargo"][g] = float(s["cargo"].get(g, 0.0)) + units
				EventBus.toast.emit(Loc.t("destroy.salvaged") % [int(units), Loc.t("good." + g)])
	if payload.has("supplies"):
		for k: String in payload["supplies"]:
			s["supplies"][k] = float(s["supplies"][k]) + float(payload["supplies"][k])
		EventBus.toast.emit(Loc.t("destroy.barrel"))


## Kedging, tide and dumping cargo free a ship that is aground; a fast arrival at the pier costs a fine.
func _seamanship(delta: float) -> void:
	var g: Grounding = ship.grounding
	if g.stuck:
		var clock: Node = get_node_or_null("/root/GameClock")
		var hours: float = (float(clock.day) * 24.0 + float(clock.hour)) if clock != null else 0.0
		var freed: bool = g.kedge(delta * Progression.stat(Session.state, "kedge_speed_mult"), Input.is_action_pressed("kedge")) or g.tide_check(OceanCurrent.tide_m(hours))
		if freed:
			EventBus.stat_event.emit("kedged_free", 1.0)
		if Input.is_action_just_pressed("dump_cargo") and Session.has_state():
			var dumped: Dictionary = g.dump_cargo(Session.state["cargo"])
			freed = not g.stuck
			if not dumped.is_empty():
				EventBus.toast.emit(Loc.t("ship.dumped"))
		if freed:
			ship.global_position += Vector3(g.normal.x, 0.0, g.normal.y) * 12.0
			EventBus.toast.emit(Loc.t("ship.freed"))
	_dock_hit_cool = maxf(_dock_hit_cool - delta, 0.0)
	var port: String = PortData.port_near(Vector2(ship.global_position.x, ship.global_position.z), DOCK_HIT_RADIUS_M)
	if port != "" and _dock_hit_cool <= 0.0 and ship.speed_knots() > CollisionModel.DOCK_MAX_KN:
		_dock_hit_cool = 6.0
		var hit: Dictionary = CollisionModel.dock_hit(ship.speed_knots(), ship.stats.mass_kg)
		ship.damage.apply_impact(0, float(hit["bow_damage"]), 0.0, false)
		if PortData.PORTS[port]["lawful"] and Session.has_state():
			Session.state["gold"] = maxi(int(Session.state["gold"]) - int(hit["fine"]), 0)
			EventBus.toast.emit(Loc.t("ship.dock_fine") % int(hit["fine"]))
		for b in streamer.ports[port].buildings if streamer.ports.has(port) else []:
			if b.kind == "dock" and b.is_alive():
				b.hurt(float(hit["dock_damage"]), true)
				break


func open_journal() -> void:
	if get_node_or_null("MapLayer") != null or get_node_or_null("PortLayer") != null or tours == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := TourJournalScreen.new()
	screen.director = tours
	layer.add_child(screen)
	screen.closed.connect(layer.queue_free)


## A sea monster out of a tour: the fight panel opens over the sea.
func open_sea_fight(fight: MonsterFight) -> void:
	if get_node_or_null("MapLayer") != null or get_node_or_null("PortLayer") != null or tours == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := TourEncounterScreen.new()
	screen.director = tours
	screen.fight = fight
	layer.add_child(screen)
	screen.closed.connect(layer.queue_free)


func open_interior() -> void:
	if get_node_or_null("MapLayer") != null or get_node_or_null("PortLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := InteriorScreen.new()
	screen.stats = ship.stats
	layer.add_child(screen)
	screen.closed.connect(layer.queue_free)


func _open_screen(screen: MenuScreen) -> MenuScreen:
	if get_node_or_null("MapLayer") != null or get_node_or_null("PortLayer") != null:
		screen.free()
		return null
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(screen)
	screen.closed.connect(layer.queue_free)
	return screen


func open_skills() -> void:
	_open_screen(SkillsScreen.new())


func open_log() -> void:
	_open_screen(JournalScreen.new())


func open_customize() -> void:
	var screen: MenuScreen = _open_screen(CustomizeScreen.new())
	if screen != null:
		(screen as CustomizeScreen).changed.connect(apply_customization)


## Fishing needs a ship that is nearly still.
func open_fishing() -> void:
	if ship.speed_knots() > FISH_MAX_KN:
		EventBus.toast.emit(Loc.t("fish.too_fast"))
		return
	_open_screen(FishingScreen.make(int(Session.state["seed"]) + int(Session.state["day"]) * 13 + int(Time.get_ticks_msec() % 991)))


## Push the flag, sail, hull and name choices onto the ship's look.
func apply_customization() -> void:
	ShipCustom.apply(ship, Customization.get_custom(Session.state))


func open_rivals() -> void:
	if get_node_or_null("MapLayer") != null or get_node_or_null("PortLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := RivalScreen.new()
	layer.add_child(screen)
	screen.closed.connect(layer.queue_free)


func open_map() -> void:
	if get_node_or_null("MapLayer") != null or get_node_or_null("PortLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := WorldMapScreen.new()
	screen.player_pos = Vector2(ship.global_position.x, ship.global_position.z)
	screen.player_heading = ship.heading()
	screen.max_speed_kn = Session.player_stats().max_speed_kn
	layer.add_child(screen)
	screen.closed.connect(layer.queue_free)


func _physics_process(delta: float) -> void:
	Session.playtime_s += delta
	if Session.has_state():
		_game_tick()
	_navigate(delta)
	_seamanship(delta)
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
