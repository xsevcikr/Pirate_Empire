class_name GameOverlay
extends CanvasLayer
## Messages over the game: the quest hint on a parchment banner at the top centre (the tutorial step, or the job
## you took when the tutorial is done), the "[F] Do it" prompt at the bottom centre that shows only next to
## something you can use, toasts as small wood cards on the right, and the gold/food/cargo line.

const TOAST_SECONDS: float = 4.0
const MAX_TOASTS: int = 4

var _prompt: Label
var _banner: PanelContainer
var _prompt_text: String = ""
const BANNER_TEXT_MAX_PX: float = 820.0
var _hint: Label  ## the raw prompt text (hidden; the key caps in _interact show it)
var _interact: HBoxContainer
var _interact_text: String = "<unset>"
var _info: Label
var _nav: Label
var _toasts: VBoxContainer
var _toast_age: Array[float] = []


func _ready() -> void:
	layer = 5
	_info = _make_label(Vector2.ZERO, 20)
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = 32.0
	_info.offset_top = -76.0
	_info.offset_bottom = -46.0
	_nav = _make_label(Vector2.ZERO, 18)
	_nav.anchor_left = 1.0
	_nav.anchor_right = 1.0
	_nav.offset_left = -520.0
	_nav.offset_right = -24.0
	_nav.offset_top = 40.0
	_nav.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_banner()
	_hint = _bottom_centre(24, -180.0)
	_hint.visible = false
	_interact = HBoxContainer.new()
	_interact.name = "InteractPrompt"
	_interact.alignment = BoxContainer.ALIGNMENT_CENTER
	_interact.add_theme_constant_override("separation", 22)
	_interact.anchor_left = 0.0
	_interact.anchor_right = 1.0
	_interact.anchor_top = 1.0
	_interact.anchor_bottom = 1.0
	_interact.offset_top = -214.0
	_interact.offset_bottom = -156.0
	_interact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_interact)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -520.0
	_toasts.offset_right = -24.0
	_toasts.offset_top = 90.0
	add_child(_toasts)
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.connect(add_toast)


func set_nav(text: String) -> void:
	_nav.text = text


func _bottom_centre(size: int, offset_y: float) -> Label:
	var l: Label = _make_label(Vector2.ZERO, size)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.offset_top = offset_y
	l.offset_bottom = offset_y + 40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _build_banner() -> void:
	_banner = UiKit.panel("panel_paper", 18)
	_banner.name = "QuestBanner"
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = 18.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	row.add_child(UiKit.icon("flag", 34))
	_prompt = UiKit.label("", UiKit.SIZE_BODY, UiKit.PAPER_TEXT, true, false)
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt)


## The tutorial step's text, or "" when there is none (the banner then shows the job you took, if any).
func set_prompt(text: String) -> void:
	_prompt_text = text
	_refresh_banner()


func _refresh_banner() -> void:
	var text: String = _prompt_text if _prompt_text != "" else quest_hint(Session.state if Session.has_state() else {})
	if text == _prompt.text and _banner.visible == (text != ""):
		return
	_prompt.text = text
	_banner.visible = text != ""
	var f: Font = UiKit.font(true)
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x if f != null else text.length() * 12.0
	var lw: float = minf(w + 6.0, BANNER_TEXT_MAX_PX)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w + 6.0 > BANNER_TEXT_MAX_PX else TextServer.AUTOWRAP_OFF
	_prompt.custom_minimum_size = Vector2(lw, 0)
	var full: float = lw + 34.0 + 10.0 + 36.0  # flag icon, gap, panel margins
	_banner.offset_left = -full * 0.5
	_banner.offset_right = full * 0.5
	_banner.offset_bottom = _banner.offset_top
	_banner.reset_size.call_deferred()


## The first job on your list as a one-line goal, for the banner once the tutorial is over.
static func quest_hint(st: Dictionary) -> String:
	if st.is_empty() or not st.has("quests"):
		return ""
	for id: String in st["quests"]:
		if QuestData.JOBS.has(id):
			return Loc.t(QuestData.JOBS[id]["title"])
	return ""


func quest_banner_text() -> String:
	return _prompt.text if _banner.visible else ""


## What you can do right here, as "Key: what it does" parts split by three spaces, e.g. "Space: Dock". Each part
## shows as a key cap and a word; "" hides the prompt, so it only appears next to something you can use.
func set_dock_hint(text: String) -> void:
	_hint.text = text
	if text == _interact_text:
		return
	_interact_text = text
	for c in _interact.get_children():
		_interact.remove_child(c)
		c.queue_free()
	for part: Array in prompt_parts(text):
		var card: PanelContainer = UiKit.panel("panel_dark", 10)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		if str(part[0]) != "":
			row.add_child(UiKit.keycap(str(part[0]), 44))
		row.add_child(UiKit.label(str(part[1]), UiKit.SIZE_BODY, Color.WHITE, true))
		_interact.add_child(card)


func interact_parts_shown() -> int:
	return _interact.get_child_count()


## "Space: Dock   F: Tie up" -> [["Space", "Dock"], ["F", "Tie up"]]. A part with no short key before a colon
## keeps its whole text and no key cap.
static func prompt_parts(text: String) -> Array:
	var out: Array = []
	for seg: String in text.split("   ", false):
		seg = seg.strip_edges()
		if seg == "":
			continue
		var i: int = seg.find(": ")
		if i > 0 and i <= 12 and seg.substr(0, i).split(" ").size() <= 2:
			out.append([seg.substr(0, i), seg.substr(i + 2)])
		else:
			out.append(["", seg])
	return out


func set_info(text: String) -> void:
	_info.text = text


## The one-line status at the bottom left: gold, food and water always; the hold only when it is nearly full and
## morale only when the men are unhappy.
static func status_text(st: Dictionary) -> String:
	var out: String = Loc.t("hud.status_short") % [int(st["gold"]), CrewLife.days_left(st, "food"), CrewLife.days_left(st, "water")]
	var cap: float = PortService.cargo_capacity(st)
	var full: float = PortService.cargo_used(st) / cap if cap > 0.0 else 0.0
	if full >= 0.8:
		out += "   " + Loc.t("hud.status_cargo") % (full * 100.0)
	var morale: float = float(st["morale"])
	if morale < Morale.BANDS["content"]["min"]:
		out += "   " + Loc.t("hud.status_morale") % Loc.t("morale." + Morale.band(morale))
	return out


func add_toast(text: String) -> void:
	var card: PanelContainer = UiKit.panel("panel_dark", 12)
	var l: Label = UiKit.label(text, UiKit.SIZE_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(l)
	_toasts.add_child(card)
	_toast_age.append(0.0)
	while _toast_age.size() > MAX_TOASTS:
		_drop_toast(0)


func _process(delta: float) -> void:
	if _prompt_text == "":
		_refresh_banner()  # a job taken in port shows up without a call
	for i in range(_toast_age.size() - 1, -1, -1):
		_toast_age[i] += delta
		if _toast_age[i] > TOAST_SECONDS:
			_drop_toast(i)


func _drop_toast(i: int) -> void:
	var c: Node = _toasts.get_child(i)
	_toasts.remove_child(c)
	c.queue_free()
	_toast_age.remove_at(i)
