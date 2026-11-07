class_name SailingHud
extends CanvasLayer
## Sailing HUD, kept small: a card in the bottom-right corner with speed, sails, wind, hull and crew. Guns, ammo,
## the target and the captain's health only appear in a fight; flooding and fire only when there are any. The key
## list is folded away behind one hint ("?" shows it). The top-left corner is left free for the map.

const COMBAT_RANGE_M: float = 700.0  ## a hostile ship this close puts the gun line on the card
const COMBAT_HOLD_S: float = 8.0  ## ...and it stays that long after the last hit or shot
const SCAN_EVERY_S: float = 0.25

var ship: Ship
var wind: WindModel
var clock: Node

var target: Ship
var _card: PanelContainer
var _label: Label
var _hint: Label
var _help: Label
var _scan_t: float = 0.0
var _combat_left: float = 0.0
var _hostile_near: bool = false
var _hooked: Ship


func _ready() -> void:
	_card = PanelContainer.new()
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_right = -24.0
	_card.offset_bottom = -24.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.12, 0.55)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)
	_label = _make_label(20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_label)
	_hint = _make_label(16)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 32.0
	_hint.offset_top = -40.0
	_hint.text = Loc.t("hud.help_hint")
	_hint.modulate = Color(1, 1, 1, 0.75)
	add_child(_hint)
	_help = _make_label(16)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 32.0
	_help.offset_top = -40.0
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.text = Loc.t("hud.help_keys")
	_help.visible = false
	add_child(_help)


func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("controls_help"):
		toggle_help()
		get_viewport().set_input_as_handled()


func toggle_help() -> void:
	_help.visible = not _help.visible
	_hint.visible = not _help.visible


func help_shown() -> bool:
	return _help != null and _help.visible


## True while a fight is on: a hostile ship close by, or a shot fired or taken in the last few seconds.
func in_combat() -> bool:
	return _hostile_near or _combat_left > 0.0


func _process(delta: float) -> void:
	if ship == null or wind == null or not is_instance_valid(ship):
		return
	_watch(ship)
	_combat_left = maxf(_combat_left - delta, 0.0)
	if ship.broadside != null and ship.broadside.ready_count(0) + ship.broadside.ready_count(1) < ship.broadside.gun_count() * 2:
		_combat_left = COMBAT_HOLD_S  # guns reloading: we just fired
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_EVERY_S
		_hostile_near = _scan_hostiles()
	_label.text = card_text()


func _watch(s: Ship) -> void:
	if _hooked == s:
		return
	_hooked = s
	if not s.hit_taken.is_connected(_on_hit):
		s.hit_taken.connect(_on_hit)


func _on_hit(_info: Dictionary) -> void:
	_combat_left = COMBAT_HOLD_S


func _scan_hostiles() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == ship or s.ai == null or s.damage == null or s.damage.sunk or s.has_surrendered:
			continue
		if s.faction == "merchant" or not FactionRel.hostile(ship.faction, s.faction):
			continue
		if s.global_position.distance_to(ship.global_position) <= COMBAT_RANGE_M:
			return true
	return false


## The text on the card, line by line.
func card_text() -> String:
	var d: DamageModel = ship.damage
	var lines: Array[String] = []
	lines.append(Loc.t("hud.card_sail") % [ship.speed_knots(), Loc.t("hud.sails_%d" % clampi(ship.sail_level, 0, 3)), wind.speed_kn])
	var state: String = Loc.t("hud.card_ship") % [int(round(d.hull_fraction() * 100.0)), ship.crew.count]
	var flood: float = d.flood_fraction()
	if flood > 0.02:
		state += "   " + Loc.t("hud.card_flood") % int(round(flood * 100.0))
	if d.fires_burning() > 0:
		state += "   " + Loc.t("hud.card_fire")
	lines.append(state)
	if in_combat():
		var b: Broadside = ship.broadside
		lines.append(Loc.t("hud.card_guns") % [b.ready_count(0), b.gun_count(), b.ready_count(1), b.gun_count(),
			Loc.t("ammo." + b.ammo_id), int(b.ammo.get(b.ammo_id, 0))])
		if target != null and is_instance_valid(target) and not target.damage.sunk:
			# the enemy's hull is not shown: only what the eye can see, her masts
			lines.append(Loc.t("hud.card_target") % [target.stats.display_name, target.damage.mast_down.count(false), target.stats.mast_count])
	if Session.has_state():
		var hp: float = CaptainHealth.hp(Session.state)
		if in_combat() or hp < DeckData.FIGHTER_HP - 0.5:
			lines.append(Loc.t("hud.card_captain") % [ceili(hp), roundi(DeckData.FIGHTER_HP)])
	return "\n".join(lines)
