class_name EasyPlayDirector
extends Node
## Runs the kid-friendly layer at sea: the parrot that flies with the ship, spots hidden treasure and gives hints;
## the floating chests it finds; the collection book (shells, flags, ship cards) and the goals list with its stars.
## The rules live in EasyPlay, HiddenLoot and ParrotHints; this node only watches the ship and the event bus.

const TICK_S: float = 0.5
const GOAL_TICK_S: float = 2.0
const FORGET_M: float = HiddenLoot.SPOT_M * 1.4  ## a marker this far behind is taken off the sea again

signal goals_changed

var state: Dictionary
var ship: Ship
var ocean: WaveModel
var parrot: ParrotModel
var markers: Dictionary = {}  ## spot id -> LootMarker
var _bus: Node
var _all_spots: Array[Dictionary] = []
var _tick: float = 0.0
var _goal_tick: float = 0.0
var _hint_t: float = 0.0
var _announced: Dictionary = {}  ## spot ids the parrot already squawked about this voyage


func _ready() -> void:
	_bus = Svc.node("EventBus")
	if state.is_empty() and Session.has_state():
		state = Session.state
	EasyPlay.store(state)
	_all_spots = HiddenLoot.spots()
	if ship != null:
		EasyPlay.add_ship_card(state, ship.stats.class_id)
		parrot = ParrotModel.new()
		parrot.name = "Parrot"
		parrot.ship = ship
		parrot.ocean = ocean
		get_parent().add_child.call_deferred(parrot)
		parrot.ready.connect(func() -> void:
			parrot.global_position = parrot.home_point()
			parrot.set_colours(EasyPlay.parrot_colour(state)), CONNECT_ONE_SHOT)
	if _bus != null:
		_bus.ship_sunk.connect(_on_ship_sunk)
		_bus.prize_taken.connect(on_prize)
		_bus.port_docked.connect(on_docked)
		_bus.trade_made.connect(_on_trade)


func _process(delta: float) -> void:
	if state.is_empty():
		return
	_goal_tick += delta
	if _goal_tick >= GOAL_TICK_S:
		_goal_tick = 0.0
		check_goals()
	if ship == null or not is_instance_valid(ship):
		return
	_tick += delta
	_hint_t += delta
	if _tick >= TICK_S:
		_tick = 0.0
		scan(Vector2(ship.global_position.x, ship.global_position.z))
	if _hint_t >= ParrotHints.HINT_EVERY_S and str(state.get("tutorial", "done")) == "done" and _at_sea():
		_hint_t = 0.0
		hint()


func _at_sea() -> bool:
	var host: Node = get_parent()
	return host != null and host.get_node_or_null("PortLayer") == null and host.get_node_or_null("MapLayer") == null and not get_tree().paused


## Looks for hidden treasure round `pos`: marks the spots the parrot spots, collects one the ship reached, and
## sends the parrot to circle the nearest. Public so tests can drive it.
func scan(pos: Vector2) -> Dictionary:
	var got: Dictionary = {}
	var near: Array[Dictionary] = HiddenLoot.near(state, pos, HiddenLoot.SPOT_M, _all_spots)
	for s in near:
		var id: String = str(s["id"])
		if not markers.has(id):
			_mark(s)
		if not _announced.has(id):
			_announced[id] = true
			_say(Loc.t("parrot.spotted") % [Loc.t(ParrotHints.NAME_KEY), Loc.t("compass." + HiddenLoot.compass(pos, s["pos"]))])
			if parrot != null:
				parrot.squawk()
		if (s["pos"] as Vector2).distance_to(pos) <= HiddenLoot.PICKUP_M:
			got = collect(id)
	for id: String in markers.keys():
		var m: LootMarker = markers[id]
		if not is_instance_valid(m) or m.spot.distance_to(pos) > FORGET_M or not HiddenLoot.is_full(state, id):
			if is_instance_valid(m):
				m.queue_free()
			markers.erase(id)
	if parrot != null:
		var left: Array[Dictionary] = HiddenLoot.near(state, pos, HiddenLoot.SPOT_M, _all_spots)
		parrot.target_spot = left[0]["pos"] if not left.is_empty() else null
	return got


