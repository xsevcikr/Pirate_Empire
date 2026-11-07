class_name SupplyScreen
extends PortScreen
## The chandler: how many days the food, water and rum last, one button to restock for a voyage, and single supplies.


func _init() -> void:
	super()
	_title_key = "supply_shop.title"


func build() -> void:
	add_header()
	begin_list()
	var s: Dictionary = state()
	var m: Market = market()
	add_text(Loc.t("crew.supplies_line") % [CrewLife.days_left(s, "food"), CrewLife.days_left(s, "water"), CrewLife.days_left(s, "rum")])
	for days in SupplyStore.RESTOCK_DAYS:
		var cost: int = SupplyStore.restock_cost(s, m, days)
		add_item_row(Loc.t("supply_shop.restock") % [days, cost], [[Loc.t("supply_shop.buy"), _restock.bind(days) if cost > 0 else Callable()]])
	add_text(Loc.t("port.supplies"))
	for id: String in PortData.SUPPLIES:
		var have: float = float(s["supplies"][id])
		add_item_row("%s  %.1f g   (%s %d)" % [Loc.t("supply." + id), PortService.supply_price(s, m, id), Loc.t("port.owned"), int(have)], [
			[Loc.t("port.buy_1"), _buy.bind(id, 1)], [Loc.t("port.buy_10"), _buy.bind(id, 10)]])
	add_button("menu.back", close)


func _restock(days: int) -> void:
	var m: Market = market()
	var got: Dictionary = SupplyStore.restock(state(), m, days)
	save_market(m)
	var total: int = int(got["food"]) + int(got["water"]) + int(got["rum"])
	if total > 0:
		for id: String in got:
			if int(got[id]) > 0:
				emit_bus("trade_made", ["buy_supply", id, float(got[id]), 0])
		toast("supply_shop.bought", [int(got["food"]), int(got["water"]), int(got["rum"])])
	else:
		toast("port.cannot_buy")
	_rebuild()


func _buy(id: String, n: int) -> void:
	var m: Market = market()
	if PortService.buy_supply(state(), m, id, n):
		save_market(m)
		emit_bus("trade_made", ["buy_supply", id, float(n), 0])
	else:
		toast("port.cannot_buy")
	_rebuild()
