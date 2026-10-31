class_name Tutorial
extends Node
## Walks the new player through the first ten minutes. Watches the ship and the event bus, advances the
## step stored in the save state, and shows the prompt for the current step.

signal prompt_changed(text: String)

const FAR_FROM_DOCK_M: float = 140.0

var ship: Ship
var _step_time: float = 0.0
var _seen_under_way: bool = false


func _ready() -> void:
	var bus: Node = Svc.node("EventBus")
	bus.tutorial_event.connect(feed)
	bus.port_docked.connect(func(_id: String) -> void: feed("docked"))
	bus.trade_made.connect(_on_trade)
	bus.crew_hired.connect(func(_t: String) -> void:
		if int(Session.state["crew"]) >= TutorialData.HIRES_NEEDED:
			feed("hired_crew"))
	bus.quest_taken.connect(func(_id: String) -> void: feed("quest_taken"))
	_announce()


func step() -> String:
	return Session.state.get("tutorial", "done")


func _on_trade(kind: String, id: String, _units: float, _gold: int) -> void:
	if kind == "sell" and id == "fish":
		feed("sold_fish")
	elif kind == "buy_supply" and id == "food":
		feed("bought_food")


func feed(event_name: String) -> void:
	if Session.state.is_empty():
		return
	var before: String = step()
	var after: String = TutorialData.advance(before, event_name)
	if after == before:
		return
	Session.state["tutorial"] = after
	_step_time = 0.0
	Svc.node("EventBus").tutorial_step_changed.emit(after)
	_announce()


func _announce() -> void:
	var key: String = TutorialData.prompt_key(step()) if not Session.state.is_empty() else ""
	prompt_changed.emit(Loc.t(key) if key != "" else "")


func _physics_process(delta: float) -> void:
	if ship == null or Session.state.is_empty():
		return
	_step_time += delta
	match step():
		"leave_dock":
			var dock := Vector3(PortData.PORTS[PortData.START_PORT]["dock"].x, 0.0, PortData.PORTS[PortData.START_PORT]["dock"].y)
			if ship.sail_level >= 1 and ship.global_position.distance_to(dock) > FAR_FROM_DOCK_M:
				feed("left_dock")
		"into_wind":
			if ship.sail_level >= 1 and absf(ship.rudder_input) > 0.5 and _step_time > 2.0:  # steered: no wind to face any more
				feed("faced_wind")
			elif _step_time > 90.0:
				feed("faced_wind")  # never block on this one
		"compass":
			if _step_time >= float(TutorialData.STEPS[TutorialData.index_of("compass")]["seconds"]):
				feed("timer")
