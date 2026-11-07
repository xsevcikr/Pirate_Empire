class_name FirstTips
extends CanvasLayer
## First-time tips: a parchment card on the left that explains something the first time it happens (the first
## enemy, the first harbour, the first gold...). Each tip shows once ever; the player can switch them all off in
## Settings > Accessibility ("Show tips"), and "Show tips again" there brings them back.

## Tip id -> text key. The order is the order they are checked.
const TIPS: Array[String] = ["sail", "enemy", "harbour", "hurt", "gold", "map"]
const SHOW_S: float = 10.0
const CHECK_EVERY_S: float = 0.5
const SAIL_AFTER_S: float = 4.0
const MAP_AFTER_S: float = 150.0

var world: Node  ## the World scene: `ship`, `can_dock()`
var _card: PanelContainer
var _text: Label
var _left: float = 0.0
var _check_t: float = 0.0
var _time: float = 0.0
var _start_gold: int = -1
var shown_id: String = ""


func _ready() -> void:
	layer = 6
	_card = UiKit.panel("panel_paper", 18)
	_card.name = "TipCard"
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = 24.0
	_card.offset_top = -40.0
	_card.custom_minimum_size = Vector2(380, 0)
	_card.visible = false
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiKit.icon("info", 34))
	head.add_child(UiKit.label(Loc.t("tip.title"), UiKit.SIZE_BODY, UiKit.PAPER_TEXT, true, false))
	_text = UiKit.label("", UiKit.SIZE_SMALL, UiKit.PAPER_TEXT, false, false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(360, 0)
	col.add_child(_text)
	var off: Label = UiKit.label(Loc.t("tip.switch_off"), 16, Color(UiKit.PAPER_TEXT, 0.7), false, false)
	col.add_child(off)


func _settings() -> Node:
	return Svc.node("Settings")


func enabled() -> bool:
	var st: Node = _settings()
	return st == null or bool(st.get("tips_enabled"))


func seen(id: String) -> bool:
	var st: Node = _settings()
	return st != null and (st.get("tips_seen") as PackedStringArray).has(id)


## Shows a tip unless tips are off or it was shown before. Returns true if it is now on screen.
func show_tip(id: String) -> bool:
	if not enabled() or seen(id) or _card.visible:
		return false
	var st: Node = _settings()
	if st != null:
		var arr: PackedStringArray = st.get("tips_seen")
		arr.append(id)
		st.set("tips_seen", arr)
		st.save_settings()
	shown_id = id
	_text.text = Loc.t("tip." + id) % _keys_for(id)
	_card.visible = true
	_left = SHOW_S
	return true


func _keys_for(id: String) -> Array:
	match id:
		"sail":
			return [_k("sail_up", "W"), _k("sail_down", "S"), _k("steer_left", "A"), _k("steer_right", "D")]
		"enemy":
			return [_k("fire_port", "Q"), _k("fire_starboard", "E")]
		"harbour":
			return [_k("interact", "Space")]
		"hurt":
			return [_k("damage_control", "Z")]
		"map":
			return [_k("world_map", "M")]
	return []


func _k(action: String, fallback: String) -> String:
	var k: String = UiKit.action_key(action)
	return k if k != "" else fallback


func _process(delta: float) -> void:
	_time += delta
	if _card.visible:
		_left -= delta
		if _left <= 0.0 or not enabled():
			_card.visible = false
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY_S
	if not enabled():
		return
	var id: String = due()
	if id != "":
		show_tip(id)


## The first tip whose moment has come and that was not shown yet, or "".
func due() -> String:
	var ship: Ship = world.get("ship") as Ship if world != null and is_instance_valid(world) else null
	if ship == null or not is_instance_valid(ship) or ship.damage == null:
		return ""
	var gold: int = int(Session.state.get("gold", 0)) if Session.has_state() else 0
	if _start_gold < 0:
		_start_gold = gold
	for id: String in TIPS:
		if seen(id):
			continue
		match id:
			"sail":
				if _time > SAIL_AFTER_S:
					return id
			"enemy":
				if _hostile_near(ship):
					return id
			"harbour":
				if world.has_method("can_dock") and world.can_dock():
					return id
			"hurt":
				if ship.damage.hull_fraction() < 0.5:
					return id
			"gold":
				if gold > _start_gold:
					return id
			"map":
				if _time > MAP_AFTER_S:
					return id
	return ""


func _hostile_near(me: Ship) -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == me or s.damage == null or s.damage.sunk:
			continue
		if WorldMarkers.side_of(me.faction, s.faction) == "foe" and s.global_position.distance_to(me.global_position) < 600.0:
			return true
	return false
