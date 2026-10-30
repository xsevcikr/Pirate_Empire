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
## Play boardings as a 3D deck fight. Off in headless runs, where the scripted tests use the crew-pool fight.
var use_deck_view: bool = DisplayServer.get_name() != "headless"


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
		bc.game_state = Session.state
		bc.use_deck = use_deck_view
		bc.deck_started.connect(_on_deck_started.bind(bc))
		add_child(bc)
		bc.finished.connect(_on_boarding_finished.bind(t))
		_controllers[t] = bc
	(_controllers[t] as BoardingController).process_grapple(Input.is_action_pressed("grapple"), delta)


## The nearest ship that would listen to a hail, within Parley.RANGE_M, or null.
func nearest_hailable() -> Ship:
	var best: Ship = null
	var best_d: float = Parley.RANGE_M
	for t in targets:
		if Parley.can_hail(t):
			var d: float = t.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = t
	return best


## "Strike your colours!": demand the surrender of the nearest ship. If she strikes, the prize screen opens as after
## a won boarding with no blood spilt. Returns {struck, chance}, or {} when nobody is in hailing range.
func hail() -> Dictionary:
	if player == null or _busy:
		return {}
	var t: Ship = nearest_hailable()
	var bus: Node = Svc.node("EventBus")
	if t == null:
		if bus != null:
			bus.toast.emit(Loc.t("parley.nobody"))
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Session.state.get("seed", 1)) * 389 + int(t.get_meta("loot_seed", 7)) + int(Session.state.get("day", 0))
	var res: Dictionary = Parley.hail(player, t, Session.state, rng)
	if bus != null:
		bus.toast.emit(Loc.t("parley.struck" if res["struck"] else "parley.refused") % int(float(res["chance"]) * 100.0))
	if res["struck"]:
		_on_boarding_finished(true, t)
	return res


func _on_deck_started(deck: DeckCombat, bc: BoardingController) -> void:
	var scene := DeckFightScene.new()
	bc.deck_driven = true
	get_tree().current_scene.add_child(scene)
	scene.start(deck)
	get_tree().paused = true
	scene.fight_over.connect(func(_r: Dictionary) -> void:
		get_tree().paused = false
		bc.complete_deck_fight())


