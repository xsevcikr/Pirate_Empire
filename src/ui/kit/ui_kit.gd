class_name UiKit
extends RefCounted
## Building blocks for the Kenney-style HUD: the skin textures from tools/gen_ui_skin.py, the Fredoka font, big
## outlined labels, icon chips, key caps and bars. Colours come from the Okabe-Ito set, which stays apart for
## colour-blind players, and every coloured thing also carries an icon or a word, never colour alone.

const UI_DIR: String = "res://assets/ui/"
const FONT_MEDIUM: String = "res://assets/fonts/Fredoka-Medium.ttf"
const FONT_BOLD: String = "res://assets/fonts/Fredoka-Bold.ttf"

## Okabe-Ito colours.
const FRIEND := Color(0.34, 0.71, 0.91)  ## sky blue: you and your fleet
const FOE := Color(0.9, 0.42, 0.1)  ## vermilion-orange: enemies
const GOOD := Color(0.0, 0.66, 0.48)  ## bluish green: healthy, gains
const WARN := Color(0.94, 0.89, 0.26)  ## yellow: careful
const NEUTRAL := Color(0.92, 0.9, 0.85)  ## merchants and everyone else
const GOLD := Color(1.0, 0.8, 0.3)
const INK := Color(0.23, 0.14, 0.08)
const PAPER_TEXT := Color(0.28, 0.17, 0.09)

## Text sizes, bigger than before so a 9-year-old reads them from the sofa.
const SIZE_SMALL: int = 20
const SIZE_BODY: int = 24
const SIZE_TITLE: int = 34
const SIZE_BIG: int = 44

static var _tex: Dictionary = {}
static var _fonts: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var p: String = UI_DIR + name + ".png"
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex[name] = t
	return t


static func font(bold: bool = false) -> Font:
	var key: String = FONT_BOLD if bold else FONT_MEDIUM
	if not _fonts.has(key):
		_fonts[key] = load(key) as Font if ResourceLoader.exists(key) else null
	return _fonts[key]


## A 9-sliced skin piece: "panel_wood", "panel_paper", "panel_dark", "button_normal", "bar_back", ...
static func box(name: String, margin: int = 0, content: int = -1) -> StyleBox:
	var t: Texture2D = tex(name)
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.36, 0.23, 0.13, 0.9)
		f.set_corner_radius_all(12)
		f.set_content_margin_all(12 if content < 0 else content)
		return f
	var b := StyleBoxTexture.new()
	b.texture = t
	if name == "panel_wood":  # planks repeat instead of smearing when the panel is big
		b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	var m: int = margin if margin > 0 else int(Look.SKIN_MARGIN.get(name, 16))
	b.texture_margin_left = m
	b.texture_margin_right = m
	b.texture_margin_top = m
	b.texture_margin_bottom = m
	var c: int = content if content >= 0 else m
	b.content_margin_left = c
	b.content_margin_right = c
	b.content_margin_top = maxi(c - 4, 4)
	b.content_margin_bottom = maxi(c - 4, 4)
	return b


## A panel container in one of the skins.
static func panel(skin: String = "panel_dark", content: int = -1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(skin, 0, content))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Big rounded text with a dark outline, readable over the sea.
static func label(text: String = "", size: int = SIZE_BODY, color: Color = Color.WHITE, bold: bool = false, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	var f: Font = font(bold)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(INK, 0.95))
		l.add_theme_constant_override("outline_size", maxi(4, size / 4))
	else:
		l.add_theme_constant_override("outline_size", 0)  # dark text on parchment: no theme outline
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## An icon: "heart", "skull", "anchor", "sail", "star", "gear", "speed", "flag", "info" are flat symbols; a name
## with a slash ("pirate/barrel") is a Kenney model picture from the catalogue icon set.
static func icon_texture(name: String) -> Texture2D:
	if name.contains("/"):
		return CatalogueIcons.texture(name)
	return tex("icon_" + name)


static func icon(name: String, size: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_texture(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## An icon and a number side by side, e.g. a coin and "1 250".
static func chip(icon_name: String, text: String, size: int = SIZE_BODY, color: Color = Color.WHITE) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon(icon_name, size + 8))
	var l: Label = label(text, size, color, true)
	l.name = "Text"
	h.add_child(l)
	return h


static func chip_set(c: HBoxContainer, text: String, color: Color = Color.WHITE) -> void:
	var l: Label = c.get_node("Text")
	l.text = text
	l.add_theme_color_override("font_color", color)


## A parchment key cap with the key's name on it, for "[F] Tie up" prompts.
static func keycap(key_text: String, size: int = 46) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("keycap", 14, 8))
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = label(key_text, int(size * 0.5), PAPER_TEXT, true, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## The name of the first keyboard key bound to an input action ("F", "Space"), or "" when none.
static func action_key(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for e: InputEvent in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k != null:
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return key_label(OS.get_keycode_string(code))
	return ""


## Short labels for key caps: "Slash" -> "/", "BracketLeft" -> "[".
static func key_label(name: String) -> String:
	const SHORT: Dictionary = {"Slash": "/", "BackSlash": "\\", "Comma": ",", "Period": ".", "Semicolon": ";", "Apostrophe": "'",
		"BracketLeft": "[", "BracketRight": "]", "Minus": "-", "Equal": "=", "QuoteLeft": "`", "Escape": "Esc"}
	return SHORT.get(name, name)


## A chunky rounded bar in the skin, tinted with one of the colours above.
static func bar(tint: Color, height: int = 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back: StyleBox = box("bar_back", 9, 0)
	var fill: StyleBox = box("bar_fill", 9, 0)
	if fill is StyleBoxTexture:
		(fill as StyleBoxTexture).modulate_color = tint
	elif fill is StyleBoxFlat:
		(fill as StyleBoxFlat).bg_color = tint
	b.add_theme_stylebox_override("background", back)
	b.add_theme_stylebox_override("fill", fill)
	return b


## The colour for a share of something good (health, hull): green when full, yellow in the middle, orange low.
## Colour-blind safe, and the bars also show their number.
static func health_color(frac: float) -> Color:
	if frac > 0.6:
		return GOOD
	if frac > 0.3:
		return WARN
	return FOE
