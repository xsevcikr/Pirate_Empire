class_name StarIcon
extends Control
## A drawn five-pointed star (gold when earned, grey when not), since the UI font has no star glyph.

var lit: bool = true
const GOLD := Color(1.0, 0.78, 0.15)
const DIM := Color(0.55, 0.56, 0.64)
const INK := Color(0.16, 0.12, 0.2)


static func make(size_px: float, is_lit: bool = true) -> StarIcon:
	var s := StarIcon.new()
	s.lit = is_lit
	s.custom_minimum_size = Vector2(size_px, size_px)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r_out: float = minf(size.x, size.y) * 0.5
	var r_in: float = r_out * 0.45
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + PI * i / 5.0
		pts.append(c + Vector2.from_angle(a) * (r_out if i % 2 == 0 else r_in))
	draw_colored_polygon(pts, GOLD if lit else DIM)
	pts.append(pts[0])
	draw_polyline(pts, INK, maxf(1.5, r_out * 0.12), true)
