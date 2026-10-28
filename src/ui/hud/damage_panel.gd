class_name DamagePanel
extends CanvasLayer
## Damage control on the HUD. A small top-down plan of the ship shows each section's hull (green to red), the
## water in it (blue), every hole (red while open, grey stuffed, white fothered, brown patched) and the masts.
## It pops up by itself when the ship is hurt; Z opens the full panel where the player sends hands to the pumps,
## the holes, the fires, the rigging and the hull, or leaves it to the bosun ("auto").

const W: float = 470.0
const H_SMALL: float = 210.0
const H_FULL: float = 390.0
const PLAN_W: float = 92.0
const PLAN_H: float = 180.0
const SHOW_HOLD_S: float = 8.0  ## the small panel stays this long after the last of the damage is dealt with

var world: Node
var expanded: bool = false
var _root: Control
var _plan: Control
var _text: Label
var _jobs: VBoxContainer
var _auto_btn: Button
var _rows: Dictionary = {}  # job -> {label, minus, plus}
var _calm_s: float = 99.0
var _t: float = 0.0


func _ready() -> void:
	layer = 6
	_root = PanelContainer.new()
	_root.name = "DamagePanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.72)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	_root.add_theme_stylebox_override("panel", sb)
	_root.anchor_top = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = 24.0
	_root.offset_right = 24.0 + W
	add_child(_root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_root.add_child(row)
	_plan = Control.new()
	_plan.custom_minimum_size = Vector2(PLAN_W, PLAN_H)
	_plan.draw.connect(_draw_plan)
	row.add_child(_plan)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_text = _label(17)
	col.add_child(_text)
	_jobs = VBoxContainer.new()
	_jobs.add_theme_constant_override("separation", 2)
	col.add_child(_jobs)
	_auto_btn = Button.new()
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.pressed.connect(func() -> void:
		var dc: DamageControl = _control()
		if dc != null:
			dc.auto = not dc.auto
			Sfx.play("ui_click"))
	_jobs.add_child(_auto_btn)
	for job in DamageControl.JOBS:
		var r := HBoxContainer.new()
		var l: Label = _label(16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var minus := _small_button("-", _nudge.bind(job, -1))
		var plus := _small_button("+", _nudge.bind(job, 1))
		r.add_child(minus)
		r.add_child(plus)
		_jobs.add_child(r)
		_rows[job] = {"label": l, "minus": minus, "plus": plus}
	_layout()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(30, 26)
	b.pressed.connect(cb)
	return b


func _nudge(job: String, d: int) -> void:
	var dc: DamageControl = _control()
	if dc == null:
		return
	if dc.auto:  # taking the helm from the bosun starts from what he had set
		var w: Dictionary = dc.auto_weights()
		for j in DamageControl.JOBS:
			dc.weights[j] = int(w.get(j, 0))
	dc.set_weight(job, int(dc.weights.get(job, 0)) + d)
	Sfx.play("ui_click")


func _layout() -> void:
	var h: float = H_FULL if expanded else H_SMALL
	_root.offset_top = -150.0 - h
	_root.offset_bottom = -150.0
	_jobs.visible = expanded


func _ship() -> Ship:
	return world.get("ship") as Ship if world != null else null


func _control() -> DamageControl:
	var s: Ship = _ship()
	return s.damage.control if s != null and s.damage != null else null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("damage_control"):
		expanded = not expanded
		_layout()
		get_viewport().set_input_as_handled()


## Anything the crew could be working on: holes, water, fire, a fallen mast.
static func hurt(d: DamageModel) -> bool:
	return d.open_breach_count() > 0 or d.water_total() > 0.05 or d.fires_burning() > 0 or d.mast_down.has(true)


func _process(delta: float) -> void:
	_t += delta
	var s: Ship = _ship()
	if s == null or s.damage == null:
		_root.visible = false
		return
	var d: DamageModel = s.damage
	_calm_s = 0.0 if hurt(d) else _calm_s + delta
	_root.visible = expanded or _calm_s < SHOW_HOLD_S
	if not _root.visible:
		return
	_plan.queue_redraw()
	var dc: DamageControl = d.control
	var lines: PackedStringArray = []
	lines.append(Loc.t("dmg.title") % [int(d.hull_fraction() * 100.0), int(d.flood_fraction() * 100.0)])
	var patched: int = d.breaches.size() - d.open_breach_count()
	lines.append(Loc.t("dmg.holes") % [d.open_breach_count(), patched, d.leak_total()])
	if dc != null:
		lines.append(Loc.t("dmg.stores") % [int(dc.have("timber")), int(dc.have("canvas")), dc.have("tools")])
		var busy: PackedStringArray = []
		for job in DamageControl.JOBS:
			if float(dc.hands_on.get(job, 0.0)) >= 0.5:
				busy.append("%s %d" % [Loc.t("dmg.job." + job), roundi(dc.hands_on[job])])
		lines.append(Loc.t("dmg.hands") % (", ".join(busy) if not busy.is_empty() else Loc.t("dmg.idle")))
		if dc.patch_progress() > 0.0:
			lines.append(Loc.t("dmg.patching") % int(dc.patch_progress() * 100.0))
		if not expanded:
			lines.append(Loc.t("dmg.open_hint"))
	_text.text = "\n".join(lines)
	if expanded and dc != null:
		_auto_btn.text = Loc.t("dmg.auto_on" if dc.auto else "dmg.auto_off")
		var w: Dictionary = dc.auto_weights() if dc.auto else dc.weights
		for job in DamageControl.JOBS:
			var r: Dictionary = _rows[job]
			var n: int = int(w.get(job, 0))
			var bar: String = "■".repeat(n) + "□".repeat(DamageControl.MAX_WEIGHT - n)
			var work: String = "" if dc.has_work(job) else "  · " + Loc.t("dmg.nothing")
			(r["label"] as Label).text = "%s  %s  %d%s" % [Loc.t("dmg.job." + job), bar, roundi(dc.hands_on.get(job, 0.0)), work]


## Top-down plan, bow up. Four-section ships: bow, port and starboard halves, stern; eight-section ships split
## the sides into fore, mid and aft.
func _draw_plan() -> void:
	var s: Ship = _ship()
	if s == null:
		return
	var d: DamageModel = s.damage
	var cx: float = PLAN_W * 0.5
	var top: float = 6.0
	var bottom: float = PLAN_H - 6.0
	var hw: float = PLAN_W * 0.42
	var cap: float = d.displacement_t() * DamageModel.FLOOD_CAPACITY_SHARE / float(d.section_count)
	for i in d.section_count:
		var poly: PackedVector2Array = _section_poly(d, i, cx, top, bottom, hw)
		var hp: float = d.section_hp[i] / d.section_max
		var col: Color = Color(0.85, 0.2, 0.15).lerp(Color(0.95, 0.8, 0.2), clampf(hp * 2.0, 0.0, 1.0)) if hp < 0.5 else Color(0.95, 0.8, 0.2).lerp(Color(0.35, 0.75, 0.35), (hp - 0.5) * 2.0)
		if d.section_hp[i] <= 0.0:
			col = Color(0.25, 0.08, 0.08)
		_plan.draw_colored_polygon(poly, col)
		var wet: float = clampf(d.water_t[i] / maxf(cap, 0.001), 0.0, 1.0)
		if wet > 0.01:
			_plan.draw_colored_polygon(poly, Color(0.15, 0.45, 0.95, 0.25 + 0.55 * wet))
		if d.fire_level[i] > 0:
			var c: Vector2 = _centroid(poly)
			_plan.draw_circle(c, 5.0 + 2.0 * d.fire_level[i], Color(1.0, 0.5 + 0.2 * sin(_t * 9.0), 0.1, 0.9))
		poly.append(poly[0])
		_plan.draw_polyline(poly, Color(0.05, 0.04, 0.03), 2.0)
	# masts along the centreline
	for m in d.mast_down.size():
		var y: float = lerpf(top + (bottom - top) * 0.3, top + (bottom - top) * 0.72, (m + 0.5) / float(d.mast_down.size())) if d.mast_down.size() > 1 else top + (bottom - top) * 0.45
		var p := Vector2(cx, y)
		if d.mast_down[m]:
			_plan.draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), Color(0.95, 0.15, 0.1), 3.0)
			_plan.draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), Color(0.95, 0.15, 0.1), 3.0)
		else:
			_plan.draw_circle(p, 4.5, Color(0.45, 0.3, 0.18))
	# holes
	for br in d.breaches:
		var bp: Vector3 = br["pos"]
		var along: float = clampf(bp.z / s.stats.length_m + 0.5, 0.0, 1.0)
		var across: float = clampf(bp.x / (s.stats.beam_m * 0.5), -1.0, 1.0)
		var q := Vector2(cx + across * _half_width(along, hw) * 0.92, lerpf(top, bottom, along))
		var r: float = 3.0 + 1.5 * int(br["size"])
		var col: Color
		match str(br["state"]):
			"open":
				col = Color(1.0, 0.15, 0.1).lerp(Color(1.0, 0.85, 0.8), 0.5 + 0.5 * sin(_t * 8.0))
			"stuffed":
				col = Color(0.55, 0.52, 0.48)
			"fothered":
				col = Color(0.95, 0.92, 0.82)
			_:
				col = Color(0.7, 0.5, 0.28)
		_plan.draw_circle(q, r + 1.5, Color(0, 0, 0))
		_plan.draw_circle(q, r, col)


