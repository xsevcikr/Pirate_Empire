class_name WantedBoardScreen
extends PortScreen
## The harbour's wanted board: the captain's infamy, the price each flag has put on the ship (pardoned by the
## governor of a lawful port, bribed down at a pirate haven), the navy's rewards for pirates taken, and the posters
## of the rival crews.


func _init() -> void:
	super()
	_title_key = "port.wanted_board"


func build() -> void:
	add_header()
	begin_list(420.0)
	var s: Dictionary = state()
	var fame: int = int(s["fame"])
	var rank: String = Bounty.rank_id(fame)
	var next: int = Bounty.to_next_rank(fame)
	add_text(Loc.t("bounty.your_name") % [Loc.t("rank." + rank), fame] + ("" if next == 0 else "  " + Loc.t("bounty.next_rank") % next))
	add_text(Loc.t("rank.desc_" + rank))
	add_text(Loc.t("bounty.on_your_head"))
	var any: bool = false
	var lawful: bool = bool(PortData.PORTS[port_id]["lawful"])
	for f: String in Bounty.FACTIONS:
		var v: float = Bounty.value(s, f)
		if v <= 0.0:
			continue
		any = true
		var line: String = "  %s: %d  (%s)" % [Loc.t("faction." + f), ceili(v), Loc.t("bounty.stars") % Bounty.stars_for(v)]
		var buttons: Array = []
		if lawful and f == PortData.PORTS[port_id]["faction"]:
			var cost: int = Bounty.pardon_cost(s, port_id)
			if cost >= 0:
				buttons.append([Loc.t("bounty.pardon") % cost, _pardon if cost <= int(s["gold"]) else Callable()])
			else:
				line += "  " + Loc.t("bounty.no_pardon")
		elif not lawful:
			var bribe: int = Bounty.bribe_cost(s, port_id, f)
			buttons.append([Loc.t("bounty.bribe") % bribe, _bribe.bind(f) if bribe >= 0 and bribe <= int(s["gold"]) else Callable()])
		add_item_row(line, buttons)
	if not any:
		add_text("  " + Loc.t("bounty.clean"))
	var owed: int = int(s.get("bounty_claims", 0))
	if owed > 0:
		add_item_row(Loc.t("bounty.owed") % owed, [[Loc.t("bounty.collect"), _collect if Bounty.can_collect(s, port_id) else Callable()]])
	add_text(Loc.t("bounty.posters"))
	for p: Dictionary in Bounty.posters(s):
		var d: Dictionary = CrewData.def(p["crew"])
		add_text("  " + Loc.t("bounty.poster") % [str(d["name"]), str(d["captain"]), int(p["reward"])])
	add_button("menu.back", close)


func _pardon() -> void:
	if Bounty.pardon(state(), port_id):
		Sfx.play("coin")
		toast("bounty.pardoned")
	_rebuild()


func _bribe(faction: String) -> void:
	if Bounty.bribe(state(), port_id, faction):
		Sfx.play("coin")
		toast("bounty.bribed")
	_rebuild()


func _collect() -> void:
	var gold: int = Bounty.collect(state(), port_id)
	if gold > 0:
		Sfx.play("coin")
		toast("bounty.collected", [gold])
	_rebuild()
