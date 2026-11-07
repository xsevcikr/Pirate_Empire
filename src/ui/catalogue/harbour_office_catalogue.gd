class_name HarbourOfficeCatalogue
extends ShipyardCatalogue
## The harbour office of the player's own lagoon: fit ship upgrades at home, raise the lagoon and its housing so
## more pirates can live there, and send those pirates out on missions (LagoonMissions) without the captain.

const RANK_ICON: String = "pirate/structure-platform-dock"
const HOUSING_ICON: String = "nature/bed"


func title_key() -> String:
	return "office.title"


func categories() -> PackedStringArray:
	return PackedStringArray(["cat.upgrades", "office.lagoon", "office.missions", "cat.services"])


## The lagoon's own shipyard sets the yard level; without one the office can still fit the first four tiers.
func yard_level(s: Dictionary) -> int:
	return maxi(int(Lagoon.best(s, "repair")), 1)


func items(s: Dictionary) -> Array[CatalogueItem]:
	var out: Array[CatalogueItem] = []
	_upgrades(s, out)
	for it in out:
		if it.status == CatalogueItem.Status.LOCKED:
			it.requirement = Loc.t("office.needs_lagoon_yard") % FULL_TIER_YARD
	_lagoon(s, out)
	_missions(s, out)
	_services(s, out)
	return out


func _lagoon(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var rank: int = Lagoon.rank_of(s)
	var cost: int = Lagoon.next_rank_cost(s)
	var next_id: String = LagoonData.rank(rank + 1)["id"] if cost > 0 else LagoonData.rank(rank)["id"]
	var up := CatalogueItem.make("office:rank", "office.lagoon", Loc.t("lagoon.rank_" + next_id), RANK_ICON, maxi(cost, 0))
	up.blurb = Loc.t("office.rank_desc")
	up.tier = rank + 1
	up.tiers = LagoonData.RANKS.size()
	up.stat(Loc.t("office.stat_plots"), str(LagoonData.cells(rank).size()))
	up.stat(Loc.t("office.stat_piers"), str(Lagoon.pier_slots(s)))
	up.stat(Loc.t("office.stat_parties"), str(LagoonMissions.slots(s)))
	up.action_key = "office.raise"
	up.data = {"kind": "rank", "trade": "lagoon_rank"}
	if cost < 0:
		up.status = CatalogueItem.Status.MAXED
	out.append(up)
	var hcost: int = Lagoon.housing_cost(s)
	var lv: int = Lagoon.housing_level(s)
	var house := CatalogueItem.make("office:housing", "office.lagoon", Loc.t("office.housing"), HOUSING_ICON, maxi(hcost, 0))
	house.blurb = Loc.t("office.housing_desc")
	house.tier = lv
	house.tiers = (LagoonData.HOUSING["cost"] as Array).size()
	house.stat(Loc.t("office.stat_people"), "%d / %d" % [int(Lagoon.data(s)["pop"]) + LagoonMissions.away(s), Lagoon.beds(s)])
	house.stat(Loc.t("office.stat_beds"), "+%d" % Lagoon.housing_beds(s))
	if hcost >= 0:
		house.stat(Loc.t("cat.stat_next"), "+%d" % int(LagoonData.HOUSING["beds"][lv]))
	house.action_key = "office.expand"
	house.data = {"kind": "housing", "trade": "lagoon_housing"}
	if hcost < 0:
		house.status = CatalogueItem.Status.MAXED
	elif rank < Lagoon.housing_rank_needed(s):
		house.lock(Loc.t("office.needs_rank") % Loc.t("lagoon.rank_" + LagoonData.rank(Lagoon.housing_rank_needed(s))["id"]))
	out.append(house)


func _missions(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var l: Dictionary = Lagoon.data(s)
	for p: Dictionary in LagoonMissions.active(s):
		var m: Dictionary = LagoonMissions.mission(p["id"])
		var it := CatalogueItem.make("away:" + str(p["id"]), "office.missions", Loc.t("mission." + str(p["id"])), m["icon"], 0)
		it.blurb = Loc.t("mission.desc." + str(p["id"]))
		it.note = Loc.t("office.away") % [int(p["crew"]), maxi(int(p["back"]) - int(s["day"]), 0)]
		it.status = CatalogueItem.Status.OWNED
		out.append(it)
	for m: Dictionary in LagoonMissions.MISSIONS:
		var id: String = m["id"]
		if LagoonMissions.is_out(s, id):
			continue
		var it := CatalogueItem.make("mission:" + id, "office.missions", Loc.t("mission." + id), m["icon"], 0)
		it.blurb = Loc.t("mission.desc." + id)
		it.stat(Loc.t("office.stat_crew"), str(int(m["crew"])))
		it.stat(Loc.t("office.stat_days"), str(int(m["days"])))
		it.stat(Loc.t("office.stat_reward"), "%s-%s" % [CatalogueScreen.money(int(m["gold"][0])), CatalogueScreen.money(int(m["gold"][1]))])
		it.stat(Loc.t("office.stat_risk"), "%d%%" % roundi(LagoonMissions.risk(s, id) * 100.0))
		it.stat(Loc.t("office.stat_lost"), "%d%%" % roundi(LagoonMissions.loss_chance(s, id) * 100.0))
		it.action_key = "office.send"
		it.note = Loc.t("office.send_note") % int(m["crew"])
		it.data = {"kind": "mission", "id": id, "trade": "lagoon_mission"}
		match LagoonMissions.send_problem(s, id):
			"rank":
				it.lock(Loc.t("office.needs_rank") % Loc.t("lagoon.rank_" + LagoonData.rank(int(m["rank"]))["id"]))
			"slots":
				it.lock(Loc.t("office.no_slots") % LagoonMissions.slots(s))
			"crew":
				it.lock(Loc.t("office.no_crew") % [int(m["crew"]), int(l["pop"])])
		out.append(it)
	for e: Dictionary in LagoonMissions.log_of(s):
		var lost: bool = int(e["alive"]) == 0
		var it := CatalogueItem.make("log:%d:%s" % [int(e["day"]), e["id"]], "office.missions", Loc.t("mission." + str(e["id"])), "dungeon/stones" if lost else "dungeon/coin", 0)
		it.blurb = Loc.t("office.returned") % int(e["day"])
		it.status = CatalogueItem.Status.OWNED
		it.note = LagoonMissions.report(e)
		it.note_bad = lost
		out.append(it)


func buy(s: Dictionary, item: CatalogueItem) -> bool:
	match item.data.get("kind", ""):
		"rank":
			return Lagoon.rank_up(s)
		"housing":
			return Lagoon.expand_housing(s)
		"mission":
			return LagoonMissions.send(s, item.data["id"])
	return super(s, item)


func bought_message(_s: Dictionary, item: CatalogueItem) -> String:
	if item.data.get("kind", "") == "mission":
		return Loc.t("office.sent") % item.title
	return ""


func icon_list() -> PackedStringArray:
	var out: PackedStringArray = [RANK_ICON, HOUSING_ICON, "dungeon/stones", "dungeon/coin"]
	for m: Dictionary in LagoonMissions.MISSIONS:
		if not out.has(m["icon"]):
			out.append(m["icon"])
	return out
