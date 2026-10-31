class_name Minimap
extends CanvasLayer
## The round sea chart in the top-left corner, north up and centred on the ship. It looks like an old parchment
## chart: islands with their real coastlines, beaches and green land, island names, harbours as little houses in
## their flag colour, every other ship as an arrow, the set course, and home (the lagoon on Skull Atoll) as a gold
## star that stays pinned to the rim with its distance when it is out of range. Click the chart to open the big
## chart; the + and - buttons under it zoom.

const DIAMETER_PX: float = 260.0
const MARGIN_PX: float = 30.0
const BOTTOM_PX: float = MARGIN_PX + DIAMETER_PX + 40.0  ## where the HUD below it may start
const RIGHT_PX: float = MARGIN_PX + DIAMETER_PX + 12.0  ## where a panel beside it may start
const SEA := Color(0.71, 0.8, 0.76)  ## sea on parchment
const PAPER := Color(0.93, 0.86, 0.68)
const WOOD := Color(0.45, 0.28, 0.14)
const TRIM := Color(0.95, 0.75, 0.3)
const INK := Color(0.25, 0.16, 0.08)
const HOME := Color(1.0, 0.8, 0.2)
const COURSE := Color(0.75, 0.12, 0.1)
const NAME_MIN_PX: float = 12.0  ## an island this small on the chart keeps its name to itself

var ship: Ship
var world: Node  ## the world scene, for its discovery map and the big chart; may be null in tests
var range_index: int = 1
var _gen: WorldGen
var _discovery: Discovery
var _disc: Control  ## the round sea; it clips what is drawn on it
var _content: Control  ## islands, ports and ships, clipped to the disc
var _top: Control  ## rim, compass, player and home markers: never clipped
var _font: Font


func _ready() -> void:
	layer = 5
	_font = ThemeDB.fallback_font
	_gen = PortData.gen()
	_disc = Control.new()
	_disc.position = Vector2(MARGIN_PX, MARGIN_PX)
	_disc.size = Vector2(DIAMETER_PX, DIAMETER_PX)
	_disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.draw.connect(_draw_disc)
	add_child(_disc)
	_content = Control.new()
	_content.size = _disc.size
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.draw.connect(_draw_content)
	_disc.add_child(_content)
	_top = Control.new()
	_top.position = _disc.position
	_top.size = Vector2(DIAMETER_PX, DIAMETER_PX)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_top.tooltip_text = Loc.t("minimap.open_tip")
	_top.gui_input.connect(_on_input)
	_top.draw.connect(_draw_top)
	add_child(_top)
	var zoom := HBoxContainer.new()
	zoom.position = Vector2(MARGIN_PX + DIAMETER_PX * 0.5 - 52.0, MARGIN_PX + DIAMETER_PX + 4.0)
	zoom.add_theme_constant_override("separation", 6)
	add_child(zoom)
	zoom.add_child(_zoom_button("-", 1))
	zoom.add_child(_zoom_button("+", -1))


func _zoom_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(46, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Loc.t("minimap.zoom_tip")
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	for st in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER if st == "normal" else (PAPER.lightened(0.2) if st == "hover" else TRIM)
		box.border_color = WOOD
		box.set_border_width_all(3)
		box.set_corner_radius_all(8)
		b.add_theme_stylebox_override(st, box)
	b.pressed.connect(func() -> void: zoom(step))
	return b


## step +1 shows more sea (zoom out), -1 less (zoom in).
func zoom(step: int) -> void:
	range_index = clampi(range_index + step, 0, MinimapMath.RANGES_M.size() - 1)


func range_m() -> float:
	return MinimapMath.RANGES_M[range_index]


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if world != null and world.has_method("open_map"):
				world.open_map()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1)
		_top.accept_event()


func _process(_delta: float) -> void:
	var on: bool = ship != null and is_instance_valid(ship)
	visible = on
	if not on:
		return
	_content.queue_redraw()
	_top.queue_redraw()


