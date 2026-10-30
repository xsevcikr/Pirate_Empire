class_name LagoonCatalogue
extends CatalogueSource
## The pirate lagoon's catalogue: ships laid down at the lagoon's own shipyard, and piers to berth them.
## Buildings are not here: they are bought by placing them on a plot in build mode.

const SHIP_NAMES: PackedStringArray = [
	"Salty Maiden", "Black Gull", "Rum Runner", "Sea Wolf", "Crimson Tide", "Kraken's Kiss", "Lucky Doubloon",
	"Iron Mermaid", "Storm Petrel", "Jolly Widow", "Night Heron", "Gilded Shark", "Bold Barnacle", "Silver Eel",
]
const PIER_ICON: String = "pirate/structure-platform-dock"


func title_key() -> String:
	return "cat.lagoon_title"


func categories() -> PackedStringArray:
	return PackedStringArray(["cat.lagoon_ships", "cat.lagoon_piers"])


func items(s: Dictionary) -> Array[CatalogueItem]:
	var out: Array[CatalogueItem] = []
	_ships(s, out)
	_piers(s, out)
	return out


func _ships(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var fleet: Array = s["fleet"]
	for class_id in PortData.CLASS_ORDER:
		var st: ShipStats = PortService.ship_stats(class_id)
		var it := CatalogueItem.make("lagoon_ship:" + class_id, "cat.lagoon_ships", Loc.t("ship." + class_id), ShipyardCatalogue.ship_icon(class_id), st.price)
		it.blurb = Loc.t("cat.lagoon_berths") % [mini(fleet.size(), Lagoon.berths(s)), Lagoon.berths(s)]
		it.stat(Loc.t("cat.stat_speed"), Loc.t("cat.kn") % st.max_speed_kn)
		it.stat(Loc.t("cat.stat_cargo"), Loc.t("cat.tons") % int(st.cargo_t))
		it.stat(Loc.t("cat.stat_guns"), str(st.guns_per_side * 2))
		it.stat(Loc.t("cat.stat_crew"), str(st.crew_max))
		it.action_key = "lagoon.lay_down"
		it.data = {"kind": "ship", "class": class_id, "trade": "lagoon_ship"}
		match Lagoon.commission_problem(s, class_id):
			"yard":
				it.lock(Loc.t("cat.lagoon_need_yard"))
			"berth":
				it.lock(Loc.t("cat.lagoon_need_berth"))
			"fame":
				it.lock(Loc.t("port.fame_needed") % st.infamy_required)
		out.append(it)


func _piers(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var piers: Array = Lagoon.data(s)["piers"] if Lagoon.claimed(s) else []
	for i in piers.size():
		var lv: int = int(piers[i])
		var cost: int = Lagoon.pier_upgrade_cost(s, i)
		var it := CatalogueItem.make("pier:%d" % i, "cat.lagoon_piers", Loc.t("cat.lagoon_pier") % (i + 1), PIER_ICON, maxi(cost, 0))
		it.blurb = Loc.t("cat.lagoon_pier_desc")
		it.tier = lv
		it.tiers = LagoonData.pier_levels()
		it.stat(Loc.t("cat.stat_berths"), str(int(LagoonData.PIER["berths"][lv - 1])))
		if cost >= 0:
			it.stat(Loc.t("cat.stat_next"), str(int(LagoonData.PIER["berths"][lv])))
		else:
			it.status = CatalogueItem.Status.MAXED
		it.action_key = "lagoon.upgrade"
		it.data = {"kind": "upgrade_pier", "index": i, "trade": "lagoon_pier"}
		out.append(it)
	var fresh := CatalogueItem.make("pier:new", "cat.lagoon_piers", Loc.t("cat.lagoon_new_pier"), PIER_ICON, LagoonData.pier_cost(1))
	fresh.blurb = Loc.t("cat.lagoon_pier_desc")
	fresh.stat(Loc.t("cat.stat_berths"), str(int(LagoonData.PIER["berths"][0])))
	fresh.action_key = "lagoon.build_it"
	fresh.data = {"kind": "build_pier", "trade": "lagoon_pier"}
	if not Lagoon.claimed(s):
		fresh.lock(Loc.t("cat.lagoon_unclaimed"))
	elif piers.size() >= Lagoon.pier_slots(s):
		fresh.lock(Loc.t("lagoon.piers_full"))
	out.append(fresh)


func buy(s: Dictionary, item: CatalogueItem) -> bool:
	match item.data.get("kind", ""):
		"ship":
			var n: String = SHIP_NAMES[(s["fleet"] as Array).size() % SHIP_NAMES.size()]
			return Lagoon.commission(s, item.data["class"], n)
		"build_pier":
			return Lagoon.build_pier(s)
		"upgrade_pier":
			return Lagoon.upgrade_pier(s, int(item.data["index"]))
	return false


func bought_message(s: Dictionary, item: CatalogueItem) -> String:
	if item.data.get("kind", "") == "ship":
		var fleet: Array = s["fleet"]
		return Loc.t("lagoon.launched") % str(fleet[fleet.size() - 1].get("name", ""))
	return ""


func icon_list() -> PackedStringArray:
	var out: PackedStringArray = [PIER_ICON]
	for class_id in PortData.CLASS_ORDER:
		var icon: String = ShipyardCatalogue.ship_icon(class_id)
		if not out.has(icon):
			out.append(icon)
	return out
