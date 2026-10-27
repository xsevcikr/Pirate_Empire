class_name CustomizeScreen
extends PortScreen
## Ship and captain customization (Y): flag, sails, hull, figurehead, pet, name, false colours and the captain's look.

signal changed


func _init() -> void:
	super()
	_title_key = "custom.title"
	dim = 0.55


func build() -> void:
	var s: Dictionary = state()
	var c: Dictionary = Customization.get_custom(s)
	begin_list(440.0)
	add_text(Loc.t("custom.flag"))
	_cycle("custom.emblem", CustomizationData.EMBLEMS.size(), int(c["flag"]["emblem"]), func(v: int) -> void: Customization.set_flag(s, v, int(c["flag"]["color"]), int(c["flag"]["layout"])), func(v: int) -> String: return Loc.t("emblem." + CustomizationData.EMBLEMS[v]))
	_cycle("custom.color", CustomizationData.FLAG_COLORS.size(), int(c["flag"]["color"]), func(v: int) -> void: Customization.set_flag(s, int(c["flag"]["emblem"]), v, int(c["flag"]["layout"])), func(v: int) -> String: return str(v + 1))
	_cycle("custom.layout", CustomizationData.FLAG_LAYOUTS.size(), int(c["flag"]["layout"]), func(v: int) -> void: Customization.set_flag(s, int(c["flag"]["emblem"]), int(c["flag"]["color"]), v), func(v: int) -> String: return Loc.t("layout." + CustomizationData.FLAG_LAYOUTS[v]))
	add_item_row(Loc.t("custom.pixel_flag"), [[Loc.t("custom.edit"), _open_pixels]])
	add_text(Loc.t("custom.sails"))
	_cycle("custom.pattern", CustomizationData.SAIL_PATTERNS.size(), int(c["sail"]["pattern"]), func(v: int) -> void: Customization.set_sail(s, v, int(c["sail"]["color"])), func(v: int) -> String: return Loc.t("pattern." + CustomizationData.SAIL_PATTERNS[v]))
	_cycle("custom.color", CustomizationData.SAIL_COLORS.size(), int(c["sail"]["color"]), func(v: int) -> void: Customization.set_sail(s, int(c["sail"]["pattern"]), v), func(v: int) -> String: return str(v + 1))
	add_text(Loc.t("custom.hull"))
	var h: Dictionary = c["hull"]
	_cycle("custom.paint", CustomizationData.HULL_PAINTS.size(), int(h["paint"]), func(v: int) -> void: Customization.set_hull(s, v, int(h["trim"]), int(h["lanterns"]), bool(h["gold_leaf"])), func(v: int) -> String: return Loc.t("paint." + CustomizationData.HULL_PAINTS[v]))
	_cycle("custom.trim", CustomizationData.TRIM_COLORS.size(), int(h["trim"]), func(v: int) -> void: Customization.set_hull(s, int(h["paint"]), v, int(h["lanterns"]), bool(h["gold_leaf"])), func(v: int) -> String: return str(v + 1))
	_cycle("custom.lanterns", CustomizationData.LANTERN_STYLES.size(), int(h["lanterns"]), func(v: int) -> void: Customization.set_hull(s, int(h["paint"]), int(h["trim"]), v, bool(h["gold_leaf"])), func(v: int) -> String: return Loc.t("lantern." + CustomizationData.LANTERN_STYLES[v]))
	var leaf: bool = Customization.gold_leaf_allowed(s)
	add_item_row("%s: %s" % [Loc.t("custom.gold_leaf"), Loc.t("custom.on") if bool(h["gold_leaf"]) else Loc.t("custom.off")],
		[[Loc.t("custom.toggle"), _toggle_leaf if leaf else Callable()]])
	add_text(Loc.t("custom.figurehead"))
	var fi: int = CustomizationData.FIGUREHEAD_ORDER.find(str(c["figurehead"]))
	_cycle("custom.figurehead", CustomizationData.FIGUREHEAD_ORDER.size(), fi, func(v: int) -> void: Customization.set_figurehead(s, CustomizationData.FIGUREHEAD_ORDER[v]), func(v: int) -> String: return Loc.t("figurehead." + CustomizationData.FIGUREHEAD_ORDER[v]))
	var pets: Array[String] = [""]
	pets.append_array(CustomizationData.PET_ORDER)
	_cycle("custom.pet", pets.size(), pets.find(str(c["pet"])), func(v: int) -> void: Customization.set_pet(s, pets[v]), func(v: int) -> String: return Loc.t("pet." + pets[v]) if pets[v] != "" else Loc.t("pet.none"))
	var colours: Array[String] = [""]
	colours.append_array(Reputation.START_REP.keys())
	_cycle("custom.false_colors", colours.size(), colours.find(str(c["false_colors"])), func(v: int) -> void: Customization.set_false_colors(s, colours[v]), func(v: int) -> String: return Loc.t("faction." + colours[v]) if colours[v] != "" else Loc.t("custom.own_colors"))
	add_text(Loc.t("custom.captain"))
	for slot: String in CustomizationData.CAPTAIN_SLOTS:
		var opts: Array = CustomizationData.CAPTAIN_SLOTS[slot]
		var cur: String = str(c["captain"][slot])
		var idx: int = opts.find(cur)
		add_item_row("%s: %s" % [Loc.t("slot." + slot), Loc.t("look.%s.%s" % [slot, cur])], [
			[Loc.t("custom.next"), _look.bind(slot, str(opts[(idx + 1) % opts.size()]))],
		])
	add_button("menu.back", close)


func _cycle(label_key: String, count: int, cur: int, setter: Callable, namer: Callable) -> void:
	var next: int = (maxi(cur, 0) + 1) % count
	add_item_row("%s: %s" % [Loc.t(label_key), namer.call(maxi(cur, 0))], [[Loc.t("custom.next"), _apply.bind(setter, next)]])


func _apply(setter: Callable, v: int) -> void:
	setter.call(v)
	changed.emit()
	_rebuild()


func _toggle_leaf() -> void:
	var h: Dictionary = Customization.get_custom(state())["hull"]
	Customization.set_hull(state(), int(h["paint"]), int(h["trim"]), int(h["lanterns"]), not bool(h["gold_leaf"]))
	changed.emit()
	_rebuild()


func _look(slot: String, choice: String) -> void:
	var s: Dictionary = state()
	if not Customization.owns(s, slot, choice):
		var key: String = "%s/%s" % [slot, choice]
		var gate: Dictionary = CustomizationData.GATED.get(key, {})
		if gate.has("cost") and Customization.buy(s, slot, choice):
			toast("custom.bought")
		else:
			toast("custom.locked")
			return
	Customization.set_look(s, slot, choice)
	changed.emit()
	_rebuild()


func _open_pixels() -> void:
	open_child(PixelFlagScreen.new())
