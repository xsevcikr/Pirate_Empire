class_name ShipyardCatalogue
extends CatalogueSource
## The ship upgrade station of a city: ships for sale, the eight upgrade lines and yard services.

const UPGRADE_ICONS: Dictionary = {
	"hull": "town/planks", "armor": "dungeon/shield-rectangle", "sails": "proc/sail", "rudder": "town/wheel",
	"cannons": "pirate/cannon", "ram": "castle/siege-ram", "quarters": "nature/bed", "specialty": "pirate/chest",
}
const STAT_KEYS: Dictionary = {
	"hull_hp": "cat.stat_hull", "max_speed_kn": "cat.stat_speed", "turn_rate_deg_s": "cat.stat_turn",
	"rudder_hp": "cat.stat_rudder", "crew_max": "cat.stat_crew",
}
const FULL_TIER_YARD: int = 3  ## Upgrades.purchase refuses tier 5 below this shipyard level


func title_key() -> String:
	return "port.shipyard"


func categories() -> PackedStringArray:
	return PackedStringArray(["cat.ships", "cat.upgrades", "cat.services"])


static func ship_icon(class_id: String) -> String:
	return "pirate/" + ShipModel.model_for(PortService.ship_stats(class_id), "player")


func items(s: Dictionary) -> Array[CatalogueItem]:
	var out: Array[CatalogueItem] = []
	_ships(s, out)
	_upgrades(s, out)
	_services(s, out)
	return out


func _ship_stats(it: CatalogueItem, st: ShipStats) -> void:
	it.stat(Loc.t("cat.stat_speed"), Loc.t("cat.kn") % st.max_speed_kn)
	it.stat(Loc.t("cat.stat_cargo"), Loc.t("cat.tons") % int(st.cargo_t))
	it.stat(Loc.t("cat.stat_guns"), str(st.guns_per_side * 2))
	it.stat(Loc.t("cat.stat_crew"), str(st.crew_max))
	it.stat(Loc.t("cat.stat_hull"), str(int(st.hull_hp)))


func _ships(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var mine := CatalogueItem.make("ship:" + s["ship_class"], "cat.ships", Loc.t("ship." + s["ship_class"]), ship_icon(s["ship_class"]), 0)
	mine.blurb = "\"%s\"   %s %d%%" % [s["ship_name"], Loc.t("hud.hull"), int(float(s["ship_hull"]) * 100.0)]
	mine.status = CatalogueItem.Status.OWNED
	_ship_stats(mine, UpgradeEffects.apply(PortService.ship_stats(s["ship_class"]), s["upgrades"]))
	out.append(mine)
	for class_id in LegendaryShips.owned(s):
		if class_id == s["ship_class"]:
			continue
		var leg := CatalogueItem.make("helm:" + class_id, "cat.ships", Loc.t("ship." + class_id), ship_icon(class_id), 0)
		leg.blurb = Loc.t("cat.legendary")
		leg.action_key = "port.take_helm"
		leg.data = {"kind": "helm", "class": class_id}
		_ship_stats(leg, PortService.ship_stats(class_id))
		out.append(leg)
	for class_id in PortData.CLASS_ORDER:
		if class_id == s["ship_class"] or not PortData.can_sell_class(port_id, class_id):
			continue
		var st: ShipStats = PortService.ship_stats(class_id)
		var it := CatalogueItem.make("ship:" + class_id, "cat.ships", Loc.t("ship." + class_id), ship_icon(class_id), PortService.ship_cost(s, class_id))
		it.blurb = Loc.t("cat.trade_in") % [CatalogueScreen.money(st.price), CatalogueScreen.money(PortService.trade_in_value(s, class_id))]
		it.data = {"kind": "ship", "class": class_id, "trade": "buy_ship"}
		_ship_stats(it, st)
		if st.infamy_required > int(s["fame"]):
			it.lock(Loc.t("port.fame_needed") % st.infamy_required)
		out.append(it)


func _upgrades(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var level: int = PortData.PORTS[port_id]["shipyard_level"]
	for line: String in Upgrades.BASE_COST.keys():
		var tier: int = int(s["upgrades"].get(line, 0))
		var maxed: bool = tier >= Upgrades.TIERS
		var price: int = 0 if maxed else Upgrades.cost(line, tier + 1, s["ship_class"])
		var it := CatalogueItem.make("upg:" + line, "cat.upgrades", Loc.t("upg." + line), UPGRADE_ICONS[line], price)
		it.tier = tier
		it.tiers = Upgrades.TIERS
		it.action_key = "port.install"
		it.data = {"kind": "upgrade", "line": line, "trade": "upgrade"}
		if UpgradeEffects.PER_TIER.has(line):
			for stat: String in UpgradeEffects.PER_TIER[line]:
				var pct: int = roundi(float(UpgradeEffects.PER_TIER[line][stat]) * 100.0)
				it.stat(Loc.t(STAT_KEYS[stat]), Loc.t("cat.pct_now") % [pct, pct * tier])
		it.blurb = Loc.t("cat.upg_desc." + line)
		if maxed:
			it.status = CatalogueItem.Status.MAXED
		elif tier + 1 == Upgrades.TIERS and level < FULL_TIER_YARD:
			it.lock(Loc.t("cat.needs_yard") % FULL_TIER_YARD)
		out.append(it)


func _services(s: Dictionary, out: Array[CatalogueItem]) -> void:
	var repair := CatalogueItem.make("svc:repair", "cat.services", Loc.t("port.repair"), "pirate/crate", PortService.repair_cost(s))
	repair.blurb = Loc.t("cat.repair_desc")
	repair.stat(Loc.t("hud.hull"), "%d%%" % int(float(s["ship_hull"]) * 100.0))
	repair.action_key = "port.repair_do"
	repair.data = {"kind": "repair"}
	if repair.price <= 0:
		repair.status = CatalogueItem.Status.MAXED
	out.append(repair)
	var ins := CatalogueItem.make("svc:insure", "cat.services", Loc.t("insure.label"), "dungeon/coin", Finance.insurance_premium(s))
	ins.blurb = Loc.t("cat.insure_desc")
	ins.action_key = "insure.buy"
	ins.data = {"kind": "insure"}
	if bool(s["insured"]):
		ins.status = CatalogueItem.Status.OWNED
	out.append(ins)


func buy(s: Dictionary, item: CatalogueItem) -> bool:
	match item.data.get("kind", ""):
		"ship":
			return PortService.buy_ship(s, item.data["class"], port_id)
		"helm":
			return LegendaryShips.take_helm(s, item.data["class"])
		"upgrade":
			var level: int = PortData.PORTS[port_id]["shipyard_level"]
			var left: int = Upgrades.purchase(s["upgrades"], item.data["line"], s["ship_class"], int(s["gold"]), level)
			if left < 0:
				return false
			s["gold"] = left
			return true
		"repair":
			return PortService.repair(s)
		"insure":
			return Finance.buy_insurance(s)
	return false


func icon_list() -> PackedStringArray:
	var out: PackedStringArray = []
	for class_id in PortData.CLASS_ORDER:
		out.append(ship_icon(class_id))
	out.append("pirate/ship-ghost")
	for line: String in UPGRADE_ICONS:
		out.append(UPGRADE_ICONS[line])
	out.append_array(["pirate/crate", "dungeon/coin"])
	return out
