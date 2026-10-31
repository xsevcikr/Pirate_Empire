class_name StatusPanel
extends CanvasLayer
## The captain's status board in the top-left, beside the sea chart: hearts (the captain's health, one heart is
## one bottle of rum), gold coins, and a bar for the ship's hull, crew, cannonballs, rum, food and water. Bars are
## green, turn yellow when something runs low and red, pulsing, when it is about to run out. The pictures are
## Kenney models rendered to icons (assets/icons/catalogue).

const ICONS: Dictionary = {
	"gold": "dungeon/coin", "hull": "pirate/ship-pirate-small", "crew": "characters/character-a",
	"ammo": "pirate/cannon-ball", "rum": "pirate/bottle", "food": "nature/crop_pumpkin", "water": "pirate/barrel",
}
## Tints that make the icons read at a glance (the barrel is the water cask, the bottle amber rum).
const TINTS: Dictionary = {"rum": Color(1.0, 0.8, 0.55), "food": Color(1.0, 0.72, 0.4), "water": Color(0.7, 0.88, 1.0)}
const PAPER := Color(0.93, 0.86, 0.68, 0.95)
const WOOD := Color(0.45, 0.28, 0.14)
const INK := Color(0.25, 0.16, 0.08)
const ICON_PX: float = 30.0
const BAR_W: float = 104.0
const BAR_H: float = 14.0
const REFRESH_S: float = 0.2

var ship: Ship
var _box: PanelContainer
var _hearts: Control
var _hp_label: Label
var _gold: Label
var _rows: Dictionary = {}  ## id -> {"bar": Control, "label": Label, "icon": TextureRect}
var _data: Dictionary = {}
var _heart: Dictionary = {"total": 4, "halves": 8, "level": StatusMath.OK}
var _t: float = 0.0
var _refresh: float = 0.0


func _ready() -> void:
	layer = 5
	_box = PanelContainer.new()
	_box.position = Vector2(Minimap.RIGHT_PX + 8.0, 14.0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = WOOD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(2, 3)
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_box.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	_hearts = Control.new()
	_hearts.custom_minimum_size = Vector2(4 * 30.0, 26.0)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts.draw.connect(_draw_hearts)
	top.add_child(_hearts)
	_hp_label = _text(14)
	top.add_child(_hp_label)
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 6)
	col.add_child(money)
	money.add_child(_icon("gold"))
	_gold = _text(22)
	_gold.add_theme_color_override("font_color", Color(0.6, 0.4, 0.0))
	money.add_child(_gold)
	for id in StatusMath.ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var icon: TextureRect = _icon(id)
		row.add_child(icon)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(BAR_W, ICON_PX)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_bar.bind(id, bar))
		row.add_child(bar)
		var label: Label = _text(16)
		label.custom_minimum_size = Vector2(62, 0)
		row.add_child(label)
		_rows[id] = {"bar": bar, "label": label, "icon": icon}
		row.tooltip_text = Loc.t("status." + id)
		row.mouse_filter = Control.MOUSE_FILTER_PASS


func _icon(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = CatalogueIcons.texture(ICONS[id])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	t.pivot_offset = Vector2(ICON_PX, ICON_PX) * 0.5
	t.modulate = TINTS.get(id, Color.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _text(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _process(delta: float) -> void:
	var on: bool = ship != null and is_instance_valid(ship) and Session.has_state()
	visible = on
	if not on:
		return
	_t += delta
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_S
		refresh()
	var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
	for id in _rows:
		var r: Dictionary = _rows[id]
		var danger: bool = _data.has(id) and int(_data[id]["level"]) == StatusMath.DANGER
		var s: float = 1.0 + (0.18 * pulse if danger else 0.0)
		(r["icon"] as TextureRect).scale = Vector2(s, s)
		(r["bar"] as Control).queue_redraw()
	_hearts.queue_redraw()


## Reads the ship and the game state into the rows.
func refresh() -> void:
	var st: Dictionary = Session.state
	var b: Broadside = ship.broadside
	var info: Dictionary = {
		"hull": ship.damage.hull_fraction() if ship.damage != null else 1.0,
		"crew": ship.crew.count, "crew_min": ship.stats.crew_min, "crew_max": ship.stats.crew_max,
		"ammo": int(b.ammo.get(b.ammo_id, 0)) if b != null else 0, "guns": b.gun_count() if b != null else 1,
	}
	_data = StatusMath.rows(st, info)
	var hp: float = CaptainHealth.hp(st)
	_heart = StatusMath.hearts(hp)
	_hp_label.text = "%d/%d" % [ceili(hp), roundi(DeckData.FIGHTER_HP)]
	_gold.text = str(int(st.get("gold", 0)))
	for id in _rows:
		(_rows[id]["label"] as Label).text = str(_data[id]["text"])


## A rounded bar with a dark outline (the Kenney UI look); a red bar pulses.
func _draw_bar(id: String, bar: Control) -> void:
	if not _data.has(id):
		return
	var d: Dictionary = _data[id]
	var y: float = (ICON_PX - BAR_H) * 0.5
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.35, 0.25, 0.15, 0.45)
	back.set_corner_radius_all(int(BAR_H * 0.5))
	back.border_color = INK
	back.set_border_width_all(2)
	back.draw(bar.get_canvas_item(), Rect2(0, y, BAR_W, BAR_H))
	var frac: float = float(d["frac"])
	if frac <= 0.0:
		return
	var col: Color = StatusMath.colour(int(d["level"]))
	if int(d["level"]) == StatusMath.DANGER:
		col = col.lightened(0.35 * (0.5 + 0.5 * sin(_t * 6.0)))
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(BAR_H * 0.5) - 2)
	var w: float = maxf((BAR_W - 4.0) * frac, BAR_H - 4.0)
	fill.draw(bar.get_canvas_item(), Rect2(2, y + 2, w, BAR_H - 4))
	bar.draw_line(Vector2(6, y + 4), Vector2(maxf(w - 4.0, 6.0), y + 4), Color(1, 1, 1, 0.35), 2.0)  # shine


func _draw_hearts() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
	var low: bool = int(_heart["level"]) == StatusMath.DANGER
	for k in int(_heart["total"]):
		var c := Vector2(13.0 + 30.0 * k, 12.0)
		var s: float = 0.95 * (1.0 + (0.12 * pulse if low else 0.0))
		var whole: PackedVector2Array = heart_points(c, s, false)
		_hearts.draw_colored_polygon(whole, Color(0.45, 0.35, 0.3, 0.45))
		var filled: int = clampi(int(_heart["halves"]) - k * 2, 0, 2)
		var red := Color(0.9, 0.15, 0.2) if not low else Color(0.9, 0.15, 0.2).lightened(0.3 * pulse)
		if filled == 2:
			_hearts.draw_colored_polygon(whole, red)
		elif filled == 1:
			_hearts.draw_colored_polygon(heart_points(c, s, true), red)
		var line: PackedVector2Array = whole.duplicate()
		line.append(whole[0])
		_hearts.draw_polyline(line, INK, 2.0, true)
		if filled == 2:
			_hearts.draw_circle(c + Vector2(-5, -5) * s * 1.2, 2.2 * s * 1.4, Color(1, 1, 1, 0.55))


## A heart outline around `c`; `left_half` gives only its left half (for a half heart).
static func heart_points(c: Vector2, s: float, left_half: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = 28
	var from: int = n / 2 if left_half else 0
	for i in range(from, n + 1 if left_half else n):
		var t: float = TAU * float(i) / float(n)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 2.0) * s * 0.8)
	return pts