func _on_boarding_finished(won: bool, ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	var losses: Dictionary = Session.reconcile_crew(player)
	_report_losses(losses)
	if not won:
		CrewLife.add_morale(Session.state, Morale.DELTA["defeat"])
		CrewPersona.on_event(Session.state, "defeat")
		Svc.node("EventBus").toast.emit(Loc.t("prize.repelled"))
		(_controllers[ship] as BoardingController).queue_free()
		_controllers.erase(ship)
		return
	_busy = true
	CrewPersona.on_event(Session.state, "boarding_win")
	var loot: Dictionary = roll_loot(ship, Session.state)
	var split: Dictionary = share_out(loot, Session.state)
	apply_loot(loot, Session.state)
	CrewLife.award_xp(Session.state, "boarding")
	var lines := PackedStringArray()
	lines.append(Loc.t("prize.gold") % int(loot["gold"]))
	if split["crew"] > 0.0:
		lines.append(Loc.t("prize.crew_share") % [int(split["crew"]), int(float(Session.state["captain_cut"]) * 100.0)])
	for g: String in loot["cargo"]:
		lines.append("%d × %s" % [int(loot["cargo"][g]), Loc.t("good." + g)])
	for s: String in loot["supplies"]:
		lines.append("%d × %s" % [int(loot["supplies"][s]), Loc.t("supply." + s)])
	if loot["map_fragment"] != "":
		lines.append(Loc.t("prize.map_fragment"))
	var screen := PrizeScreen.new()
	screen.summary_lines = lines
	screen.can_capture = FateEffects.prize_crew_available(Session.state) > 0
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
	var faction: String = str(ship.get_meta("rep_faction", "merchant"))
	var info: Dictionary = FateEffects.fate_info(Session.state, ship.stats.price, ship.crew.count, faction == "merchant")
	var effects: Dictionary = CaptureFate.resolve(fate as CaptureFate.Fate, info, rng)
	Session.state["rep"][faction] = clampf(float(Session.state["rep"][faction]) + float(effects["reputation"]), -100.0, 100.0)
	var applied: Dictionary = FateEffects.apply(Session.state, effects, ship.stats.class_id, str(ship.display_label))
	var bus: Node = Svc.node("EventBus")
	if applied["gold"] > 0:
		bus.toast.emit(Loc.t("prize.fate_gold") % applied["gold"])
	if applied["recruits"] > 0:
		bus.toast.emit(Loc.t("prize.fate_recruits") % applied["recruits"])
	if applied["ship_added"]:
		bus.toast.emit(Loc.t("prize.fate_ship"))
	if applied["rescue_fleet"]:
		bus.toast.emit(Loc.t("prize.fate_rescue"))
	finish_prize(ship, loot, fate)
	if fate != CaptureFate.Fate.RELEASE and fate != CaptureFate.Fate.RANSOM:
		ship.queue_free()
	_busy = false


## Quest, log and tutorial bookkeeping after a ship was looted. Also used by the scripted test.
func finish_prize(ship: Ship, loot: Dictionary, fate: int) -> void:
	var bus: Node = Svc.node("EventBus")
	CrewLife.add_morale(Session.state, Morale.DELTA["victory"])
	CrewPersona.on_event(Session.state, "victory")
	CrewLife.award_xp(Session.state, "battle")
	if ship.has_meta("convoy"):
		TradeNetwork.lose_ships(Session.state, int(ship.get_meta("convoy")), 1)
		ship.remove_meta("convoy")
	var info: Dictionary = {"quest": str(ship.get_meta("quest", "")), "tutorial": str(ship.get_meta("tutorial", "")), "loot": loot, "fate": fate, "rival": str(ship.get_meta("rival", "")), "class_id": ship.stats.class_id,
		"crew": str(ship.get_meta("crew", "")), "crew_role": str(ship.get_meta("crew_role", "")), "crew_tag": str(ship.get_meta("crew_tag", "")), "ship": ship}
	if loot["map_fragment"] != "" and MapFragments.add(Session.state, loot["map_fragment"]):
		bus.toast.emit(Loc.t("tour.fragment_found"))
	if info["quest"] != "" and Session.state["quests"].has(info["quest"]):
		Session.state["quests"].erase(info["quest"])
		Session.state["quests_done"].append(info["quest"])
		Session.state["gold"] = int(Session.state["gold"]) + int(QuestData.JOBS[info["quest"]]["reward"])
		bus.quest_completed.emit(info["quest"])
		bus.toast.emit(Loc.t("port.quest_done") % int(QuestData.JOBS[info["quest"]]["reward"]))
	Session.state["prizes_taken"] = int(Session.state.get("prizes_taken", 0)) + 1
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
	share_out(loot, Session.state)
	for g: String in full["cargo"]:
		loot["cargo"][g] = floorf(full["cargo"][g] * Loot.SINK_CARGO_FRACTION)
	apply_loot(loot, Session.state)
	Svc.node("EventBus").toast.emit(Loc.t("prize.barrels") % int(loot["gold"]))
	finish_prize(ship, loot, CaptureFate.Fate.STRIP_AND_SINK)


## Splits the gold between the captain's cut and the crew's shares (spec section 4). Changes loot["gold"]
## to the captain's part and moves the crew's morale by the cut and the shares paid.
static func share_out(loot: Dictionary, state: Dictionary) -> Dictionary:
	var split: Dictionary = Morale.loot_split(float(loot["gold"]), float(state["captain_cut"]), int(state["crew"]))
	loot["gold"] = floori(split["captain"])
	CrewLife.add_morale(state, split["morale"])
	CrewPersona.on_loot(state, split["crew"])
	return split


func _report_losses(losses: Dictionary) -> void:
	if int(losses["dead"]) > 0 or int(losses["wounded"]) > 0:
		Svc.node("EventBus").toast.emit(Loc.t("crew.losses") % [int(losses["dead"]), int(losses["wounded"])])


static func roll_loot(ship: Ship, state: Dictionary) -> Dictionary:
	var spec: Dictionary = ship.get_meta("loot", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 7919 + int(ship.get_meta("loot_seed", 7)) + int(state["day"])
	var gold_range: Array = spec.get("gold", [0, 0])
	var fragment: String = str(spec.get("map_fragment", ""))
	if fragment == "":
		fragment = MapFragments.roll_drop(state, str(ship.get_meta("loot_source", ship.get_meta("rep_faction", "merchant"))), rng)
	return {
		"gold": rng.randi_range(int(gold_range[0]), int(gold_range[1])),
		"cargo": spec.get("cargo", {}).duplicate(),
		"supplies": spec.get("supplies", {}).duplicate(),
		"map_fragment": fragment,
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
