class_name Session
extends RefCounted
## The running game: the state dictionary, slots, and the hops between menu, loading screen and world.

const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const WORLD_SCENE: String = "res://scenes/world.tscn"
const SLOTS: Array[int] = [1, 2, 3]
const AUTOSAVE_SLOT: int = 0
const START_POS: Vector2 = Vector2(0.0, 420.0)
const START_YAW_DEG: float = -90.0

static var state: Dictionary = {}
static var playtime_s: float = 0.0


static func _clock() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameClock") if tree != null else null


static func _set_clock(day: int, hour: float) -> void:
	var clock: Node = _clock()
	if clock != null:
		clock.day = day
		clock.hour = hour


static func has_state() -> bool:
	return not state.is_empty()


static func begin_new(captain: String, difficulty: int, seed_value: int) -> void:
	state = SaveGame.new_state()
	state["captain"] = captain if captain.strip_edges() != "" else Loc.t("menu.default_captain")
	state["difficulty"] = clampi(difficulty, 0, 3)
	state["seed"] = seed_value
	playtime_s = 0.0
	_set_clock(int(state["day"]) + 1, state["hour"])


static func load_slot(slot: int) -> bool:
	var d: Dictionary = SaveGame.read(slot)
	if d.is_empty():
		return false
	state = d
	playtime_s = float(d.get("playtime", 0.0))
	_set_clock(int(d["day"]), float(d["hour"]))
	return true


## Copy live values from the running world into the state.
static func capture(world: Node) -> void:
	var ship: Ship = world.get("ship")
	if ship != null:
		state["pos"] = [ship.global_position.x, ship.global_position.z]
		state["yaw"] = ship.rotation_degrees.y
		state["ship_hull"] = ship.damage.hull_fraction()
		reconcile_crew(ship)
		state["sail_level"] = ship.sail_level
		state["morale"] = ship.crew.morale
		for k: String in ship.broadside.ammo:
			state["ammo"][k] = int(ship.broadside.ammo[k])
	var clock: Node = _clock()
	if clock != null:
		state["day"] = clock.day
		state["hour"] = clock.hour
	state["playtime"] = playtime_s
	state["saved_at"] = int(Time.get_unix_time_from_system())


## Stats of the player's ship with upgrades applied; the old sloop demo when no game is running.
static func player_stats() -> ShipStats:
	if state.is_empty():
		return load("res://data/ships/sloop.tres")
	var stats: ShipStats = UpgradeEffects.apply(PortService.ship_stats(state["ship_class"]), state["upgrades"])
	stats.max_speed_kn *= float(CrewEffects.compute(state["roster"])["speed_mult"])  # a navigator's +4%
	stats.max_speed_kn *= Progression.stat(state, "speed_mult")
	stats.turn_rate_deg_s *= Progression.stat(state, "turn_mult")
	stats.cargo_t *= Progression.stat(state, "cargo_mult")
	return stats


## Put saved values back into a freshly built world.
static func apply(world: Node) -> void:
	if state.is_empty():
		return
	var ship: Ship = world.get("ship")
	if ship == null:
		return
	var pos: Array = state.get("pos", [START_POS.x, START_POS.y])
	ship.position = Vector3(float(pos[0]), 0.0, float(pos[1]))
	ship.rotation_degrees.y = float(state.get("yaw", START_YAW_DEG))
	ship.sail_level = int(state.get("sail_level", 0))
	apply_to_ship(ship)


## Push the state's crew, ammunition, hull and morale into the live ship. Called after the player changed
## something in port, so the ship and the state agree before the next capture.
static func apply_to_ship(ship: Ship) -> void:
	ship.crew.count = CrewLife.fit_crew(state)
	ship.crew.captain_hands = 1
	ship.crew.brief_morale = true
	var fx: Dictionary = CrewEffects.compute(state["roster"])
	ship.crew.quality = float(fx["quality"])
	ship.broadside.spread_scale = float(fx["spread_mult"]) * Progression.stat(state, "spread_mult")
	ship.broadside.reload_scale = float(fx["reload_mult"]) * Progression.stat(state, "reload_mult")
	ship.broadside.double_shot_chance = Progression.stat(state, "double_shot_chance")
	ship.broadside.mast_crit = Progression.stat(state, "mast_crit_chance")
	ship.crew.morale = float(state["morale"])
	ship.display_label = str(state["ship_name"])
	for k: String in state["ammo"]:
		ship.broadside.ammo[k] = int(state["ammo"][k])
	apply_hull(ship)


static func apply_hull(ship: Ship) -> void:
	var frac: float = clampf(float(state["ship_hull"]), 0.05, 1.0)
	for i in ship.damage.section_hp.size():
		ship.damage.section_hp[i] = ship.damage.section_max * frac


## Men who fell on the ship since the state last saw it (guns, boarding) become casualties in the state.
static func reconcile_crew(ship: Ship) -> Dictionary:
	var lost: int = CrewLife.fit_crew(state) - ship.crew.count
	if lost <= 0:
		return {"dead": 0, "wounded": 0}
	return CrewLife.casualties(state, lost)


## Written to the autosave slot whenever the player leaves port.
static func autosave(world: Node) -> void:
	save_to(world, AUTOSAVE_SLOT)


static func save_to(world: Node, slot: int) -> bool:
	capture(world)
	return SaveGame.write(state, slot)


## Newest slot holding a save, or -1.
static func latest_slot() -> int:
	var best: int = -1
	var best_t: int = -1
	for s in [AUTOSAVE_SLOT] + SLOTS:
		var d: Dictionary = SaveGame.read(s)
		if d.is_empty():
			continue
		var t: int = int(d.get("saved_at", 0))
		if t >= best_t:
			best_t = t
			best = s
	return best


static func summary(slot: int) -> String:
	var d: Dictionary = SaveGame.read(slot)
	if d.is_empty():
		return Loc.t("menu.empty_slot")
	return Loc.t("menu.slot_summary") % [str(d.get("captain", "?")), int(d["day"]), int(d["gold"]), int(d["crew"]), Time.get_datetime_string_from_unix_time(int(d.get("saved_at", 0))).replace("T", " ")]


static func enter_world(tree: SceneTree) -> void:
	tree.paused = false
	var loading := LoadingScreen.new()
	loading.target_path = WORLD_SCENE
	tree.root.add_child(loading)
	if tree.current_scene != null:
		tree.current_scene.queue_free()
		tree.current_scene = null


static func quit_to_menu(tree: SceneTree) -> void:
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)
