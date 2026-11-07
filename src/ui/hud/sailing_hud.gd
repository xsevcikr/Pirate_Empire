class_name SailingHud
extends CanvasLayer
## Sailing HUD, kept small: a Kenney-style wood card in the bottom-right corner with speed, sails, a hull bar and
## the crew. Guns, ammo, the target and the captain's health only appear in a fight; flooding and fire only when
## there are any. Every row has an icon, so it reads without colour. The key list is folded away behind one hint
## ("/" shows it). The top-left corner is left free for the map. There is no wind: sailing ignores it.

const COMBAT_RANGE_M: float = 700.0  ## a hostile ship this close puts the gun line on the card
const COMBAT_HOLD_S: float = 8.0  ## ...and it stays that long after the last hit or shot
const SCAN_EVERY_S: float = 0.25

var ship: Ship
var wind: WindModel
var clock: Node

var target: Ship
var _card: PanelContainer
var _label: Label  ## the card as plain text (kept for tests and screen readers); hidden, the rows show it
var _speed: Label
var _sails: Label
var _hull_bar: ProgressBar
var _hull_text: Label
var _crew: HBoxContainer
var _alert: Label
var _combat_rows: VBoxContainer
var _guns: Label
var _ammo: HBoxContainer
var _target_line: Label
var _captain_row: HBoxContainer
var _captain_bar: ProgressBar
var _hint: HBoxContainer
var _help: PanelContainer
var _scan_t: float = 0.0
var _combat_left: float = 0.0
var _hostile_near: bool = false
var _hooked: Ship


func _ready() -> void:
	_card = UiKit.panel("panel_dark", 16)
	_card.name = "ShipCard"
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_right = -24.0
	_card.offset_bottom = -24.0
	_card.custom_minimum_size = Vector2(330, 0)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	top.add_child(UiKit.icon("speed", 40))
	_speed = UiKit.label("0.0 kn", UiKit.SIZE_TITLE, Color.WHITE, true)
	top.add_child(_speed)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(UiKit.icon("sail", 30))
	_sails = UiKit.label("", UiKit.SIZE_SMALL, UiKit.NEUTRAL)
	top.add_child(_sails)
	var hull := HBoxContainer.new()
	hull.add_theme_constant_override("separation", 8)
	col.add_child(hull)
	hull.add_child(UiKit.icon("pirate/ship-pirate-small", 34))
	_hull_bar = UiKit.bar(UiKit.GOOD, 22)
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hull.add_child(_hull_bar)
	_hull_text = UiKit.label("100%", UiKit.SIZE_SMALL, Color.WHITE, true)
	_hull_text.custom_minimum_size = Vector2(62, 0)
	_hull_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hull.add_child(_hull_text)
	_crew = UiKit.chip("characters/character-a", "0", UiKit.SIZE_SMALL)
	col.add_child(_crew)
	_alert = UiKit.label("", UiKit.SIZE_SMALL, UiKit.WARN, true)
	_alert.visible = false
	col.add_child(_alert)
	_combat_rows = VBoxContainer.new()
	_combat_rows.add_theme_constant_override("separation", 4)
	_combat_rows.visible = false
	col.add_child(_combat_rows)
	var guns := HBoxContainer.new()
	guns.add_theme_constant_override("separation", 8)
	_combat_rows.add_child(guns)
	guns.add_child(UiKit.icon("pirate/cannon", 30))
	_guns = UiKit.label("", UiKit.SIZE_SMALL, Color.WHITE, true)
	guns.add_child(_guns)
	_ammo = UiKit.chip("pirate/cannon-ball", "", UiKit.SIZE_SMALL)
	_combat_rows.add_child(_ammo)
	_target_line = UiKit.label("", UiKit.SIZE_SMALL, UiKit.FOE, true)
	_combat_rows.add_child(_target_line)
	_captain_row = HBoxContainer.new()
	_captain_row.add_theme_constant_override("separation", 8)
	_captain_row.visible = false
	col.add_child(_captain_row)
	_captain_row.add_child(UiKit.icon("heart", 30))
	_captain_bar = UiKit.bar(UiKit.GOOD, 18)
	_captain_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_captain_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_captain_row.add_child(_captain_bar)
	_label = _make_label(20)
	_label.visible = false
	add_child(_label)
	_hint = HBoxContainer.new()
	_hint.add_theme_constant_override("separation", 8)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 28.0
	_hint.offset_top = -44.0
	_hint.modulate = Color(1, 1, 1, 0.85)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var help_key: String = UiKit.action_key("controls_help")
	_hint.add_child(UiKit.keycap(help_key if help_key != "" else "/", 34))
	_hint.add_child(UiKit.label(Loc.t("hud.help_hint"), 18))
	add_child(_hint)
	_help = UiKit.panel("panel_dark", 16)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 24.0
	_help.offset_top = -24.0
	_help.offset_bottom = -24.0
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.add_child(UiKit.label(Loc.t("hud.help_keys"), UiKit.SIZE_SMALL))
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
	if ship == null or not is_instance_valid(ship) or ship.damage == null:
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
	_refresh_card()


