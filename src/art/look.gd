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


## Chunky rounded panels, buttons and bars in the Kenney palette, for every Control in the game.
static func ui_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var panel := _box(Color(0.22, 0.25, 0.4, 0.88), Color(0.12, 0.13, 0.22), 3, 12)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", _box(Color(1.0, 0.75, 0.27), Color(0.12, 0.13, 0.22), 3, 10))
	t.set_stylebox("hover", "Button", _box(Color(1.0, 0.84, 0.45), Color(0.12, 0.13, 0.22), 3, 10))
	t.set_stylebox("pressed", "Button", _box(Color(0.85, 0.58, 0.18), Color(0.12, 0.13, 0.22), 3, 10))
	t.set_stylebox("disabled", "Button", _box(Color(0.5, 0.52, 0.62), Color(0.12, 0.13, 0.22), 3, 10))
	t.set_color("font_color", "Button", Color(0.16, 0.12, 0.2))
	t.set_color("font_hover_color", "Button", Color(0.16, 0.12, 0.2))
	t.set_color("font_pressed_color", "Button", Color(0.16, 0.12, 0.2))
	t.set_stylebox("background", "ProgressBar", _box(Color(0.12, 0.13, 0.22, 0.8), Color(0.12, 0.13, 0.22), 2, 8))
	t.set_stylebox("fill", "ProgressBar", _box(Color(0.38, 0.8, 0.55), Color(0.12, 0.13, 0.22), 2, 8))
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
