class_name GoalsScreen
extends PortScreen
## The goals list (F7): every goal with its progress and the stars it pays, the stars earned so far and the
## parrot colours they unlock.

const INK := Color(0.16, 0.12, 0.2)
const PAPER := Color(0.99, 0.94, 0.8)
const PAPER_DONE := Color(0.82, 0.95, 0.8)


func _init() -> void:
	super()
	_title_key = "goals.title"
	dim = 0.6


func build() -> void:
	var s: Dictionary = state()
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(StarIcon.make(34))
	var total := Label.new()
	total.text = Loc.t("goals.stars") % [EasyPlay.stars(s), GoalData.total_stars()]
	total.add_theme_font_size_override("font_size", 24)
	head.add_child(total)
	_box.add_child(head)
	var col: Dictionary = EasyPlay.parrot_colour(s)
	var next: Dictionary = {}
	for c in GoalData.PARROT_COLOURS:
		if int(c["stars"]) > EasyPlay.stars(s):
			next = c
			break
	var pl := Label.new()
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.text = Loc.t("goals.parrot_colour") % [Loc.t(ParrotHints.NAME_KEY), Loc.t("parrot.colour_" + str(col["id"]))]
	if not next.is_empty():
		pl.text += "  " + Loc.t("goals.next_colour") % [int(next["stars"]), Loc.t("parrot.colour_" + str(next["id"]))]
	_box.add_child(pl)
	begin_list(440.0)
	_list.custom_minimum_size = Vector2(680, 0)
	for g in GoalData.LIST:
		_list.add_child(_row(s, g))
	add_button("menu.back", close)


func _row(s: Dictionary, g: Dictionary) -> Control:
	var done: bool = EasyPlay.is_done(s, str(g["id"]))
	var card := PanelContainer.new()
	card.set_meta("kind", "goal_row")
	card.add_theme_stylebox_override("panel", CatalogueScreen._style(PAPER_DONE if done else PAPER, INK, 2, 10, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", INK)
	var have: int = int(minf(EasyPlay.value(s, str(g["stat"])), float(g["goal"])))
	l.text = ("%s  (%s)" % [EasyPlay.goal_text(str(g["id"])), Loc.t("goals.done_mark")]) if done else ("%s  (%d/%d)" % [EasyPlay.goal_text(str(g["id"])), have, int(g["goal"])])
	row.add_child(l)
	if not done:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 18)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = EasyPlay.progress(s, g)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
	for i in int(g["stars"]):
		row.add_child(StarIcon.make(24, done))
	return card