## Puts the numbers on the card rows.
func _refresh_card() -> void:
	var d: DamageModel = ship.damage
	_speed.text = "%.1f kn" % ship.speed_knots()
	_sails.text = Loc.t("hud.sails_%d" % clampi(ship.sail_level, 0, 3))
	var hull: float = d.hull_fraction()
	_hull_bar.value = hull * 100.0
	_tint(_hull_bar, UiKit.health_color(hull))
	_hull_text.text = "%d%%" % int(round(hull * 100.0))
	UiKit.chip_set(_crew, Loc.t("hud.card_crew") % ship.crew.count)
	var alerts: Array[String] = []
	var flood: float = d.flood_fraction()
	if flood > 0.02:
		alerts.append(Loc.t("hud.card_flood") % int(round(flood * 100.0)))
	if d.fires_burning() > 0:
		alerts.append(Loc.t("hud.card_fire"))
	_alert.text = "!  " + "   ".join(alerts) if not alerts.is_empty() else ""
	_alert.visible = not alerts.is_empty()
	var fight: bool = in_combat()
	_combat_rows.visible = fight
	if fight:
		var b: Broadside = ship.broadside
		_guns.text = Loc.t("hud.card_guns_short") % [b.ready_count(0), b.gun_count(), b.ready_count(1), b.gun_count()]
		UiKit.chip_set(_ammo, "%s x%d" % [Loc.t("ammo." + b.ammo_id), int(b.ammo.get(b.ammo_id, 0))])
		var has_target: bool = target != null and is_instance_valid(target) and not target.damage.sunk
		_target_line.visible = has_target
		if has_target:
			_target_line.text = Loc.t("hud.card_target") % [target.stats.display_name, target.damage.mast_down.count(false), target.stats.mast_count]
	var show_captain: bool = false
	if Session.has_state():
		var hp: float = CaptainHealth.hp(Session.state)
		show_captain = fight or hp < DeckData.FIGHTER_HP - 0.5
		_captain_bar.value = hp / DeckData.FIGHTER_HP * 100.0
		_tint(_captain_bar, UiKit.health_color(hp / DeckData.FIGHTER_HP))
	_captain_row.visible = show_captain


func _tint(b: ProgressBar, c: Color) -> void:
	var f: StyleBox = b.get_theme_stylebox("fill")
	if f is StyleBoxTexture:
		(f as StyleBoxTexture).modulate_color = c
	elif f is StyleBoxFlat:
		(f as StyleBoxFlat).bg_color = c


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
	lines.append(Loc.t("hud.card_sail") % [ship.speed_knots(), Loc.t("hud.sails_%d" % clampi(ship.sail_level, 0, 3))])
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
