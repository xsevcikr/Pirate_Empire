class_name CrewScreen
extends MenuScreen
## Ship and crew, as big cards: a row of supply chips (morale, food, water, rum, wages), the loot cut and rum
## ration, one parchment card per sailor with a Kenney portrait, name, job, level stars and an XP bar, and the
## hold as item cards (picture, name, amount).

const CARD_COLUMNS: int = 3
const GOOD_ICONS: Dictionary = {"fish": "pirate/barrel", "rum": "pirate/bottle", "gunpowder": "pirate/barrel", "iron": "pirate/cannon-ball",
	"spices": "pirate/chest", "gems": "pirate/chest", "contraband": "pirate/chest"}
const PORTRAITS: String = "abcdefghijklmnopqr"

var world: Node


func _init() -> void:
	super()
	_title_key = "crew.screen"
	dim = 0.55


func build() -> void:
	var st: Dictionary = Session.state
	_box.custom_minimum_size = Vector2(980, 0)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 26)
	chips.add_theme_constant_override("v_separation", 8)
	_box.add_child(chips)
	var morale: float = float(st["morale"])
	chips.add_child(UiKit.chip("star", Loc.t("crew.morale_chip") % [int(morale), Loc.t("morale." + Morale.band(morale))], UiKit.SIZE_BODY, UiKit.health_color(morale / 100.0)))
	chips.add_child(UiKit.chip("pirate/barrel", Loc.t("crew.days") % CrewLife.days_left(st, "food")))
	chips.add_child(UiKit.chip("pirate/bottle-large", Loc.t("crew.days") % CrewLife.days_left(st, "water")))
	chips.add_child(UiKit.chip("pirate/bottle", Loc.t("crew.days") % CrewLife.days_left(st, "rum")))
	chips.add_child(UiKit.chip("dungeon/coin", Loc.t("crew.wage_chip") % CrewLife.wages_per_day(st)))
	chips.add_child(UiKit.chip("characters/character-a", Loc.t("crew.count_chip") % [int(st["crew"]), int(st["wounded"])]))
	var cut := HSlider.new()
	cut.min_value = Morale.CUT_MIN * 100.0
	cut.max_value = Morale.CUT_MAX * 100.0
	cut.step = 5.0
	cut.value = float(st["captain_cut"]) * 100.0
	cut.focus_mode = Control.FOCUS_ALL
	cut.custom_minimum_size = Vector2(260, 30)
	cut.value_changed.connect(func(v: float) -> void: st["captain_cut"] = v / 100.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l: Label = UiKit.label(Loc.t("crew.cut"), UiKit.SIZE_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(cut)
	var ration := CheckButton.new()
	ration.text = Loc.t("crew.rum_ration")
	ration.button_pressed = bool(st["rum_ration"])
	ration.focus_mode = Control.FOCUS_ALL
	ration.toggled.connect(func(on: bool) -> void: st["rum_ration"] = on)
	row.add_child(ration)
	_box.add_child(row)
	var roster_title: Label = UiKit.label(Loc.t("crew.roster"), UiKit.SIZE_TITLE, UiKit.GOLD, true)
	_box.add_child(roster_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_box.add_child(scroll)
	for m: Dictionary in st["roster"]:
		grid.add_child(card(m))
	var goods: Array = []
	for g: String in st["cargo"]:
		if float(st["cargo"][g]) >= 1.0:
			goods.append(g)
	if not goods.is_empty():
		var hold_title: Label = UiKit.label(Loc.t("crew.hold") % [PortService.cargo_used(st), PortService.cargo_capacity(st)], UiKit.SIZE_TITLE, UiKit.GOLD, true)
		_box.add_child(hold_title)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		_box.add_child(flow)
		for g: String in goods:
			flow.add_child(item_card(GOOD_ICONS.get(g, "pirate/crate"), Loc.t("good." + g), "x%d" % int(st["cargo"][g])))
	add_button("menu.back", close)


## The Kenney character a sailor looks like: always the same one for the same name.
static func portrait_of(member: Dictionary) -> String:
	var n: String = str(member.get("name", ""))
	return "characters/character-" + PORTRAITS[absi(n.hash()) % PORTRAITS.length()]


## XP progress inside the current level, 0..1 (1 at the top level).
static func level_progress(member: Dictionary) -> float:
	var lvl: int = int(member["level"])
	if lvl >= CrewTypes.MAX_LEVEL:
		return 1.0
	var lo: int = 0 if lvl <= 1 else CrewTypes.XP_THRESHOLDS[lvl - 2]
	var hi: int = CrewTypes.XP_THRESHOLDS[lvl - 1]
	return clampf(float(int(member["xp"]) - lo) / float(maxi(hi - lo, 1)), 0.0, 1.0)


## One big card for one sailor.
func card(m: Dictionary) -> PanelContainer:
	var p: PanelContainer = UiKit.panel("panel_paper", 14)
	p.set_meta("kind", "crew_card")
	p.custom_minimum_size = Vector2(310, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	row.add_child(UiKit.icon(portrait_of(m), 96))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(str(m["name"]), UiKit.SIZE_BODY, UiKit.PAPER_TEXT, true, false))
	col.add_child(UiKit.label(Loc.t("crew." + str(m["type"])), UiKit.SIZE_SMALL, UiKit.PAPER_TEXT, false, false))
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 0)
	for i in CrewTypes.MAX_LEVEL:
		var s: TextureRect = UiKit.icon("star", 22)
		if i >= int(m["level"]):
			s.modulate = Color(0.3, 0.25, 0.2, 0.35)
		stars.add_child(s)
	col.add_child(stars)
	var xp: ProgressBar = UiKit.bar(UiKit.FRIEND, 14)
	xp.value = level_progress(m) * 100.0
	col.add_child(xp)
	col.add_child(UiKit.label("%d XP" % int(m["xp"]), 16, UiKit.PAPER_TEXT, false, false))
	return p


## A small card for something in the hold.
func item_card(icon_name: String, title: String, amount: String) -> PanelContainer:
	var p: PanelContainer = UiKit.panel("panel_paper", 10)
	p.set_meta("kind", "item_card")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(UiKit.icon(icon_name, 56))
	var col := VBoxContainer.new()
	col.add_child(UiKit.label(title, UiKit.SIZE_SMALL, UiKit.PAPER_TEXT, true, false))
	col.add_child(UiKit.label(amount, UiKit.SIZE_BODY, UiKit.PAPER_TEXT, true, false))
	row.add_child(col)
	return p
