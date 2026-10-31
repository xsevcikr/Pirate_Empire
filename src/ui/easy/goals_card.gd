class_name GoalsCard
extends CanvasLayer
## A small card on the left of the sailing screen with the next goals, the stars earned, and buttons for the goals
## list (F7), the collection book (F8) and the parrot's hint (F9).

signal open_goals
signal open_book
signal ask_parrot

const INK := Color(0.16, 0.12, 0.2)
const PAPER := Color(0.99, 0.94, 0.8, 0.94)
const REFRESH_S: float = 1.0

var _rows: VBoxContainer
var _stars: Label
var _t: float = 0.0


func _ready() -> void:
	layer = 5
	var card := PanelContainer.new()
	card.name = "GoalsCard"
	card.position = Vector2(24, 330)
	card.custom_minimum_size = Vector2(330, 0)
	card.add_theme_stylebox_override("panel", CatalogueScreen._style(PAPER, INK, 3, 12, 10))
	card.theme = Look.ui_theme()
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = Loc.t("goals.card_title")
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(StarIcon.make(22))
	_stars = Label.new()
	_stars.add_theme_color_override("font_color", INK)
	_stars.add_theme_font_size_override("font_size", 20)
	head.add_child(_stars)
	v.add_child(head)
	_rows = VBoxContainer.new()
	v.add_child(_rows)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	for spec: Array in [["F7 " + Loc.t("goals.button"), open_goals], ["F8 " + Loc.t("coll.button"), open_book], ["F9 " + Loc.t("parrot.name"), ask_parrot]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.set_meta("kind", "goals_card_button")
		var sig: Signal = spec[1]
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			sig.emit())
		buttons.add_child(b)
	v.add_child(buttons)
	refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= REFRESH_S:
		_t = 0.0
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_F7:
			open_goals.emit()
		KEY_F8:
			open_book.emit()
		KEY_F9:
			ask_parrot.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func refresh() -> void:
	if _rows == null or Session.state.is_empty():
		return
	var s: Dictionary = Session.state
	_stars.text = str(EasyPlay.stars(s))
	for c in _rows.get_children():
		c.queue_free()
	var open: Array[Dictionary] = EasyPlay.active(s)
	if open.is_empty():
		var l := Label.new()
		l.text = Loc.t("goals.all_done")
		l.add_theme_color_override("font_color", INK)
		_rows.add_child(l)
	for g in open:
		var row := HBoxContainer.new()
		row.set_meta("kind", "goals_card_row")
		var l := Label.new()
		l.text = "%s  %d/%d" % [EasyPlay.goal_text(str(g["id"])), int(minf(EasyPlay.value(s, str(g["stat"])), float(g["goal"]))), int(g["goal"])]
		l.add_theme_color_override("font_color", INK)
		l.add_theme_font_size_override("font_size", 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		row.add_child(l)
		for i in int(g["stars"]):
			row.add_child(StarIcon.make(16, false))
		_rows.add_child(row)
