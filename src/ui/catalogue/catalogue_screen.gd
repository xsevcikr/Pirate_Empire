class_name CatalogueScreen
extends PortScreen
## A shop catalogue: tabs of categories over a grid of cards, each with a picture, stats, price, requirement and a
## buy button. It draws whatever a CatalogueSource lists, so the shipyard, the outfitter and the pirate lagoon share it.

signal bought(item: CatalogueItem)

const COLUMNS: int = 3
const CARD_W: float = 360.0
const INK := Color(0.16, 0.12, 0.2)
const MUTED := Color(0.4, 0.36, 0.46)
const PAPER := Color(0.99, 0.94, 0.8)
const PAPER_LOCKED := Color(0.8, 0.8, 0.84)
const PAPER_OWNED := Color(0.82, 0.95, 0.8)
const SKY := Color(0.62, 0.84, 0.98)
const GOLD_INK := Color(0.72, 0.45, 0.05)
const RED_INK := Color(0.78, 0.18, 0.16)
const GREEN_INK := Color(0.16, 0.55, 0.3)

var source: CatalogueSource
var category: String = ""
var _focus_id: String = ""


func _init() -> void:
	super()
	dim = 0.6


static func with_source(src: CatalogueSource, at_port: String = PortData.START_PORT) -> CatalogueScreen:
	var s := CatalogueScreen.new()
	s.source = src
	s.port_id = at_port
	return s


func _ready() -> void:
	source.port_id = port_id
	_title_key = source.title_key()
	if category == "" and not source.categories().is_empty():
		category = source.categories()[0]
	super()


func build() -> void:
	var page := PanelContainer.new()
	page.name = "Page"
	page.add_theme_stylebox_override("panel", _style(Color(0.22, 0.25, 0.4, 0.94), INK, 4, 18, 14))
	_box.add_child(page)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	page.add_child(inner)
	inner.add_child(_gold_bar())
	inner.add_child(_tabs())
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(CARD_W * COLUMNS + 50.0, 450)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(grid)
	scroll.add_child(center)
	inner.add_child(scroll)
	var gold: int = source.gold(state())
	for it: CatalogueItem in source.items(state()):
		if it.category == category:
			grid.add_child(_card(it, gold))
	add_button("menu.back", close)


func items_in(cat: String) -> Array[CatalogueItem]:
	var out: Array[CatalogueItem] = []
	for it: CatalogueItem in source.items(state()):
		if it.category == cat:
			out.append(it)
	return out


func find_item(id: String) -> CatalogueItem:
	for it: CatalogueItem in source.items(state()):
		if it.id == id:
			return it
	return null


func select(cat: String) -> void:
	category = cat
	_focus_id = ""
	_rebuild()


## Buy by id, the same as pressing the card's button. Returns whether it went through.
func buy_id(id: String) -> bool:
	var it: CatalogueItem = find_item(id)
	return it != null and _buy(it)


func _buy(it: CatalogueItem) -> bool:
	_focus_id = it.id
	if not it.can_buy(source.gold(state())) or not source.buy(state(), it):
		toast("cat.cannot")
		_rebuild()
		return false
	emit_bus("trade_made", [str(it.data.get("trade", "catalogue")), it.id, 1.0, 0])
	var msg: String = source.bought_message(state(), it)
	if msg != "":
		var bus: Node = Svc.node("EventBus")
		if bus != null:
			bus.toast.emit(msg)
	else:
		toast("cat.bought", [it.title])
	bought.emit(it)
	_rebuild()
	return true


func focus_first() -> void:
	if _focus_id != "" and is_inside_tree() and _child == null:
		var b: Button = find_child("Buy_" + _focus_id.validate_node_name(), true, false)
		if b != null and not b.disabled:
			b.grab_focus()
			return
	super()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _child == null:
		var cats: PackedStringArray = source.categories()
		var step: int = 0
		if event.is_action_pressed("ui_page_down"):
			step = 1
		elif event.is_action_pressed("ui_page_up"):
			step = -1
		if step != 0 and cats.size() > 1:
			get_viewport().set_input_as_handled()
			select(cats[posmod(cats.find(category) + step, cats.size())])
			return
	super(event)


# ---- drawing -----------------------------------------------------------------------------------

func _gold_bar() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var coin: Texture2D = CatalogueIcons.texture("dungeon/coin")
	if coin != null:
		var tr := TextureRect.new()
		tr.texture = coin
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(34, 34)
		row.add_child(tr)
	var l := Label.new()
	l.name = "Gold"
	l.text = Loc.t("cat.gold") % money(source.gold(state()))
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	row.add_child(l)
	return row


