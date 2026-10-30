class_name LagoonScreen
extends MenuScreen
## Ashore at the player's lagoon: claim the atoll, see what it earns and who lives there, go into build mode, run
## the harbour, raise the lagoon to its next rank, set sail. Coming ashore empties the chest and the larder.

var world: Node
var landing: Dictionary = {}


func _init() -> void:
	super()
	dim = 0.55


func _ready() -> void:
	get_tree().paused = true
	if Lagoon.claimed(Session.state):
		_come_ashore()
	super()


func _come_ashore() -> void:
	landing = Lagoon.land(Session.state, int(Session.state["day"]))
	if int(landing["gold"]) > 0:
		Sfx.play("coin")


func build() -> void:
	var s: Dictionary = Session.state
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	if not Lagoon.claimed(s):
		title.text = LagoonData.ISLAND
		_line(Loc.t("lagoon.unclaimed"))
		var b: Button = add_button("lagoon.claim", _claim)
		b.text = Loc.t("lagoon.claim") % LagoonData.CLAIM_COST
		b.disabled = int(s["gold"]) < LagoonData.CLAIM_COST
		add_button("port.set_sail", close)
		return
	var rank: int = Lagoon.rank_of(s)
	title.text = Loc.t("lagoon.rank_" + LagoonData.rank(rank)["id"])
	if not landing.is_empty():
		_line(Loc.t("lagoon.landing") % [int(landing["gold"]), int(landing["food"]), int(landing["morale"]), int(landing["healed"]), int(float(landing["hull"]) * 100.0)])
	var l: Dictionary = Lagoon.data(s)
	_line(Loc.t("lagoon.summary") % [int(l["pop"]), Lagoon.beds(s), int(Lagoon.income_daily(s)), int(float(l["chest"])), int(Lagoon.chest_cap(s))])
	_line(Loc.t("lagoon.summary2") % [int(Lagoon.morale_bonus(s)), int(Lagoon.defence(s)), int(Lagoon.raid_strength(s)), (s["fleet"] as Array).size(), Lagoon.berths(s)])
	_line(Loc.t("port.header") % [int(s["gold"]), PortService.cargo_used(s), PortService.cargo_capacity(s), PortService.food_days(s)])
	add_button("lagoon.build", _open_build_mode)
	add_button("lagoon.harbour", func() -> void: open_child(LagoonHarbourScreen.new()))
	var cost: int = Lagoon.next_rank_cost(s)
	if cost > 0:
		var up: Button = add_button("lagoon.rank_up", _rank_up)
		up.text = Loc.t("lagoon.rank_up") % [Loc.t("lagoon.rank_" + LagoonData.rank(rank + 1)["id"]), cost]
		up.disabled = cost > int(s["gold"])
	add_button("port.set_sail", close)


func _line(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func _claim() -> void:
	if Lagoon.claim(Session.state):
		Sfx.play("chest")
		_toast(Loc.t("lagoon.claimed"))
		_sync_scene()
	_rebuild()


func _rank_up() -> void:
	if Lagoon.rank_up(Session.state):
		Sfx.play("level_up")
		_toast(Loc.t("lagoon.ranked") % Loc.t("lagoon.rank_" + LagoonData.rank(Lagoon.rank_of(Session.state))["id"]))
		_sync_scene()
	_rebuild()


func _open_build_mode() -> void:
	var mode := LagoonBuildMode.new()
	mode.lagoon = _scene()
	visible = false
	get_tree().current_scene.add_child(mode)
	mode.finished.connect(func() -> void:
		visible = true
		_rebuild())


func _scene() -> LagoonScene:
	if world != null and world.get("streamer") != null:
		return world.streamer.lagoon
	return null


func _sync_scene() -> void:
	var sc: LagoonScene = _scene()
	if sc != null:
		sc.sync()


func _on_child_closed(screen: MenuScreen) -> void:
	super(screen)
	_sync_scene()


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)


func close() -> void:
	get_tree().paused = false
	super()
