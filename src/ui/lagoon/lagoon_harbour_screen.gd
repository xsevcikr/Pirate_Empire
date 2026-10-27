class_name LagoonHarbourScreen
extends PortScreen
## The lagoon's harbour: build and lengthen piers, see the fleet at its berths, take command of another ship, sell
## one, and lay down new ships at the lagoon's own shipyard.

const SHIP_NAMES: PackedStringArray = [
	"Salty Maiden", "Black Gull", "Rum Runner", "Sea Wolf", "Crimson Tide", "Kraken's Kiss", "Lucky Doubloon",
	"Iron Mermaid", "Storm Petrel", "Jolly Widow", "Night Heron", "Gilded Shark", "Bold Barnacle", "Silver Eel",
]


func _init() -> void:
	super()
	_title_key = "lagoon.harbour"


func build() -> void:
	add_header()
	begin_list(420.0)
	var s: Dictionary = state()
	var fleet: Array = s["fleet"]
	add_text(Loc.t("lagoon.berths") % [mini(fleet.size(), Lagoon.berths(s)), Lagoon.berths(s)])
	var piers: Array = Lagoon.data(s)["piers"]
	for i in piers.size():
		var cost: int = Lagoon.pier_upgrade_cost(s, i)
		var label: String = Loc.t("lagoon.pier") % [i + 1, int(piers[i]), int(LagoonData.PIER["berths"][int(piers[i]) - 1])]
		if cost < 0:
			add_item_row(label, [])
		else:
			add_item_row(label + "  (%d g)" % cost, [[Loc.t("lagoon.upgrade"), _upgrade_pier.bind(i) if cost <= int(s["gold"]) else Callable()]])
	if piers.size() < Lagoon.pier_slots(s):
		var pc: int = LagoonData.pier_cost(1)
		add_item_row(Loc.t("lagoon.new_pier") % pc, [[Loc.t("lagoon.build_it"), _build_pier if pc <= int(s["gold"]) else Callable()]])
	else:
		add_text(Loc.t("lagoon.piers_full"))
	add_text(Loc.t("lagoon.fleet"))
	if fleet.is_empty():
		add_text(Loc.t("lagoon.no_fleet"))
	var berths: int = Lagoon.berths(s)
	for i in fleet.size():
		var e: Dictionary = fleet[i]
		var where: String = Loc.t("lagoon.at_pier" if i < berths else "lagoon.at_anchor")
		var text: String = "%s \"%s\"  %s %d%%  %s" % [Loc.t("ship." + Lagoon.class_of(e)), str(e.get("name", "")), Loc.t("hud.hull"), int(float(e.get("hull", 1.0)) * 100.0), where]
		add_item_row(text, [[Loc.t("lagoon.command"), _command.bind(i)], [Loc.t("lagoon.sell") % Lagoon.sell_price(s, i), _sell.bind(i)]])
	add_text(Loc.t("lagoon.yard"))
	var classes: Array[String] = Lagoon.commission_classes(s)
	if classes.is_empty():
		add_text(Loc.t("lagoon.no_yard"))
	for class_id in classes:
		var st: ShipStats = PortService.ship_stats(class_id)
		var problem: String = Lagoon.commission_problem(s, class_id)
		var label2: String = "%s  %d g  %s %.1f kn  %s %d" % [Loc.t("ship." + class_id), st.price, Loc.t("port.speed"), st.max_speed_kn, Loc.t("lagoon.guns"), st.guns_per_side * 2]
		if problem != "":
			label2 += "  (" + Loc.t("lagoon.why_" + problem) + ")"
		add_item_row(label2, [[Loc.t("lagoon.lay_down"), _commission.bind(class_id) if problem == "" else Callable()]])
	add_button("menu.back", close)


func _upgrade_pier(i: int) -> void:
	if Lagoon.upgrade_pier(state(), i):
		Sfx.play("coin")
	_rebuild()


func _build_pier() -> void:
	if Lagoon.build_pier(state()):
		Sfx.play("coin")
	_rebuild()


func _command(i: int) -> void:
	if Lagoon.take_command(state(), i):
		toast("lagoon.took_command", [str(state()["ship_name"])])
	_rebuild()


func _sell(i: int) -> void:
	var g: int = Lagoon.sell_ship(state(), i)
	if g > 0:
		Sfx.play("coin")
		toast("lagoon.sold", [g])
	_rebuild()


func _commission(class_id: String) -> void:
	var s: Dictionary = state()
	var n: String = SHIP_NAMES[(s["fleet"] as Array).size() % SHIP_NAMES.size()]
	if Lagoon.commission(s, class_id, n):
		Sfx.play("level_up")
		toast("lagoon.launched", [n])
	_rebuild()
