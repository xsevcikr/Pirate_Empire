class_name TavernScreen
extends PortScreen
## Hire crew, listen to Old Finn and the rumours.


func _init() -> void:
	super()
	_title_key = "port.tavern"


func build() -> void:
	add_header()
	begin_list()
	var s: Dictionary = state()
	var stats: ShipStats = PortService.ship_stats(s["ship_class"])
	add_text("%s %d / %d" % [Loc.t("port.crew"), int(s["crew"]), stats.crew_max])
	var level: int = PortData.PORTS[port_id]["tavern_level"]
	var room: int = PortService.crew_room(s)
	for tier: String in ["green", "seasoned"]:
		var cost: int = CrewManager.HIRE_COST[tier]
		var ok: bool = room > 0 and cost <= int(s["gold"]) and (tier == "green" or level >= 2)
		add_item_row("%s  %d g  (%s %d g/%s)" % [Loc.t("crew." + tier), cost, Loc.t("port.wage"), CrewManager.WAGE_PER_DAY * (1 if tier == "green" else 2), Loc.t("port.day")],
			[[Loc.t("port.hire"), _hire.bind(tier) if ok else Callable()]])
	add_text(Loc.t("port.roster"))
	for m: Dictionary in s["roster"]:
		add_text("  %s  (%s)" % [m["name"], Loc.t("crew." + m["type"])])
	add_text(Loc.t("port.rumours"))
	add_text("  " + Loc.t("rumour.%d" % (int(s["day"]) % 3)))
	if TutorialData.index_of(s["tutorial"]) <= TutorialData.index_of("hunt_lugger"):
		add_item_row(Loc.t("port.old_finn"), [[Loc.t("port.talk"), _talk_finn]])
	add_button("menu.back", close)


func _hire(tier: String) -> void:
	if PortService.hire(state(), tier, port_id):
		emit_bus("crew_hired", [tier])
		toast("port.hired")
	_rebuild()


func _talk_finn() -> void:
	toast("port.finn_says")
	if state()["tutorial"] == "find_finn":
		emit_bus("tutorial_event", ["finn_talked"])
	_rebuild()
