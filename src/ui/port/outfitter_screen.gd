class_name OutfitterScreen
extends PortScreen
## Weapons for the captain and ammunition for the guns.


func _init() -> void:
	super()
	_title_key = "port.outfitter"


func build() -> void:
	add_header()
	begin_list()
	var s: Dictionary = state()
	add_text(Loc.t("port.ammo"))
	for id: String in GunData.AMMO_ORDER:
		var per10: int = PortService.ammo_price_per_10(s, id)
		add_item_row("%s  %d g / 10   (%s %d)" % [Loc.t("ammo." + id), per10, Loc.t("port.owned"), int(s["ammo"].get(id, 0))],
			[[Loc.t("port.buy_10_shots"), _buy_ammo.bind(id) if per10 <= int(s["gold"]) else Callable()]])
	add_text(Loc.t("port.weapons"))
	for id: String in WeaponData.sold_in_shops():
		var w: Dictionary = WeaponData.WEAPONS[id]
		var owned: bool = s["owned_weapons"].has(id)
		add_item_row("%s  %d g%s" % [Loc.t("weapon." + id), int(w["price"]), "  (" + Loc.t("port.owned") + ")" if owned else ""],
			[[Loc.t("port.buy_ship"), _buy_weapon.bind(id) if not owned and int(w["price"]) <= int(s["gold"]) else Callable()]])
	var units: float = float(s["supplies"]["small_arms"])
	add_item_row("%s: %d  (%s %d)" % [Loc.t("supply.small_arms"), int(units), Loc.t("port.pistol_shots"), int(s["pistol_shots"])],
		[[Loc.t("port.load"), _load_small_arms if units >= 1.0 else Callable()]])
	add_button("menu.back", close)


func _buy_ammo(id: String) -> void:
	PortService.buy_ammo(state(), id, 1)
	_rebuild()


func _buy_weapon(id: String) -> void:
	PortService.buy_weapon(state(), id)
	_rebuild()


func _load_small_arms() -> void:
	PortService.load_small_arms(state())
	_rebuild()
