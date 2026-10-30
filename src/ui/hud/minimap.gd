class_name Minimap
extends CanvasLayer
## The round minimap in the top-left corner: the waters around the ship, north up. Known islands, harbours and
## beach landings, every other ship as a coloured arrow, the set course, and home (the lagoon on Skull Atoll)
## always marked, pinned to the rim with its distance when it is out of range. Click it to zoom out and in.

const DIAMETER_PX: float = 260.0
const MARGIN_PX: float = 20.0
const BOTTOM_PX: float = MARGIN_PX + DIAMETER_PX + 34.0  ## where the HUD below it may start
const SEA := Color(0.1, 0.24, 0.32, 0.9)
const RIM := Color(0.55, 0.4, 0.22)
const INK := Color(0.15, 0.1, 0.05)
const HOME := Color(1.0, 0.8, 0.2)
const COURSE := Color(0.9, 0.2, 0.15)

var ship: Ship
var world: Node  ## the world scene, for its discovery map; may be null in tests
var range_index: int = 1
var _gen: WorldGen
var _discovery: Discovery
var _disc: Control  ## the round sea; it clips what is drawn on it
var _content: Control  ## islands, ports and ships, clipped to the disc
var _top: Control  ## rim, north mark, player and home markers: never clipped
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
	_top.size = Vector2(DIAMETER_PX, DIAMETER_PX + 24.0)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.tooltip_text = Loc.t("minimap.zoom_tip")
	_top.gui_input.connect(_on_input)
	_top.draw.connect(_draw_top)
	add_child(_top)


func range_m() -> float:
	return MinimapMath.RANGES_M[range_index]


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		range_index = MinimapMath.next_range(range_index)
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
	_disc.draw_circle(Vector2(_radius(), _radius()), _radius(), SEA)


func _draw_content() -> void:
	var c: Vector2 = Vector2(_radius(), _radius())
	var px_per_m: float = _radius() / range_m()
	for ring in [0.5, 1.0]:  # range rings
		_content.draw_arc(c, _radius() * ring, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.0)
	for i in _gen.islands.size():
		var isl: Dictionary = _gen.islands[i]
		var p: Vector2 = _at(isl["pos"])
		var r: float = maxf(float(isl["radius"]) * px_per_m, 3.5)
		if not MinimapMath.touches(p - c, r, _radius()):
			continue
		if not _known(isl["pos"]) and str(isl["name"]) != LagoonData.ISLAND:
			continue
		var look: Dictionary = IslandData.biome(isl["biome"])
		_content.draw_circle(p, r + 1.5, (look["sand"] as Color).darkened(0.2))
		_content.draw_circle(p, r, (look["grass"] as Color).lerp(look["sand"], 0.3))
		if isl["city"] != "":
			var faction: String = str(WorldMap.REGIONS[isl["region"]]["faction"])
			var dock: Vector2 = _at(PortData.PORTS[IslandData.port_id_of(isl["city"])]["dock"])
			_content.draw_rect(Rect2(dock - Vector2(3.5, 3.5), Vector2(7, 7)), IslandData.style(faction)["flag"])
			_content.draw_rect(Rect2(dock - Vector2(3.5, 3.5), Vector2(7, 7)), Color.WHITE, false, 1.0)
			if range_index < MinimapMath.RANGES_M.size() - 1:
				_label(_content, isl["city"], dock + Vector2(6, -4), 11, Color(1, 1, 1, 0.9))
		elif Landings.has_landing(isl):
			_content.draw_arc(_at(Landings.anchorage(_gen, i)), 3.5, 0.0, TAU, 10, Color.WHITE, 1.5)
	var course: Array = Session.state.get("course", []) if Session.has_state() else []
	if course.size() == 2:
		var g: Vector2 = _at(Vector2(float(course[0]), float(course[1])))
		_content.draw_line(c, g, Color(COURSE, 0.6), 1.5)
		_content.draw_line(g - Vector2(4, 4), g + Vector2(4, 4), COURSE, 2.0)
		_content.draw_line(g - Vector2(4, -4), g + Vector2(4, -4), COURSE, 2.0)
	for n in ship.get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == ship or s.damage == null or s.damage.sunk:
			continue
		var at: Vector2 = _at(Vector2(s.global_position.x, s.global_position.z))
		if MinimapMath.touches(at - c, 4.0, _radius()):
			_arrow(_content, at, s.heading(), 6.5, MinimapMath.ship_colour(s.faction))


func _draw_top() -> void:
	var c: Vector2 = Vector2(_radius(), _radius())
	_top.draw_arc(c, _radius(), 0.0, TAU, 64, RIM, 4.0)
	_top.draw_arc(c, _radius() + 2.0, 0.0, TAU, 64, INK, 1.5)
	_top.draw_circle(c + Vector2(0, -_radius()), 9.0, RIM)
	_label(_top, "N", c + Vector2(-4.5, -_radius() + 5.0), 13, Color.WHITE)
	# home: a gold star, on the rim with distance and bearing when it is out of range
	var home: Vector2 = MinimapMath.home_pos()
	var off: Vector2 = MinimapMath.to_map(home, _centre(), range_m(), _radius())
	var pinned: Vector2 = MinimapMath.pin_to_rim(off, _radius(), 8.0)
	_star(c + pinned, 7.0 if pinned == off else 6.0)
	var txt: String = Loc.t("minimap.home")
	if pinned != off:
		txt = Loc.t("minimap.home_far") % MinimapMath.bearing_text(_centre(), home)
	var tpos: Vector2 = c + pinned + Vector2(9, 4)
	if pinned.x > _radius() * 0.3:  # keep the label on the inside of the rim
		tpos.x -= 18.0 + _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_label(_top, txt, tpos, 12, HOME)
	_arrow(_top, c, ship.heading(), 8.5, MinimapMath.ship_colour("player"))
	_label(_top, "%.1f km" % (range_m() / 1000.0), Vector2(_radius() - 18.0, DIAMETER_PX + 18.0), 12, Color(1, 1, 1, 0.75))


func _arrow(on: Control, at: Vector2, dir: Vector2, s: float, col: Color) -> void:
	var f: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
	var side: Vector2 = f.orthogonal()
	var pts := PackedVector2Array([at + f * s * 1.4, at - f * s + side * s * 0.8, at - f * s * 0.5, at - f * s - side * s * 0.8])
	on.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	on.draw_polyline(pts, INK, 1.0)


func _star(at: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a: float = -PI * 0.5 + float(k) * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	_top.draw_colored_polygon(pts, HOME)
	pts.append(pts[0])
	_top.draw_polyline(pts, INK, 1.2)


func _label(on: Control, text: String, pos: Vector2, size: int, col: Color) -> void:
	on.draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	on.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
