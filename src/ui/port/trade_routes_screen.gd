class_name TradeRoutesScreen
extends PortScreen
## The routes ledger: the best gaps between the prices in the captain's book, from this port and anywhere he has
## been, with a button to set course and one to put an idle fleet ship on the route. Below it the fleet ships
## already trading, what they have earned, and a button to call each one home.


func _init() -> void:
	super()
	_title_key = "troute.title"
	dim = 0.55


func build() -> void:
	var s: Dictionary = state()
	TradeRoutes.record(s, port_id)  # prices here are always today's
	add_header()
	begin_list(440.0)
	var hold: float = PortService.cargo_capacity(s)
	var speed: float = Session.player_stats().max_speed_kn * 0.7
	add_text(Loc.t("troute.book") % TradeRoutes.known_ports(s).size())
	add_text(Loc.t("troute.from_here"))
	_routes(TradeRoutes.best(s, hold, speed, port_id, 5))
	add_text(Loc.t("troute.anywhere"))
	_routes(TradeRoutes.best(s, hold, speed, "", TradeRoutes.TOP))
	add_text(Loc.t("troute.fleet"))
	var f: Array = TradeRoutes.fleet(s)
	if f.is_empty():
		add_text("  " + Loc.t("troute.no_fleet"))
	for i in f.size():
		var e: Dictionary = f[i]
		if not TradeRoutes.on_route(e):
			add_text("  " + Loc.t("troute.idle") % str(e.get("name", "")))
			continue
		var r: Dictionary = e["route"]
		add_item_row("  " + Loc.t("troute.running") % [str(e.get("name", "")), Loc.t("good." + str(r["good"])), PortData.PORTS[r["from"]]["name"], PortData.PORTS[r["to"]]["name"],
			int(r["trips"]), int(r["earned"]), int(TradeRoutes.predicted(s, e))], [[Loc.t("troute.recall"), _recall.bind(i)]])
	add_button("menu.back", close)


func _routes(list: Array[Dictionary]) -> void:
	if list.is_empty():
		add_text("  " + Loc.t("troute.none"))
		return
	var idle: bool = TradeRoutes.idle_ship(state()) >= 0
	for rt: Dictionary in list:
		var text: String = Loc.t("troute.row") % [Loc.t("good." + str(rt["good"])), PortData.PORTS[rt["from"]]["name"], float(rt["buy"]),
			PortData.PORTS[rt["to"]]["name"], float(rt["sell"]), float(rt["margin"]), int(rt["profit"]), Chart.eta_text(float(rt["hours"]))]
		if int(rt["age"]) > 0:
			text += "  " + Loc.t("troute.age") % int(rt["age"])
		add_item_row(text, [[Loc.t("troute.course"), _course.bind(rt)], [Loc.t("troute.assign"), _assign.bind(rt) if idle else Callable()]])


## Sets the chart course to where the route goes next: the selling port when the goods can be bought here.
func _course(rt: Dictionary) -> void:
	var dest: String = rt["to"] if rt["from"] == port_id else rt["from"]
	var p: Vector2 = PortData.PORTS[dest]["dock"]
	state()["course"] = [p.x, p.y]
	toast("troute.course_set", [PortData.PORTS[dest]["name"]])


func _assign(rt: Dictionary) -> void:
	var i: int = TradeRoutes.idle_ship(state())
	var clock: Node = Svc.node("GameClock")
	var now_h: float = float(clock.day) * 24.0 + float(clock.hour) if clock != null else float(state()["day"]) * 24.0
	if TradeRoutes.assign(state(), i, rt["from"], rt["to"], rt["good"], now_h):
		Sfx.play("ui_confirm")
		toast("troute.assigned", [str(state()["fleet"][i].get("name", ""))])
	_rebuild()


func _recall(i: int) -> void:
	if TradeRoutes.recall(state(), i):
		toast("troute.recalled")
	_rebuild()
