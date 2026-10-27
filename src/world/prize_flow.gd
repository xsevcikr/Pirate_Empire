class_name PrizeFlow
extends Node
## Boarding and looting for the world scene: watches boardable ships near the player, runs the grapple and
## crew-pool fight, pays out the ship's loot and applies the fate the player picks.

signal prize_resolved(info: Dictionary)

const BOARD_RANGE_M: float = 60.0

var player: Ship
var targets: Array[Ship] = []
var _controllers: Dictionary = {}  ## Ship -> BoardingController
var _busy: bool = false


func add_target(ship: Ship) -> void:
	targets.append(ship)
	ship.damage.sank.connect(_on_sunk.bind(ship), CONNECT_ONE_SHOT)


func nearest_in_range() -> Ship:
	var best: Ship = null
	var best_d: float = BOARD_RANGE_M
	for t in targets:
		if is_instance_valid(t) and not t.damage.sunk:
			var d: float = t.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = t
	return best


func _physics_process(delta: float) -> void:
	if player == null or _busy:
		return
	var t: Ship = nearest_in_range()
	if t == null:
		return
	if not _controllers.has(t):
		var bc := BoardingController.new()
		bc.attacker = player
		bc.target = t
		bc.stance = BoardingController.Stance.FULL_ASSAULT
		bc.seed_value = int(Session.state.get("seed", 1)) + int(t.get_meta("loot_seed", 7))
		add_child(bc)
		bc.finished.connect(_on_boarding_finished.bind(t))
		_controllers[t] = bc
	(_controllers[t] as BoardingController).process_grapple(Input.is_action_pressed("grapple"), delta)


func _on_boarding_finished(won: bool, ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	if not won:
		Svc.node("EventBus").toast.emit(Loc.t("prize.repelled"))
		(_controllers[ship] as BoardingController).queue_free()
		_controllers.erase(ship)
		return
	_busy = true
	var loot: Dictionary = roll_loot(ship, Session.state)
	apply_loot(loot, Session.state)
	var lines := PackedStringArray()
	lines.append(Loc.t("prize.gold") % int(loot["gold"]))
	for g: String in loot["cargo"]:
		lines.append("%d × %s" % [int(loot["cargo"][g]), Loc.t("good." + g)])
	for s: String in loot["supplies"]:
		lines.append("%d × %s" % [int(loot["supplies"][s]), Loc.t("supply." + s)])
	if loot["map_fragment"] != "":
		lines.append(Loc.t("prize.map_fragment"))
	var screen := PrizeScreen.new()
	screen.summary_lines = lines
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(layer)
	layer.add_child(screen)
	screen.decided.connect(_on_fate.bind(ship, loot, layer))


func _on_fate(fate: int, ship: Ship, loot: Dictionary, layer: CanvasLayer) -> void:
	layer.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Session.state["seed"]) + int(Session.state["day"])
	var effects: Dictionary = CaptureFate.resolve(fate as CaptureFate.Fate, {"ship_value": ship.stats.price, "cargo_value": 0.0, "equipment_value": 0.0}, rng)
	var faction: String = str(ship.get_meta("rep_faction", "merchant"))
	Session.state["rep"][faction] = clampf(float(Session.state["rep"][faction]) + float(effects["reputation"]), -100.0, 100.0)
	finish_prize(ship, loot, fate)
	if fate == CaptureFate.Fate.STRIP_AND_SINK:
		ship.queue_free()
	_busy = false


## Quest, log and tutorial bookkeeping after a ship was looted. Also used by the scripted test.
func finish_prize(ship: Ship, loot: Dictionary, fate: int) -> void:
	var bus: Node = Svc.node("EventBus")
	var info: Dictionary = {"quest": str(ship.get_meta("quest", "")), "tutorial": str(ship.get_meta("tutorial", "")), "loot": loot, "fate": fate}
	if loot["map_fragment"] != "":
		Session.state["map_fragments"].append(loot["map_fragment"])
	if info["quest"] != "" and Session.state["quests"].has(info["quest"]):
		Session.state["quests"].erase(info["quest"])
		Session.state["quests_done"].append(info["quest"])
		Session.state["gold"] = int(Session.state["gold"]) + int(QuestData.JOBS[info["quest"]]["reward"])
		bus.quest_completed.emit(info["quest"])
		bus.toast.emit(Loc.t("port.quest_done") % int(QuestData.JOBS[info["quest"]]["reward"]))
	bus.prize_taken.emit(info)
	if info["tutorial"] == "lugger":
		bus.tutorial_event.emit("lugger_looted")
	targets.erase(ship)
	if _controllers.has(ship):
		(_controllers[ship] as BoardingController).queue_free()
		_controllers.erase(ship)
	prize_resolved.emit(info)


func _on_sunk(ship: Ship) -> void:
	if not is_instance_valid(ship) or not targets.has(ship):
		return
	var full: Dictionary = roll_loot(ship, Session.state)
	var loot: Dictionary = {"gold": floori(full["gold"] * Loot.SINK_CARGO_FRACTION), "cargo": {}, "supplies": {}, "map_fragment": ""}
	for g: String in full["cargo"]:
		loot["cargo"][g] = floorf(full["cargo"][g] * Loot.SINK_CARGO_FRACTION)
	apply_loot(loot, Session.state)
	Svc.node("EventBus").toast.emit(Loc.t("prize.barrels") % int(loot["gold"]))
	finish_prize(ship, loot, CaptureFate.Fate.STRIP_AND_SINK)


static func roll_loot(ship: Ship, state: Dictionary) -> Dictionary:
	var spec: Dictionary = ship.get_meta("loot", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 7919 + int(ship.get_meta("loot_seed", 7)) + int(state["day"])
	var gold_range: Array = spec.get("gold", [0, 0])
	return {
		"gold": rng.randi_range(int(gold_range[0]), int(gold_range[1])),
		"cargo": spec.get("cargo", {}).duplicate(),
		"supplies": spec.get("supplies", {}).duplicate(),
		"map_fragment": str(spec.get("map_fragment", "")),
	}


## Gold and goods go straight into the hold; goods that do not fit are left behind.
static func apply_loot(loot: Dictionary, state: Dictionary) -> void:
	state["gold"] = int(state["gold"]) + int(loot["gold"])
	for s: String in loot["supplies"]:
		state["supplies"][s] = float(state["supplies"][s]) + float(loot["supplies"][s])
	for g: String in loot["cargo"]:
		var room: float = PortService.cargo_free(state)
		var units: float = minf(float(loot["cargo"][g]), floorf(maxf(room, 0.0) / Goods.DATA[g]["weight"]))
		if units > 0.0:
			state["cargo"][g] = float(state["cargo"].get(g, 0.0)) + units
