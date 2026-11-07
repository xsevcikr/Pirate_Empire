class_name CrewScreen
extends MenuScreen
## Ship and crew: morale and its band, supplies in days, wages, the roster with levels, personalities and loyalty,
## loot cut and rum ration.

const LOYALTY_COLOR: Dictionary = {"devoted": Color(0.55, 0.95, 0.55), "loyal": Color(0.9, 0.95, 0.85), "wavering": Color(1.0, 0.85, 0.45), "disloyal": Color(1.0, 0.5, 0.45)}

var world: Node


func _init() -> void:
	super()
	_title_key = "crew.screen"
	dim = 0.55


func build() -> void:
	var st: Dictionary = Session.state
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_box.add_child(scroll)
	_line(list, Loc.t("crew.morale_line") % [int(st["morale"]), Loc.t("morale." + Morale.band(float(st["morale"]))), int(Morale.efficiency(float(st["morale"])) * 100.0)])
	_line(list, Loc.t("crew.supplies_line") % [CrewLife.days_left(st, "food"), CrewLife.days_left(st, "water"), CrewLife.days_left(st, "rum")])
	_line(list, Loc.t("crew.wages_line") % [CrewLife.wages_per_day(st), int(st["crew"]), int(st["wounded"])])
	var cut := HSlider.new()
	cut.min_value = Morale.CUT_MIN * 100.0
	cut.max_value = Morale.CUT_MAX * 100.0
	cut.step = 5.0
	cut.value = float(st["captain_cut"]) * 100.0
	cut.focus_mode = Control.FOCUS_ALL
	cut.custom_minimum_size = Vector2(240, 30)
	cut.value_changed.connect(func(v: float) -> void: st["captain_cut"] = v / 100.0)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = Loc.t("crew.cut")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(cut)
	list.add_child(row)
	var ration := CheckButton.new()
	ration.text = Loc.t("crew.rum_ration")
	ration.button_pressed = bool(st["rum_ration"])
	ration.focus_mode = Control.FOCUS_ALL
	ration.toggled.connect(func(on: bool) -> void: st["rum_ration"] = on)
	list.add_child(ration)
	_line(list, Loc.t("crew.roster"))
	CrewPersona.ensure_all(st)
	_line(list, Loc.t("persona.loyal_line") % [CrewPersona.count_at_least(st, CrewPersona.BANDS["loyal"]), st["roster"].size(), int(Mutiny.duel_win_chance(st) * 100.0)])
	for m: Dictionary in st["roster"]:
		var l2: Label = _line(list, "  %s  %s  %s %d  (%d XP)   %s   %s %d (%s)" % [m["name"], Loc.t("crew." + m["type"]), Loc.t("crew.level"), int(m["level"]), int(m["xp"]),
			Loc.t("trait." + CrewPersona.trait_of(m)), Loc.t("persona.loyalty"), int(CrewPersona.loyalty(m)), Loc.t("loyalty." + CrewPersona.band(CrewPersona.loyalty(m)))])
		l2.tooltip_text = Loc.t("trait." + CrewPersona.trait_of(m) + "_tip")
		l2.mouse_filter = Control.MOUSE_FILTER_PASS
		l2.add_theme_color_override("font_color", LOYALTY_COLOR[CrewPersona.band(CrewPersona.loyalty(m))])
	add_button("menu.back", close)


func _line(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l
