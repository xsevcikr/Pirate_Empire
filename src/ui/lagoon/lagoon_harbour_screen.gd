class_name LagoonHarbourScreen
extends PortScreen
## The lagoon's harbour: see the fleet at its berths, take command of another ship or sell one. Piers and new ships
## are bought from the lagoon catalogue (LagoonCatalogue).


func _init() -> void:
	super()
	dim = 0.55
	_title_key = "lagoon.harbour"


func build() -> void:
	add_header()
	begin_list(420.0)
	var s: Dictionary = state()
	var fleet: Array = s["fleet"]
	add_text(Loc.t("lagoon.berths") % [mini(fleet.size(), Lagoon.berths(s)), Lagoon.berths(s)])
	add_text(Loc.t("lagoon.fleet"))
	if fleet.is_empty():
		add_text(Loc.t("lagoon.no_fleet"))
	var berths: int = Lagoon.berths(s)
	for i in fleet.size():
		var e: Dictionary = fleet[i]
		var where: String = Loc.t("lagoon.at_pier" if i < berths else "lagoon.at_anchor")
		var text: String = "%s \"%s\"  %s %d%%  %s" % [Loc.t("ship." + Lagoon.class_of(e)), str(e.get("name", "")), Loc.t("hud.hull"), int(float(e.get("hull", 1.0)) * 100.0), where]
		add_item_row(text, [[Loc.t("lagoon.command"), _command.bind(i)], [Loc.t("lagoon.sell") % Lagoon.sell_price(s, i), _sell.bind(i)]])
	add_button("cat.lagoon_open", _open_catalogue)
	add_button("menu.back", close)


func _open_catalogue() -> void:
	var cat := CatalogueScreen.with_source(LagoonCatalogue.new(), port_id)
	open_child(cat)


func _command(i: int) -> void:
	if Lagoon.take_command(state(), i):
		toast("lagoon.took_command", [str(state()["ship_name"])])
	_rebuild()


func _sell(i: int) -> void:
	var g: int = Lagoon.sell_ship(state(), i)
	if g > 0:
		Sfx.play("coin")
		toast("lagoon.sold", [g])
	_rebuild()
