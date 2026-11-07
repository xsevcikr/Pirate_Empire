class_name WantedBadge
extends Control
## Top-centre of the sea view: the captain's infamy rank and, while there is a price on the ship, five wanted stars
## (the lit ones for the biggest bounty) and the flag that posted it.

const STAR_R: float = 13.0
const STAR_GAP: float = 32.0
const LIT := Color(1.0, 0.78, 0.2)
const DARK := Color(0.12, 0.13, 0.22, 0.55)
const OUTLINE := Color(0.12, 0.08, 0.06)

var stars: int = 0
var faction: String = ""
var rank: String = "nobody"
var _t: float = 0.0


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -160.0
	offset_right = 160.0
	offset_top = 14.0
	offset_bottom = 100.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not Session.has_state():
		return
	_t = 0.5
	show_state(Session.state)


func show_state(state: Dictionary) -> void:
	var s: int = Bounty.stars(state)
	var f: String = Bounty.top_faction(state)
	var r: String = Bounty.rank_id(int(state.get("fame", 0)))
	if s != stars or f != faction or r != rank:
		stars = s
		faction = f
		rank = r
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var cx: float = size.x * 0.5
	_text(font, Loc.t("rank." + rank), Vector2(cx, 20), 18, Color(0.95, 0.9, 0.8))
	if stars <= 0:
		return
	_text(font, Loc.t("bounty.wanted_by") % Loc.t("faction." + faction), Vector2(cx, 44), 16, Color(1.0, 0.55, 0.45))
	for i in 5:
		var c := Vector2(cx + (float(i) - 2.0) * STAR_GAP, 68)
		var pts: PackedVector2Array = _star(c, STAR_R)
		draw_colored_polygon(pts, LIT if i < stars else DARK)
		pts.append(pts[0])
		draw_polyline(pts, OUTLINE, 2.5, true)


func _text(font: Font, t: String, centre: Vector2, fsize: int, col: Color) -> void:
	var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var at := Vector2(centre.x - w * 0.5, centre.y)
	draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 6, Color(0, 0, 0, 0.8))
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


static func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a: float = -PI * 0.5 + PI * float(k) / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	return pts
