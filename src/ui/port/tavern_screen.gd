class_name TavernScreen
extends PortScreen
## Hire crew, listen to Old Finn and the rumours.

var _shanty: int = -1


func _init() -> void:
	super()
	_title_key = "port.tavern"


func _ready() -> void:
	super()
	Sfx.music(AudioData.TAVERN_TRACK)
	tree_exiting.connect(func() -> void: Sfx.music(""))


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
	add_text(Loc.t("port.specialists"))
	var offers: Array[String] = PortService.tavern_offers(s, port_id)
	if offers.is_empty():
		add_text("  " + Loc.t("port.no_specialists"))
	for t in offers:
		var spec: Dictionary = CrewTypes.TYPES[t]
		var can: bool = room > 0 and int(spec["hire"]) <= int(s["gold"])
		add_item_row("%s  %d g  (%s %d g/%s)" % [Loc.t("crew." + t), int(spec["hire"]), Loc.t("port.wage"), int(spec["wage"]), Loc.t("port.day")],
			[[Loc.t("port.hire"), _hire.bind(t) if can else Callable()]])
	add_text(Loc.t("port.roster"))
	for m: Dictionary in s["roster"]:
		add_text("  %s  (%s, %s %d, %d XP)" % [m["name"], Loc.t("crew." + m["type"]), Loc.t("crew.level"), int(m["level"]), int(m["xp"])])
	_map_seller(s)
	add_text(Loc.t("port.rumours"))
	add_text("  " + Loc.t("rumour.%d" % (int(s["day"]) % 3)))
	if TutorialData.index_of(s["tutorial"]) <= TutorialData.index_of("hunt_lugger"):
		add_item_row(Loc.t("port.old_finn"), [[Loc.t("port.talk"), _talk_finn]])
	if float(s["morale"]) >= AudioData.SHANTY_MIN_MORALE:
		add_button("tavern.shanty", _sing)
	add_button("games.title", func() -> void:
		var menu := MiniGameMenu.new()
		menu.port_id = port_id
		open_child(menu))
	add_button("menu.back", close)


## A sailor in the corner sells one treasure map every few days; the maps already held are listed under it.
func _map_seller(s: Dictionary) -> void:
	add_text(Loc.t("buried.seller"))
	var tier: String = BuriedTreasure.offer_tier(s, port_id)
	if tier == "":
		add_text("  " + Loc.t("buried.sold_out"))
	else:
		var price: int = BuriedTreasure.offer_price(s, port_id)
		var ok: bool = BuriedTreasure.can_hold_more(s) and int(s["gold"]) >= price
		add_item_row("  %s  %d g" % [Loc.t("buried.offer." + tier), price], [[Loc.t("buried.buy"), _buy_map if ok else Callable()]])
	add_text("  " + Loc.t("buried.held") % [BuriedTreasure.maps(s).size(), BuriedTreasure.MAX_HELD])
	for m: Dictionary in BuriedTreasure.maps(s):
		add_text("    " + BuriedTreasure.clue(m))


func _buy_map() -> void:
	var m: Dictionary = BuriedTreasure.buy_offer(state(), port_id)
	if not m.is_empty():
		Sfx.play("coin")
		toast("buried.bought", [str(m["island"])])
	_rebuild()


## The crew sings, and the player picks the shanty: each press moves on to the next one.
func _sing() -> void:
	_shanty = (_shanty + 1) % AudioData.SHANTIES.size()
	Sfx.music("shanty_" + AudioData.SHANTIES[_shanty])
	toast("tavern.sung_" + AudioData.SHANTIES[_shanty])


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