func _centre() -> Vector2:
	return Vector2(ship.global_position.x, ship.global_position.z)


func _radius() -> float:
	return DIAMETER_PX * 0.5


func _at(world_p: Vector2) -> Vector2:
	return Vector2(_radius(), _radius()) + MinimapMath.to_map(world_p, _centre(), range_m(), _radius())


func _known(p: Vector2) -> bool:
	var d: Variant = world.get("discovery") if world != null else null
	if d is Discovery:
		_discovery = d
	elif _discovery == null and Session.has_state():
		_discovery = SaveGame.restore_discovery(str(Session.state.get("discovery", "")))
	return _discovery == null or _discovery.is_revealed(WorldMap.chunk_of(p))


func _draw_disc() -> void:
	var c := Vector2(_radius(), _radius())
	_disc.draw_circle(c, _radius(), PAPER)
	_disc.draw_circle(c, _radius() - 3.0, SEA)


func _draw_content() -> void:
	var c: Vector2 = Vector2(_radius(), _radius())
	var px_per_m: float = _radius() / range_m()
	# chart grid: faint ink lines, fixed to the world so they slide past as the ship sails
	var step_m: float = range_m() / 3.0
	var origin: Vector2 = _centre()
	var gx: float = floorf((origin.x - range_m()) / step_m) * step_m
	while gx <= origin.x + range_m():
		var x: float = _at(Vector2(gx, 0)).x
		_content.draw_line(Vector2(x, 0), Vector2(x, DIAMETER_PX), Color(INK, 0.12), 1.0)
		gx += step_m
	var gz: float = floorf((origin.y - range_m()) / step_m) * step_m
	while gz <= origin.y + range_m():
		var y: float = _at(Vector2(0, gz)).y
		_content.draw_line(Vector2(0, y), Vector2(DIAMETER_PX, y), Color(INK, 0.12), 1.0)
		gz += step_m
	var names: Array = []
	for i in _gen.islands.size():
		var isl: Dictionary = _gen.islands[i]
		var p: Vector2 = _at(isl["pos"])
		var grow: float = MinimapMath.island_grow(float(isl["radius"]) * px_per_m)
		var r: float = float(isl["radius"]) * 1.3 * px_per_m * grow
		if not MinimapMath.touches(p - c, maxf(r, 4.0), _radius()):
			continue
		if not _known(isl["pos"]) and str(isl["name"]) != LagoonData.ISLAND:
			continue
		var look: Dictionary = IslandData.biome(isl["biome"])
		var to_screen: Callable = func(w: Vector2) -> Vector2: return p + (_at(w) - p) * grow
		IslandShape.draw(_content, IslandShape.of(i, isl), look, to_screen, INK, px_per_m * grow)
		if isl["city"] != "":
			var faction: String = str(WorldMap.REGIONS[isl["region"]]["faction"])
			var dock: Vector2 = to_screen.call(PortData.PORTS[IslandData.port_id_of(isl["city"])]["dock"])
			IslandShape.draw_harbour(_content, dock, IslandData.style(faction)["flag"], INK, 5.0)
			names.append([str(isl["city"]), dock + Vector2(8, 4), true])
		elif Landings.has_landing(isl):
			_content.draw_arc(to_screen.call(Landings.anchorage(_gen, i)), 4.0, 0.0, TAU, 12, INK, 1.8)
		if r >= NAME_MIN_PX and isl["city"] == "":
			names.append([str(isl["name"]), p + Vector2(-_text_w(str(isl["name"]), 11) * 0.5, -r * 0.55 - 4.0), false])
	var course: Array = Session.state.get("course", []) if Session.has_state() else []
	if course.size() == 2:
		var g: Vector2 = _at(Vector2(float(course[0]), float(course[1])))
		_dashed(c, g, Color(COURSE, 0.8), 2.0)
		_content.draw_line(g - Vector2(5, 5), g + Vector2(5, 5), COURSE, 2.5)
		_content.draw_line(g - Vector2(5, -5), g + Vector2(5, -5), COURSE, 2.5)
	for n in ship.get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == ship or s.damage == null or s.damage.sunk:
			continue
		var at: Vector2 = _at(Vector2(s.global_position.x, s.global_position.z))
		if MinimapMath.touches(at - c, 4.0, _radius()):
			IslandShape.draw_arrow(_content, at, s.heading(), 6.0, MinimapMath.ship_colour(s.faction), INK)
	for nm in names:  # names last, so no island covers another's name
		_label(_content, nm[0], nm[1], 12 if nm[2] else 11, INK if not nm[2] else Color(0.45, 0.08, 0.05))


