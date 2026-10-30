class_name WorldMapScreen
extends Control
## The chart: a parchment map of the archipelago with fog of war. Discovered islands show their name and city,
## known currents show as arrows, convoy lanes between discovered ports are dashed, and a click sets a course
## whose route and ETA are drawn. Pauses the game while open.

signal closed

const PARCHMENT := Color(0.86, 0.77, 0.58)
const FOG := Color(0.46, 0.38, 0.26)
const SEA_SEEN := Color(0.62, 0.74, 0.74)
const INK := Color(0.25, 0.16, 0.08)
const MARGIN_PX: float = 40.0

var chart: Chart
var discovery: Discovery
var player_pos: Vector2 = Vector2.ZERO
var player_heading: Vector2 = Vector2(0, -1)
var max_speed_kn: float = 11.0
var route: PackedVector2Array = PackedVector2Array()
var goal: Vector2 = Vector2.INF
var _rect: Rect2
var _font: Font


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_font = ThemeDB.fallback_font
	chart = Chart.new()
	discovery = SaveGame.restore_discovery(str(Session.state.get("discovery", "")))
	get_tree().paused = true
	var course: Array = Session.state.get("course", [])
	if course.size() == 2:
		set_goal(Vector2(float(course[0]), float(course[1])))
	queue_redraw()


func _layout() -> void:
	var side: float = minf(size.x, size.y) - MARGIN_PX * 2.0
	_rect = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func set_goal(p: Vector2) -> void:
	goal = p
	route = chart.route(player_pos, p)
	Session.state["course"] = [p.x, p.y]
	queue_redraw()


func clear_goal() -> void:
	goal = Vector2.INF
	route = PackedVector2Array()
	Session.state["course"] = []
	queue_redraw()


func eta_hours() -> float:
	return Chart.eta_hours(Chart.length_m(player_pos, route), max_speed_kn)


func island_known(isl: Dictionary) -> bool:
	return discovery.is_revealed(WorldMap.chunk_of(isl["pos"]))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_layout()
		if event.button_index == MOUSE_BUTTON_LEFT and _rect.has_point(event.position):
			set_goal(Chart.to_world(event.position, _rect))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_goal()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("world_map") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.04))
	draw_rect(_rect.grow(10.0), PARCHMENT.darkened(0.25))
	draw_rect(_rect, FOG)
	var cell: Vector2 = _rect.size / float(WorldMap.CHUNKS)
	for cz in WorldMap.CHUNKS:
		for cx in WorldMap.CHUNKS:
			if discovery.is_revealed(Vector2i(cx, cz)):
				draw_rect(Rect2(_rect.position + Vector2(cx, cz) * cell, cell + Vector2.ONE), SEA_SEEN.lerp(PARCHMENT, 0.25 + 0.1 * float((cx + cz) % 2)))
	for rid in WorldMap.REGIONS:
		var r: Rect2 = WorldMap.REGIONS[rid]["rect"]
		var a: Vector2 = Chart.to_screen(r.position, _rect)
		var b: Vector2 = Chart.to_screen(r.end, _rect)
		draw_rect(Rect2(a, b - a), INK.lerp(PARCHMENT, 0.7), false, 1.0)
		if discovery.is_revealed(WorldMap.chunk_of(r.get_center())):
			_label(Loc.t("region." + rid), (a + b) * 0.5 - Vector2(60, 0), 14, INK.lerp(PARCHMENT, 0.35))
	_draw_currents()
	_draw_lanes()
	for isl in chart.gen.islands:
		_draw_island(isl)
	_draw_route()
	_draw_player()
	_label(Loc.t("map.title"), Vector2(_rect.position.x, _rect.position.y - 14.0), 22, PARCHMENT)
	_label(Loc.t("map.help"), Vector2(_rect.position.x, _rect.end.y + 28.0), 16, PARCHMENT)
	if goal != Vector2.INF:
		var txt: String = Loc.t("map.no_route")
		if not route.is_empty():
			txt = Loc.t("map.eta") % [Chart.length_m(player_pos, route) / 1852.0, Chart.eta_text(eta_hours())]
		_label(txt, Vector2(_rect.end.x - 360.0, _rect.position.y - 14.0), 18, PARCHMENT)