## Half the hull's width at `along` (0 bow .. 1 stern): a pointed bow, a full middle and a squared stern.
func _half_width(along: float, hw: float) -> float:
	if along < 0.35:
		return hw * sin(along / 0.35 * PI * 0.5)
	if along > 0.85:
		return hw * lerpf(1.0, 0.75, (along - 0.85) / 0.15)
	return hw


func _outline(cx: float, top: float, bottom: float, hw: float, a0: float, a1: float, side: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for k in 9:
		var a: float = lerpf(a0, a1, k / 8.0)
		pts.append(Vector2(cx + side * _half_width(a, hw), lerpf(top, bottom, a)))
	return pts


func _band(cx: float, top: float, bottom: float, hw: float, a0: float, a1: float, side: float) -> PackedVector2Array:
	var pts: PackedVector2Array = _outline(cx, top, bottom, hw, a0, a1, side)
	pts.append(Vector2(cx, lerpf(top, bottom, a1)))
	pts.append(Vector2(cx, lerpf(top, bottom, a0)))
	return pts


func _section_poly(d: DamageModel, i: int, cx: float, top: float, bottom: float, hw: float) -> PackedVector2Array:
	var bow_end: float = 0.2 if d.section_count == 4 else 0.1
	var stern_start: float = 0.8 if d.section_count == 4 else 0.9
	if i == 0:
		var p: PackedVector2Array = _outline(cx, top, bottom, hw, 0.0, bow_end, 1.0)
		var q: PackedVector2Array = _outline(cx, top, bottom, hw, bow_end, 0.0, -1.0)
		p.append_array(q)
		return p
	if i == d.section_count - 1:
		var p2: PackedVector2Array = _outline(cx, top, bottom, hw, stern_start, 1.0, 1.0)
		p2.append_array(_outline(cx, top, bottom, hw, 1.0, stern_start, -1.0))
		return p2
	if d.section_count == 4:
		return _band(cx, top, bottom, hw, bow_end, stern_start, 1.0 if i == 2 else -1.0)
	var band: int = (i - 1) / 2
	var a0: float = bow_end + band * (stern_start - bow_end) / 3.0
	var a1: float = a0 + (stern_start - bow_end) / 3.0
	return _band(cx, top, bottom, hw, a0, a1, 1.0 if (i - 1) % 2 == 1 else -1.0)


func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(poly.size(), 1)
