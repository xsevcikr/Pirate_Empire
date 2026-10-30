class_name ShipyardScreen
extends PortScreen
## Buy a ship (with trade-in), repair, and install upgrades.


func _init() -> void:
	super()
	_title_key = "port.shipyard"


func build() -> void:
	add_header()
	begin_list()
	var s: Dictionary = state()
	var stats: ShipStats = PortService.ship_stats(s["ship_class"])
	add_text("%s: %s \"%s\"   %s %d%%" % [Loc.t("port.your_ship"), Loc.t("ship." + s["ship_class"]), s["ship_name"], Loc.t("hud.hull"), int(float(s["ship_hull"]) * 100.0)])
	var repair_cost: int = PortService.repair_cost(s)
	add_item_row(Loc.t("port.repair") + (" (%d g)" % repair_cost if repair_cost > 0 else ""), [[Loc.t("port.repair_do"), _repair if repair_cost > 0 else Callable()]])
	add_text(Loc.t("port.ships_for_sale"))
	for class_id in PortData.CLASS_ORDER:
		if class_id == s["ship_class"] or not PortData.can_sell_class(port_id, class_id):
			continue
		var ship_stats: ShipStats = PortService.ship_stats(class_id)
		var cost: int = PortService.ship_cost(s, class_id)
		var locked: bool = ship_stats.infamy_required > int(s["fame"])
		var label: String = "%s  %d g  (%s %d g)  %s %.1f kn  %s %d" % [Loc.t("ship." + class_id), ship_stats.price, Loc.t("port.after_trade_in"), cost, Loc.t("port.speed"), ship_stats.max_speed_kn, Loc.t("port.cargo"), int(ship_stats.cargo_t)]
		if locked:
			label += "  (" + Loc.t("port.fame_needed") % ship_stats.infamy_required + ")"
		add_item_row(label, [[Loc.t("port.buy_ship"), _buy_ship.bind(class_id) if not locked and cost <= int(s["gold"]) else Callable()]])
	add_text(Loc.t("port.upgrades"))
	var level: int = PortData.PORTS[port_id]["shipyard_level"]
	for line: String in Upgrades.BASE_COST.keys():
		var tier: int = int(s["upgrades"].get(line, 0))
		if tier >= Upgrades.TIERS:
			add_item_row("%s  %s %d/%d" % [Loc.t("upg." + line), Loc.t("port.tier"), tier, Upgrades.TIERS], [])
			continue
		var cost: int = Upgrades.cost(line, tier + 1, s["ship_class"])
		add_item_row("%s  %s %d/%d  (%d g)" % [Loc.t("upg." + line), Loc.t("port.tier"), tier, Upgrades.TIERS, cost],
			[[Loc.t("port.install"), _upgrade.bind(line, level) if cost <= int(s["gold"]) else Callable()]])
	add_button("menu.back", close)


func _repair() -> void:
	PortService.repair(state())
	_rebuild()


func _buy_ship(class_id: String) -> void:
	if PortService.buy_ship(state(), class_id, port_id):
		emit_bus("trade_made", ["buy_ship", class_id, 1.0, 0])
		toast("port.ship_bought", [Loc.t("ship." + class_id)])
	_rebuild()


func _upgrade(line: String, level: int) -> void:
	var s: Dictionary = state()
	var left: int = Upgrades.purchase(s["upgrades"], line, s["ship_class"], int(s["gold"]), level)
	if left >= 0:
		s["gold"] = left
		emit_bus("trade_made", ["upgrade", line, 1.0, 0])
	_rebuild()