func _draw_island(isl: Dictionary) -> void:
	if not island_known(isl):
		return
	var c: Vector2 = Chart.to_screen(isl["pos"], _rect)
	var look: Dictionary = IslandData.biome(isl["biome"])
	var r: float = maxf(float(isl["radius"]) / WorldMap.SIZE_M * _rect.size.x * 1.2, 5.0)
	draw_circle(c, r + 2.0, INK.lerp(PARCHMENT, 0.4))
	draw_circle(c, r, (look["grass"] as Color).lerp(look["sand"], 0.4))
	_label(isl["name"], c + Vector2(r + 5.0, -2.0), 14, INK)
	if isl["city"] != "":
		var faction: String = str(WorldMap.REGIONS[isl["region"]]["faction"])
		var col: Color = IslandData.style(faction)["flag"]
		var port: Vector2 = Chart.to_screen(PortData.PORTS[IslandData.port_id_of(isl["city"])]["dock"], _rect)
		draw_rect(Rect2(port - Vector2(4, 4), Vector2(8, 8)), col)
		draw_rect(Rect2(port - Vector2(4, 4), Vector2(8, 8)), INK, false, 1.5)
	elif Landings.has_landing(isl):  # a beach landing, no harbour: a hollow ring
		var g: WorldGen = PortData.gen()
		var at: Vector2 = Chart.to_screen(Landings.anchorage(g, g.index_of(isl["name"])), _rect)
		draw_arc(at, 4.5, 0.0, TAU, 12, INK, 2.0)


func _draw_lanes() -> void:
	for c: Dictionary in Session.state.get("convoys", []):
		var a: Dictionary = PortData.PORTS[c["from"]]
		var b: Dictionary = PortData.PORTS[c["to"]]
		if not (discovery.is_revealed(WorldMap.chunk_of(a["dock"])) and discovery.is_revealed(WorldMap.chunk_of(b["dock"]))):
			continue
		_dashed(Chart.to_screen(a["dock"], _rect), Chart.to_screen(b["dock"], _rect), INK.lerp(PARCHMENT, 0.55), 1.5)


func _draw_currents() -> void:
	var known: Array = Session.state.get("streams_known", [])
	for s in OceanCurrent.STREAMS:
		if not known.has(s["id"]):
			continue
		var a: Vector2 = Chart.to_screen(s["from"], _rect)
		var b: Vector2 = Chart.to_screen(s["to"], _rect)
		var col := Color(0.2, 0.4, 0.6, 0.8)
		draw_line(a, b, col, 3.0)
		var dir: Vector2 = (b - a).normalized()
		var mid: Vector2 = (a + b) * 0.5
		draw_colored_polygon(PackedVector2Array([mid + dir * 10.0, mid - dir * 6.0 + dir.orthogonal() * 7.0, mid - dir * 6.0 - dir.orthogonal() * 7.0]), col)
		_label("%.1f kn" % float(s["kn"]), mid + Vector2(8, -8), 12, col.darkened(0.3))


func _draw_route() -> void:
	if goal == Vector2.INF or route.is_empty():
		return
	var at: Vector2 = Chart.to_screen(player_pos, _rect)
	for w in route:
		var nxt: Vector2 = Chart.to_screen(w, _rect)
		_dashed(at, nxt, Color(0.7, 0.1, 0.1), 3.0)
		at = nxt
	var g: Vector2 = Chart.to_screen(goal, _rect)
	draw_line(g - Vector2(7, 7), g + Vector2(7, 7), Color(0.7, 0.1, 0.1), 3.0)
	draw_line(g - Vector2(7, -7), g + Vector2(7, -7), Color(0.7, 0.1, 0.1), 3.0)


func _draw_player() -> void:
	var p: Vector2 = Chart.to_screen(player_pos, _rect)
	var d: Vector2 = player_heading.normalized()
	draw_colored_polygon(PackedVector2Array([p + d * 11.0, p - d * 7.0 + d.orthogonal() * 6.0, p - d * 7.0 - d.orthogonal() * 6.0]), Color(0.75, 0.1, 0.1))
	_label(Loc.t("map.you"), p + Vector2(10, 14), 13, Color(0.6, 0.05, 0.05))


func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var len: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / maxf(len, 0.001)
	var t: float = 0.0
	while t < len:
		draw_line(a + dir * t, a + dir * minf(t + 8.0, len), col, width)
		t += 14.0


func _label(text: String, at: Vector2, font_size: int, col: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, col)