func _tabs() -> Control:
	var row := HBoxContainer.new()
	row.name = "Tabs"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for cat: String in source.categories():
		var b := Button.new()
		b.name = "Tab_" + cat.validate_node_name()
		b.text = Loc.t(cat)
		b.toggle_mode = true
		b.button_pressed = cat == category
		if cat == category:
			var open: StyleBoxFlat = _style(PAPER, INK, 3, 12, 6)
			for st: String in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, open)
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(170, 42)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(select.bind(cat))
		b.pressed.connect(Sfx.play.bind("ui_click"))
		row.add_child(b)
	return row


func _card(it: CatalogueItem, gold: int) -> Control:
	var fill: Color = PAPER
	match it.status:
		CatalogueItem.Status.LOCKED:
			fill = PAPER_LOCKED
		CatalogueItem.Status.OWNED, CatalogueItem.Status.MAXED:
			fill = PAPER_OWNED
	var card := PanelContainer.new()
	card.name = "Card_" + it.id.validate_node_name()
	card.set_meta("kind", "catalogue_card")
	card.set_meta("item_id", it.id)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.add_theme_stylebox_override("panel", _style(fill, INK, 3, 14, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	top.add_child(_picture(it))
	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 2)
	top.add_child(head)
	head.add_child(_label(it.title, 21, INK))
	if it.blurb != "":
		var b: Label = _label(it.blurb, 14, MUTED)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(200, 0)
		head.add_child(b)
	if it.tiers > 0:
		head.add_child(_pips(it.tier, it.tiers))

	if not it.stats.is_empty():
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 0)
		for pair: Array in it.stats:
			grid.add_child(_label(str(pair[0]), 14, MUTED))
			var v: Label = _label(str(pair[1]), 15, INK)
			v.custom_minimum_size = Vector2(70, 0)
			grid.add_child(v)
		col.add_child(grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	col.add_child(bottom)
	var tag: Label
	match it.status:
		_ when it.note != "" and it.status != CatalogueItem.Status.LOCKED:
			tag = _label(it.note, 17, RED_INK if it.note_bad else GREEN_INK if it.status != CatalogueItem.Status.AVAILABLE else GOLD_INK)
			tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		CatalogueItem.Status.OWNED:
			tag = _label(Loc.t("cat.owned"), 18, GREEN_INK)
		CatalogueItem.Status.MAXED:
			tag = _label(Loc.t("cat.maxed"), 18, GREEN_INK)
		CatalogueItem.Status.LOCKED:
			tag = _label(it.requirement, 15, RED_INK)
			tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_:
			tag = _label(Loc.t("cat.free") if it.price == 0 else Loc.t("cat.gold") % money(it.price), 21, GOLD_INK if it.price <= gold else RED_INK)
	tag.name = "Tag"
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(tag)
	if it.status == CatalogueItem.Status.AVAILABLE or it.status == CatalogueItem.Status.LOCKED:
		var btn := Button.new()
		btn.name = "Buy_" + it.id.validate_node_name()
		btn.text = Loc.t(it.action_key)
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(110, 40)
		btn.disabled = not it.can_buy(gold)
		btn.pressed.connect(_buy.bind(it))
		bottom.add_child(btn)
	return card


func _picture(it: CatalogueItem) -> Control:
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", _style(SKY, INK, 2, 12, 4))
	var tex: Texture2D = CatalogueIcons.texture(it.icon)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(96, 96)
		if it.status == CatalogueItem.Status.LOCKED:
			tr.modulate = Color(0.55, 0.55, 0.6)
		well.add_child(tr)
	else:
		var l: Label = _label(it.title.left(1).to_upper(), 46, INK)
		l.custom_minimum_size = Vector2(96, 96)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(l)
	return well


func _pips(tier: int, tiers: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Pips"
	row.add_theme_constant_override("separation", 4)
	for i in tiers:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(22, 12)
		p.add_theme_stylebox_override("panel", _style(Color(1.0, 0.75, 0.27) if i < tier else Color(1, 1, 1, 0.6), INK, 2, 5, 0))
		row.add_child(p)
	return row


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _style(fill: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	b.shadow_color = Color(0, 0, 0, 0.25)
	b.shadow_offset = Vector2(0, 3)
	b.shadow_size = 2 if width >= 3 else 0
	return b


## 12500 -> "12,500".
static func money(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
