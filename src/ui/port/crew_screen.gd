class_name CrewScreen
extends MenuScreen
## Ship and crew: morale and its band, supplies in days, wages, the roster with levels, loot cut and rum ration.

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
	for m: Dictionary in st["roster"]:
		_line(list, "  %s  %s  %s %d  (%d XP)" % [m["name"], Loc.t("crew." + m["type"]), Loc.t("crew.level"), int(m["level"]), int(m["xp"])])
	add_button("menu.back", close)


func _line(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
