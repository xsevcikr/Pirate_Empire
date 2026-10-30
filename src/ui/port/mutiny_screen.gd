class_name MutinyScreen
extends MenuScreen
## The crew has had enough: pay them off, duel the ringleader, or maroon the mutineers.

signal resolved

var result_key: String = ""


func _init() -> void:
	super()
	_title_key = "mutiny.title"
	dim = 0.7


func _ready() -> void:
	get_tree().paused = true
	super()


func build() -> void:
	var l := Label.new()
	l.text = Loc.t("mutiny.text")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	var leader: String = CrewPersona.ringleader(Session.state)
	if leader != "":
		var r := Label.new()
		r.text = Loc.t("persona.ringleader") % [leader, CrewPersona.count_at_least(Session.state, CrewPersona.BANDS["loyal"])]
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(r)
	var cost: int = Mutiny.pay_off_cost(Session.state)
	var pay: Button = add_button("mutiny.pay", _choose.bind(Mutiny.Option.PAY_OFF))
	pay.text = "%s (%d g)" % [Loc.t("mutiny.pay"), cost]
	pay.disabled = cost > int(Session.state["gold"])
	var duel: Button = add_button("mutiny.duel", _choose.bind(Mutiny.Option.DUEL))
	duel.text = "%s (%d%%)" % [Loc.t("mutiny.duel"), int(Mutiny.duel_win_chance(Session.state) * 100.0)]
	add_button("mutiny.maroon", _choose.bind(Mutiny.Option.MAROON))


func _choose(option: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Session.state["seed"]) * 31 + int(Session.state["day"])
	var res: Dictionary = Mutiny.resolve(option as Mutiny.Option, Session.state, rng)
	result_key = res["text_key"]
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(Loc.t(result_key))
	if not res["ok"] and option == Mutiny.Option.PAY_OFF:
		return  # could not pay: pick again
	get_tree().paused = false
	resolved.emit()
	queue_free()


func close() -> void:
	pass  # a mutiny has to be dealt with
