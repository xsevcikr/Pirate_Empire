class_name CollectionScreen
extends PortScreen
## The collection book (F8): a page each for seashells, flags and ship cards. Found entries show their picture and
## how many were found; missing ones are a grey "?" card. The giants' ship cards are the rare ones.

const COLUMNS: int = 4
const CARD := Vector2(170, 180)
const INK := Color(0.16, 0.12, 0.2)
const PAPER := Color(0.99, 0.94, 0.8)
const PAPER_RARE := Color(1.0, 0.86, 0.55)
const MISSING := Color(0.78, 0.79, 0.84)

var page: String = "shells"


func _init() -> void:
	super()
	_title_key = "coll.title"
	dim = 0.6


func build() -> void:
	var s: Dictionary = state()
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in CollectionData.KINDS:
		var b := Button.new()
		b.text = Loc.t("coll.page_" + k) % [EasyPlay.kinds_owned(s, k), CollectionData.ids_of(k).size()]
		b.disabled = k == page
		b.pressed.connect(_set_page.bind(k))
		tabs.add_child(b)
	_box.add_child(tabs)
	var hint := Label.new()
	hint.text = Loc.t("coll.how_" + page)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(CARD.x * COLUMNS + 60.0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	_box.add_child(scroll)
	for id in CollectionData.ids_of(page):
		grid.add_child(_card(s, id))
	add_button("menu.back", close)


func _set_page(k: String) -> void:
	page = k
	_rebuild()


func _card(s: Dictionary, id: String) -> Control:
	var got: bool = EasyPlay.has_item(s, id)
	var rare: bool = CollectionData.is_rare_card(id) or id == "shell_pearl" or CollectionData.found_flag_ids().has(id)
	var card := PanelContainer.new()
	card.set_meta("kind", "collection_card")
	card.set_meta("owned", got)
	card.custom_minimum_size = CARD
	card.add_theme_stylebox_override("panel", CatalogueScreen._style((PAPER_RARE if rare else PAPER) if got else MISSING, INK, 3, 12, 8))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 110)
	v.add_child(pic)
	var tex: Texture2D = CatalogueIcons.texture(CollectionData.icon(id)) if got else null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(tr)
	else:
		var q := Label.new()
		q.text = "?" if not got else ""
		q.add_theme_font_size_override("font_size", 64)
		q.add_theme_color_override("font_color", Color(0.45, 0.46, 0.54))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(q)
	var name_l := Label.new()
	name_l.text = CollectionData.display_name(id) if got else Loc.t("coll.unknown")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_color_override("font_color", INK)
	name_l.add_theme_font_size_override("font_size", 16)
	v.add_child(name_l)
	if got:
		var n := Label.new()
		n.text = (Loc.t("coll.rare") + "  " if rare else "") + "x%d" % EasyPlay.count_of(s, id)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", Color(0.72, 0.45, 0.05) if rare else Color(0.4, 0.36, 0.46))
		n.add_theme_font_size_override("font_size", 14)
		v.add_child(n)
	return card