func _mark(s: Dictionary) -> void:
	var m := LootMarker.new()
	m.spot_id = str(s["id"])
	m.spot = s["pos"]
	m.ocean = ocean
	m.name = "Loot_" + str(s["id"]).replace(":", "_").replace(" ", "_")
	markers[m.spot_id] = m
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(m)


## Takes a spot's treasure. Returns what was found.
func collect(spot_id: String) -> Dictionary:
	var got: Dictionary = HiddenLoot.take(state, spot_id)
	if got.is_empty():
		return got
	var item: String = str(got["item"])
	Sfx.play("chest")
	Sfx.play("coin")
	if item == "":
		_say(Loc.t("parrot.found_gold") % [int(got["gold"])])
	else:
		_say(Loc.t("parrot.found_item") % [int(got["gold"]), CollectionData.display_name(item)] + ("  " + Loc.t("coll.new_page") if bool(got["new"]) else ""))
	if markers.has(spot_id):
		var m: LootMarker = markers[spot_id]
		if is_instance_valid(m):
			m.queue_free()
		markers.erase(spot_id)
	if parrot != null:
		parrot.squawk()
	check_goals()
	return got


## The parrot's hint, shown as a toast.
func hint() -> String:
	var ctx: Dictionary = {}
	if ship != null and is_instance_valid(ship):
		ctx = {"hull": ship.damage.hull_fraction(), "pos": Vector2(ship.global_position.x, ship.global_position.z)}
	var line: String = ParrotHints.say(state, ctx)
	_toast(line)
	if parrot != null:
		parrot.squawk()
	_hint_t = 0.0
	return line


func check_goals() -> Array[Dictionary]:
	var before: Dictionary = EasyPlay.parrot_colour(state)
	var fresh: Array[Dictionary] = EasyPlay.check(state)
	for g in fresh:
		_toast(Loc.t("goal.done") % [EasyPlay.goal_text(str(g["id"])), int(g["stars"]), int(g["stars"]) * GoalData.GOLD_PER_STAR])
		Sfx.play("achievement")
		CaptainLog.add(state, "achievement", "goal_done", EasyPlay.goal_text(str(g["id"])))
	if not fresh.is_empty():
		var after: Dictionary = EasyPlay.parrot_colour(state)
		if after["id"] != before["id"]:
			_toast(Loc.t("parrot.new_colour") % [Loc.t(ParrotHints.NAME_KEY), Loc.t("parrot.colour_" + str(after["id"]))])
		if parrot != null:
			parrot.set_colours(after)
			parrot.squawk()
		goals_changed.emit()
	return fresh


# ---- events --------------------------------------------------------------------------------------------------

func _on_ship_sunk(pos: Vector2, class_id: String) -> void:
	if ship != null and is_instance_valid(ship) and Vector2(ship.global_position.x, ship.global_position.z).distance_to(pos) < 4.0:
		return  # that is us going down
	var faction: String = ""
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("ships"):
			var s: Ship = n as Ship
			if s != null and s != ship and Vector2(s.global_position.x, s.global_position.z).distance_to(pos) < 30.0:
				faction = s.faction
				break
	on_beaten(class_id, faction)


func on_prize(info: Dictionary) -> void:
	var s: Variant = info.get("ship")
	var faction: String = (s as Ship).faction if s is Ship and is_instance_valid(s) else ""
	on_beaten(str(info.get("class_id", "")), faction)


## A ship sunk or taken: her class's card and her faction's flag for the book.
func on_beaten(class_id: String, faction: String) -> void:
	if EasyPlay.add_ship_card(state, class_id):
		_toast(Loc.t("coll.got_card") % CollectionData.display_name(CollectionData.ship_card(class_id)) + (" " + Loc.t("coll.rare") if PortData.is_giant(class_id) else ""))
	var flag: String = EasyPlay.add_faction_flag(state, faction)
	if flag != "":
		_toast(Loc.t("coll.got_flag") % CollectionData.display_name(flag))
	check_goals()


func on_docked(port_id: String) -> void:
	EasyPlay.visit_port(state, port_id)
	check_goals()


func _on_trade(kind: String, _id: String, _units: float, _gold: int) -> void:
	if kind == "buy_ship":
		EasyPlay.add_ship_card(state, str(state.get("ship_class", "")))
	check_goals()


func _say(line: String) -> void:
	_toast(line)


func _toast(text: String) -> void:
	if _bus != null:
		_bus.toast.emit(text)