func _draw_top() -> void:
	var c: Vector2 = Vector2(_radius(), _radius())
	# a wooden frame with a gold trim
	_top.draw_arc(c, _radius() + 1.0, 0.0, TAU, 72, WOOD, 7.0, true)
	_top.draw_arc(c, _radius() - 2.5, 0.0, TAU, 72, TRIM, 1.5, true)
	_top.draw_arc(c, _radius() + 4.5, 0.0, TAU, 72, INK, 1.5, true)
	# compass points on the frame
	for k in 4:
		var dir: Vector2 = Vector2.from_angle(-PI * 0.5 + k * PI * 0.5)
		var at: Vector2 = c + dir * (_radius() + 1.0)
		var side: Vector2 = dir.orthogonal()
		var col: Color = Color(0.8, 0.15, 0.1) if k == 0 else TRIM
		_top.draw_colored_polygon(PackedVector2Array([at + dir * 9.0, at + side * 6.0 - dir * 4.0, at - side * 6.0 - dir * 4.0]), col)
	_top.draw_circle(c + Vector2(0, -_radius() - 15.0), 11.0, WOOD)
	_top.draw_arc(c + Vector2(0, -_radius() - 15.0), 11.0, 0.0, TAU, 24, TRIM, 2.0, true)
	_label(_top, "N", c + Vector2(-5.0, -_radius() - 9.5), 15, Color.WHITE)
	# home: a gold star, on the rim with distance and bearing when it is out of range
	var home: Vector2 = MinimapMath.home_pos()
	var off: Vector2 = MinimapMath.to_map(home, _centre(), range_m(), _radius())
	var pinned: Vector2 = MinimapMath.pin_to_rim(off, _radius(), 12.0)
	IslandShape.draw_star(_top, c + pinned, 9.0 if pinned == off else 8.0, HOME, INK)
	var txt: String = Loc.t("minimap.home")
	if pinned != off:
		txt = Loc.t("minimap.home_far") % MinimapMath.bearing_text(_centre(), home)
	var tpos: Vector2 = c + pinned + Vector2(11, 5)
	if pinned.x > _radius() * 0.3:  # keep the label on the inside of the rim
		tpos.x -= 22.0 + _text_w(txt, 12)
	_label(_top, txt, tpos, 12, Color(0.55, 0.35, 0.0))
	# you: a white ship arrow with a red outline, always in the middle
	IslandShape.draw_arrow(_top, c, ship.heading(), 9.0, Color.WHITE, Color(0.75, 0.1, 0.08))
	_label(_top, "%.1f km" % (range_m() / 1000.0), Vector2(DIAMETER_PX - 30.0, DIAMETER_PX - 2.0), 12, INK)


func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var len: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / maxf(len, 0.001)
	var t: float = 0.0
	while t < len:
		_content.draw_line(a + dir * t, a + dir * minf(t + 6.0, len), col, width)
		t += 11.0


func _text_w(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Ink lettering with a pale paper halo, so names read over sea and land alike.
func _label(on: Control, text: String, pos: Vector2, size: int, col: Color) -> void:
	on.draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(PAPER, 0.9))
	on.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
