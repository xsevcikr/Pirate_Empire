class_name OutfitterCatalogue
extends CatalogueSource
## The outfitter: cannon shot by the ten, the captain's weapons, and loading small-arms shot into the pistols.

const AMMO_ICONS: Dictionary = {
	"round": "pirate/cannon-ball", "chain": "proc/chain_shot", "grape": "dungeon/stones", "heated": "proc/heated_shot", "explosive": "pirate/barrel",
}
const WEAPON_ICONS: Dictionary = {
	"cutlass": "dungeon/weapon-sword", "rapier": "arena/weapon-sword", "boarding_axe": "proc/axe", "dagger": "proc/dagger",
	"flintlock": "proc/flintlock", "musket": "proc/musket", "blunderbuss": "proc/blunderbuss", "grenado": "proc/grenado",
}


func title_key() -> String:
	return "port.outfitter"


func categories() -> PackedStringArray:
	return PackedStringArray(["cat.weapons", "cat.ammo", "cat.supplies"])


func items(s: Dictionary) -> Array[CatalogueItem]:
	var out: Array[CatalogueItem] = []
	for id: String in WeaponData.sold_in_shops():
		var w: Dictionary = WeaponData.WEAPONS[id]
		var it := CatalogueItem.make("weapon:" + id, "cat.weapons", Loc.t("weapon." + id), WEAPON_ICONS.get(id, ""), int(w["price"]))
		it.blurb = Loc.t("cat.kind." + str(w["kind"]))
		var dmg: Variant = w["damage"]
		it.stat(Loc.t("cat.stat_damage"), "%d-%d" % [dmg[0], dmg[1]] if dmg is Array and dmg[0] != dmg[1] else str(dmg[0] if dmg is Array else dmg))
		if w.has("reload"):
			it.stat(Loc.t("cat.stat_reload"), Loc.t("cat.seconds") % float(w["reload"]))
		if w.has("range"):
			it.stat(Loc.t("cat.stat_range"), Loc.t("cat.metres") % int(w["range"]))
		if w.has("speed"):
			it.stat(Loc.t("cat.stat_swing"), Loc.t("cat.seconds") % float(w["speed"][0]))
		it.data = {"kind": "weapon", "id": id}
		if s["owned_weapons"].has(id):
			it.status = CatalogueItem.Status.OWNED
		out.append(it)
	for id: String in GunData.AMMO_ORDER:
		var a: Dictionary = GunData.AMMO[id]
		var it := CatalogueItem.make("ammo:" + id, "cat.ammo", Loc.t("ammo." + id), AMMO_ICONS.get(id, ""), PortService.ammo_price_per_10(s, id))
		it.blurb = Loc.t("cat.per_10") % int(s["ammo"].get(id, 0))
		it.stat(Loc.t("cat.stat_vs_hull"), "x%.2f" % float(a["hull"]))
		it.stat(Loc.t("cat.stat_vs_sails"), "x%.2f" % float(a["sail"]))
		it.stat(Loc.t("cat.stat_vs_crew"), "x%.2f" % float(a["crew"]))
		it.stat(Loc.t("cat.stat_range"), "x%.1f" % float(a["range"]))
		it.action_key = "port.buy_10_shots"
		it.data = {"kind": "ammo", "id": id}
		out.append(it)
	var units: float = float(s["supplies"]["small_arms"])
	var load := CatalogueItem.make("svc:small_arms", "cat.supplies", Loc.t("supply.small_arms"), "pirate/crate", 0)
	load.blurb = Loc.t("cat.small_arms_desc") % WeaponData.SHOTS_PER_SMALL_ARMS_UNIT
	load.stat(Loc.t("cat.stat_units"), str(int(units)))
	load.stat(Loc.t("port.pistol_shots"), str(int(s["pistol_shots"])))
	load.action_key = "port.load"
	load.data = {"kind": "load"}
	if units < 1.0:
		load.lock(Loc.t("cat.no_small_arms"))
	out.append(load)
	return out


func buy(s: Dictionary, item: CatalogueItem) -> bool:
	match item.data.get("kind", ""):
		"weapon":
			return PortService.buy_weapon(s, item.data["id"])
		"ammo":
			return PortService.buy_ammo(s, item.data["id"], 1)
		"load":
			if float(s["supplies"]["small_arms"]) < 1.0:
				return false
			PortService.load_small_arms(s)
			return true
	return false


func icon_list() -> PackedStringArray:
	var out: PackedStringArray = []
	for d: Dictionary in [AMMO_ICONS, WEAPON_ICONS]:
		for k: String in d:
			if not out.has(d[k]):
				out.append(d[k])
	out.append("pirate/crate")
	return out
