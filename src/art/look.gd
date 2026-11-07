class_name Look
extends RefCounted
## The shared cartoon look: soft colour ambient, filmic tonemap, light glow, gentle SSAO and punchy colour grading,
## the recipe of Kenney's starter scene. Every scene that draws the world calls this instead of setting its own.


static func apply_environment(env: Environment) -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.62)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 0.8
	env.ssao_power = 12.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.06


static func apply_sun(sun: DirectionalLight3D, max_distance: float) -> void:
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.9
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = max_distance


## Lifts a realistic colour towards the bright, clean tones of the Kenney palette.
static func cartoon(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 1.15 + 0.08, 0.0, 1.0), clampf(c.v * 0.6 + 0.45, 0.0, 1.0))


static var _theme: Theme

## 9-slice margins of the skin textures drawn by tools/gen_ui_skin.py, in texture pixels.
const SKIN_MARGIN: Dictionary = {
	"panel_wood": 26, "panel_paper": 22, "panel_dark": 18, "button_normal": 18, "button_hover": 18,
	"button_pressed": 18, "button_disabled": 18, "button_wood": 18, "button_wood_hover": 18, "button_wood_pressed": 18,
	"bar_back": 9, "bar_fill": 9, "keycap": 14, "field": 14, "tab_selected": 14, "tab_unselected": 14,
}


## Kenney-style pirate skin for every Control in the game: wood panels with gold rivets, gold buttons with a
## 3D lip, parchment fields and the round Fredoka font at a size kids can read. Falls back to flat boxes when
## the skin PNGs are missing.
static func ui_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f: Font = UiKit.font(false)
	if f != null:
		t.default_font = f
	t.default_font_size = 22
	var panel: StyleBox = UiKit.box("panel_wood", 0, 22)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", UiKit.box("button_normal", 0, 14))
	t.set_stylebox("hover", "Button", UiKit.box("button_hover", 0, 14))
	t.set_stylebox("pressed", "Button", UiKit.box("button_pressed", 0, 14))
	t.set_stylebox("hover_pressed", "Button", UiKit.box("button_pressed", 0, 14))
	t.set_stylebox("disabled", "Button", UiKit.box("button_disabled", 0, 14))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 1.0, 1.0, 0.9)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(14)
	focus.set_expand_margin_all(3)
	t.set_stylebox("focus", "Button", focus)
	var ink := Color(0.23, 0.14, 0.08)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.3, 0.26))
	t.set_font_size("font_size", "Button", 22)
	for kind in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", kind, StyleBoxEmpty.new())
		t.set_stylebox("hover", kind, StyleBoxEmpty.new())
		t.set_stylebox("pressed", kind, StyleBoxEmpty.new())
		t.set_stylebox("focus", kind, focus)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, kind, Color(1.0, 0.97, 0.9))
		t.set_color("font_outline_color", kind, ink)
		t.set_constant("outline_size", kind, 5)
	# Light text on the wood. No outline by default: many cards set dark text on parchment, and an outline would
	# smear it. HUD text over the sea gets its outline from UiKit.label().
	t.set_color("font_color", "Label", Color(1.0, 0.97, 0.9))
	t.set_color("default_color", "RichTextLabel", Color(1.0, 0.97, 0.9))
	var field: StyleBox = UiKit.box("field", 0, 10)
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, field)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, ink)
	t.set_stylebox("panel", "ItemList", field)
	t.set_color("font_color", "ItemList", ink)
	t.set_stylebox("normal", "OptionButton", UiKit.box("button_wood", 0, 14))
	t.set_stylebox("hover", "OptionButton", UiKit.box("button_wood_hover", 0, 14))
	t.set_stylebox("pressed", "OptionButton", UiKit.box("button_wood_pressed", 0, 14))
	t.set_stylebox("focus", "OptionButton", focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", Color(1.0, 0.97, 0.9))
	t.set_stylebox("panel", "PopupMenu", UiKit.box("panel_dark", 0, 10))
	t.set_stylebox("hover", "PopupMenu", UiKit.box("button_normal", 0, 6))
	t.set_color("font_hover_color", "PopupMenu", ink)
	t.set_stylebox("tab_selected", "TabContainer", UiKit.box("tab_selected", 0, 12))
	t.set_stylebox("tab_unselected", "TabContainer", UiKit.box("tab_unselected", 0, 12))
	t.set_stylebox("tab_hovered", "TabContainer", UiKit.box("button_hover", 0, 12))
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_color("font_selected_color", "TabContainer", ink)
	t.set_color("font_unselected_color", "TabContainer", Color(1.0, 0.97, 0.9))
	t.set_stylebox("background", "ProgressBar", UiKit.box("bar_back", 0, 0))
	var fill: StyleBox = UiKit.box("bar_fill", 0, 0)
	if fill is StyleBoxTexture:
		(fill as StyleBoxTexture).modulate_color = UiKit.GOOD
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", Color(1.0, 0.97, 0.9))
	t.set_stylebox("slider", "HSlider", UiKit.box("bar_back", 0, 0))
	var grab := UiKit.box("bar_fill", 0, 0)
	if grab is StyleBoxTexture:
		(grab as StyleBoxTexture).modulate_color = UiKit.GOLD
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0.23, 0.14, 0.08, 0.6)
	sc.set_corner_radius_all(6)
	sc.content_margin_left = 6
	sc.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", sc)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = UiKit.GOLD
	grabber.set_corner_radius_all(6)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	_theme = t
	return t


static func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


## A soft dark vignette over the whole screen, for fights.
static func add_vignette(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	layer.name = "Vignette"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() { float d = distance(UV, vec2(0.5)); COLOR = vec4(0.1, 0.08, 0.2, smoothstep(0.45, 0.85, d) * 0.45); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	rect.material = m
	layer.add_child(rect)
	parent.add_child(layer)
