class_name MarketScreen
extends PortScreen
## Trade goods and buy supplies. Prices come from Market; arrows show whether a price sits above or below normal.

const TREND_ARROW: Dictionary = {1: "▲", 0: "▬", -1: "▼"}


func _init() -> void:
	super()
	_title_key = "port.market"


func build() -> void:
	add_header()
	begin_list()
	var s: Dictionary = state()
	var m: Market = market()
	var st: Dictionary = Finance.standing(s, port_id)
	add_text(Loc.t("trade.standing") % [Loc.t("faction." + st["faction"]), Loc.t("rep.tier_" + st["tier"]), int(st["price_mod"] * 100.0)])
	add_text(Loc.t("port.supplies"))
	for id: String in PortData.SUPPLIES:
		var price: float = PortService.supply_price(s, m, id)
		var have: float = float(s["supplies"][id])
		var arrow: String = ""
		if PortData.SUPPLIES[id].has("good"):
			arrow = " " + TREND_ARROW[m.trend(PortData.SUPPLIES[id]["good"])]
		add_item_row("%s  %.1f g%s   (%s %d)" % [Loc.t("supply." + id), price, arrow, Loc.t("port.owned"), int(have)], [
			[Loc.t("port.buy_1"), _buy_supply.bind(id, 1)], [Loc.t("port.buy_10"), _buy_supply.bind(id, 10)]])
	add_text(Loc.t("port.goods"))
	for g: String in Goods.ids():
		var owned: int = int(s["cargo"].get(g, 0.0))
		var buy_p: float = PortService.good_buy_price(s, m, g)
		var sell_p: float = PortService.good_sell_price(m, g)
		add_item_row("%s  %s %.1f / %s %.1f %s   (%s %d)" % [Loc.t("good." + g), Loc.t("port.buy_short"), buy_p, Loc.t("port.sell_short"), sell_p, TREND_ARROW[m.trend(g)], Loc.t("port.owned"), owned], [
			[Loc.t("port.buy_1"), _buy_good.bind(g, 1)], [Loc.t("port.sell_1"), _sell_good.bind(g, 1)] if owned > 0 else [Loc.t("port.sell_1"), Callable()],
			[Loc.t("port.sell_all"), _sell_good.bind(g, owned)] if owned > 0 else [Loc.t("port.sell_all"), Callable()]])
	var mult: float = Smuggling.illegal_buy_mult(port_id)
	if mult > 0.0:
		add_text(Loc.t("trade.fence") % int(mult * 100.0))
		for g in Smuggling.illegal_goods(s["cargo"]):
			var have: int = int(s["cargo"][g])
			add_item_row("%s  %.1f g  (%s %d)" % [Loc.t("good." + g), Goods.base_price(g) * mult, Loc.t("port.owned"), have],
				[[Loc.t("port.sell_1"), _fence.bind(g, 1)], [Loc.t("port.sell_all"), _fence.bind(g, have)]])
	add_button("menu.back", close)


func _fence(g: String, n: int) -> void:
	var gain: int = Smuggling.sell_illegal(state(), port_id, g, n)
	if gain > 0:
		emit_bus("trade_made", ["sell", g, float(n), gain])
		toast("port.sold", [n, Loc.t("good." + g), gain])
	_rebuild()


func _buy_supply(id: String, n: int) -> void:
	var m: Market = market()
	if PortService.buy_supply(state(), m, id, n):
		save_market(m)
		emit_bus("trade_made", ["buy_supply", id, float(n), 0])
	else:
		toast("port.cannot_buy")
	_rebuild()


func _buy_good(g: String, n: int) -> void:
	var m: Market = market()
	if PortService.buy_good(state(), m, g, n):
		save_market(m)
		emit_bus("trade_made", ["buy", g, float(n), 0])
	else:
		toast("port.cannot_buy")
	_rebuild()


func _sell_good(g: String, n: int) -> void:
	var m: Market = market()
	var gain: int = PortService.sell_good(state(), m, g, n)
	if gain > 0:
		save_market(m)
		emit_bus("trade_made", ["sell", g, float(n), gain])
		toast("port.sold", [n, Loc.t("good." + g), gain])
	_rebuild()
