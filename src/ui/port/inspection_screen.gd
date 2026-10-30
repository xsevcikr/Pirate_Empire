class_name InspectionScreen
extends MenuScreen
## A harbour patrol finds contraband in the hold: pay the fine, bribe the officer, or fight.

signal resolved(choice: int, outcome: Dictionary)

var port_id: String = PortData.START_PORT
var rng := RandomNumberGenerator.new()
var leadership_rank: int = 0
var _outcome: Dictionary = {}
var _done: bool = false


func _init() -> void:
	super()
	dim = 0.7
	_title_key = "inspect.title"


func build() -> void:
	var s: Dictionary = Session.state
	var value: float = Smuggling.illegal_value(s, port_id)
	var l := Label.new()
	l.text = Loc.t("inspect.found") % [PortData.PORTS[port_id]["name"], int(value)]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	if _done:
		var r := Label.new()
		r.text = Loc.t("inspect.result_" + _result_key())
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(r)
		add_button("menu.continue", func() -> void: resolved.emit(int(_outcome["choice"]), _outcome); queue_free())
		return
	var fine: int = ceili(value * TradeData.FINE_MULT)
	var bribe: int = ceili(value * TradeData.BRIBE_FRACTION)
	var pay := add_button("inspect.pay", _choose.bind(Smuggling.Choice.PAY_FINE))
	pay.text = "%s (%d g)" % [Loc.t("inspect.pay"), fine]
	var b := add_button("inspect.bribe", _choose.bind(Smuggling.Choice.BRIBE))
	b.text = "%s (%d g, %d%%)" % [Loc.t("inspect.bribe"), bribe, int(Smuggling.bribe_chance(leadership_rank) * 100.0)]
	b.disabled = bribe > int(s["gold"])
	add_button("inspect.fight", _choose.bind(Smuggling.Choice.FIGHT))


func _choose(choice: int) -> void:
	_outcome = Smuggling.resolve(Session.state, port_id, choice as Smuggling.Choice, rng, leadership_rank)
	_outcome["choice"] = choice
	_done = true
	_rebuild()


func _result_key() -> String:
	if bool(_outcome["hostile"]):
		return "fight"
	return "kept" if bool(_outcome["kept_cargo"]) else "fined"
