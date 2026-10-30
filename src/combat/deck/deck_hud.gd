class_name DeckHud
extends Control
## Fight HUD: the captain's health, stamina, what is in his hands and his rum; a health bar for every one of our men on
## deck; the head count and the enemy's morale; the order buttons; and the hits as they land. The enemy's health is
## never shown: a hit on one of them reads "Hit!", not a number.

signal order_pressed(order: int)

## The order buttons, left to right. 0-4 are squad stances (DeckData.Command), the rest are jobs. Keys 1-8.
enum Order { ATTACK, HOLD, PROTECT, FOCUS, RETREAT, LOAD_CANNON, FIRE_CANNON, REPAIR }
const ORDER_KEYS: Array[String] = ["deck.cmd_charge", "deck.cmd_hold", "deck.cmd_protect", "deck.cmd_focus", "deck.cmd_fall_back",
	"deck.cmd_load", "deck.cmd_fire", "deck.cmd_repair"]
const COMMAND_KEYS: Array[String] = ["deck.cmd_charge", "deck.cmd_hold", "deck.cmd_protect", "deck.cmd_focus", "deck.cmd_fall_back"]
const MODE_KEYS: Array[String] = ["deck.mode_blade", "deck.mode_fists", "deck.mode_gun"]
const NUMBER_LIFE_S: float = 0.9
const NOTE_LIFE_S: float = 2.2
const CREW_ROWS: int = 11

var combat: DeckCombat
var _hp: ProgressBar
var _hp_text: Label
var _stamina: ProgressBar
var _enemy_morale: ProgressBar
var _weapon: Label
var _rum: Label
var _counts: Label
var _command: Label
var _banner: Label
var _note: Label
var _note_left: float = 0.0
var _crew_rows: Array[Dictionary] = []  ## {box, name, bar}
var _buttons: Array[Button] = []
var _numbers: Array[Dictionary] = []  ## {label, life}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 380.0
	top.offset_right = -380.0
	top.offset_top = 16.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_counts = _label(top, 28)
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var morale_l := _label(top, 14)
	morale_l.text = Loc.t("deck.enemy_morale")
	morale_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_morale = _bar(top, Color(0.8, 0.3, 0.25), 10.0)
	_build_crew_panel()
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 24.0
	bottom.offset_top = -300.0
	bottom.offset_bottom = -20.0
	bottom.custom_minimum_size = Vector2(430, 0)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_hp_text = _label(bottom, 18)
	_hp = _bar(bottom, Color(0.8, 0.2, 0.2), 20.0)
	_stamina = _bar(bottom, Color(0.9, 0.8, 0.2), 12.0)
	_weapon = _label(bottom, 20)
	_rum = _label(bottom, 18)
	_command = _label(bottom, 18)
	var help := _label(bottom, 14)
	help.text = Loc.t("deck.help")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_order_bar()
	_note = Label.new()
	_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note.offset_top = 150.0
	_note.offset_left = -300.0
	_note.offset_right = 300.0
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 26)
	_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_note.add_theme_constant_override("outline_size", 5)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_note)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.add_theme_font_size_override("font_size", 56)
	_banner.visible = false
	add_child(_banner)


## One small row per man of ours on deck: his name and his health.
func _build_crew_panel() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 20.0
	panel.offset_top = 16.0
	panel.custom_minimum_size = Vector2(230, 0)
	panel.add_theme_constant_override("separation", 2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var head := _label(panel, 16)
	head.text = Loc.t("deck.our_crew")
	for i in CREW_ROWS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var n := _label(row, 13)
		n.custom_minimum_size = Vector2(96, 0)
		n.clip_text = true
		var b := _bar(row, Color(0.35, 0.75, 0.35), 10.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_crew_rows.append({"box": row, "name": n, "bar": b})


## The order buttons along the bottom: click them, or press 1-8.
func _build_order_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -470.0
	bar.offset_right = 610.0
	bar.offset_top = -64.0
	bar.offset_bottom = -18.0
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	for i in ORDER_KEYS.size():
		var b := Button.new()
		b.text = "%d %s" % [i + 1, Loc.t(ORDER_KEYS[i])]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = i <= Order.RETREAT or i == Order.REPAIR
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(func() -> void: order_pressed.emit(i))
		b.set_meta("kind", "order_button")
		bar.add_child(b)
		_buttons.append(b)


func _label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, height)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	if combat == null or _hp == null:
		return
	var p: FighterState = combat.player
	_hp.max_value = p.hp_max
	_hp.value = maxf(p.hp, 0.0)
	_hp_text.text = Loc.t("deck.your_health") % [ceili(maxf(p.hp, 0.0)), roundi(p.hp_max)]
	_stamina.max_value = p.stamina_max
	_stamina.value = p.stamina
	_enemy_morale.max_value = 100.0
	_enemy_morale.value = combat.morale[1]
	_counts.text = Loc.t("deck.counts") % [combat.standing_on_screen(0) + combat.reserve_of(0), combat.standing_on_screen(1) + combat.reserve_of(1)]
	var pistol: String = Loc.t("deck.pistol") % [p.charges, p.ranged_ammo] if p.ranged != "" else ""
	var hand: String = Loc.t("weapon." + p.melee) if p.mode != FighterState.Mode.GUN else Loc.t("weapon." + p.ranged)
	var held: String = Loc.t(MODE_KEYS[p.mode]) if p.mode == FighterState.Mode.FISTS else "%s: %s" % [Loc.t(MODE_KEYS[p.mode]), hand]
	_weapon.text = "%s    %s" % [held, pistol]
	_rum.text = Loc.t("deck.rum") % p.rum_left if p.rum_cool <= 0.0 or p.rum_left <= 0 else Loc.t("deck.rum_wait") % [p.rum_left, ceili(p.rum_cool)]
	_command.text = "%s: %s" % [Loc.t("deck.command"), Loc.t(COMMAND_KEYS[combat.command])]
	_update_crew_rows()
	_update_buttons()
	if _note_left > 0.0:
		_note_left -= delta
		_note.modulate.a = clampf(_note_left / 0.5, 0.0, 1.0)
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i]["life"] -= delta
		var l: Label = _numbers[i]["label"]
		l.position.y -= 40.0 * delta
		l.modulate.a = clampf(float(_numbers[i]["life"]) / NUMBER_LIFE_S, 0.0, 1.0)
		if _numbers[i]["life"] <= 0.0:
			l.queue_free()
			_numbers.remove_at(i)


func _update_crew_rows() -> void:
	var men: Array[FighterState] = []
	for f in combat.fighters:
		if f.team == 0 and not f.is_player and f.is_alive():
			men.append(f)
	for i in _crew_rows.size():
		var row: Dictionary = _crew_rows[i]
		var box: Control = row["box"]
		box.visible = i < men.size()
		if i >= men.size():
			continue
		var f: FighterState = men[i]
		var tag: String = f.display_name if f.display_name != "" else Loc.t("deck.hand")
		if f.job == DeckData.Job.CANNON:
			tag += " *"
		elif f.job == DeckData.Job.REPAIR:
			tag += " +"
		(row["name"] as Label).text = tag
		var b: ProgressBar = row["bar"]
		b.max_value = f.hp_max
		b.value = maxf(f.hp, 0.0)


func _update_buttons() -> void:
	if _buttons.is_empty():
		return
	for i in Order.RETREAT + 1:
		_buttons[i].set_pressed_no_signal(int(combat.command) == i)
	var gun_crew: bool = false
	var repairing: bool = false
	for f in combat.fighters:
		if f.team == 0 and f.is_standing() and f.job == DeckData.Job.CANNON:
			gun_crew = true
		if f.team == 0 and f.is_standing() and f.job == DeckData.Job.REPAIR:
			repairing = true
	var load_b: Button = _buttons[Order.LOAD_CANNON]
	if combat.cannon_loaded:
		load_b.text = "6 %s" % Loc.t("deck.cannon_ready")
	elif gun_crew:
		load_b.text = "6 %s" % (Loc.t("deck.cannon_loading") % roundi(100.0 * combat.cannon_load / DeckData.CANNON_LOAD_MAN_S))
	else:
		load_b.text = "6 %s" % Loc.t("deck.cmd_load")
	load_b.disabled = combat.cannon_loaded
	_buttons[Order.FIRE_CANNON].disabled = not combat.cannon_loaded
	_buttons[Order.REPAIR].set_pressed_no_signal(repairing)
	_buttons[Order.REPAIR].text = "8 %s" % (Loc.t("deck.repair_stop") if repairing else Loc.t("deck.cmd_repair"))


## A line in the middle of the screen: an order taken, or why it could not be.
func note(key: String) -> void:
	if _note == null:
		return
	_note.text = Loc.t(key)
	_note_left = NOTE_LIFE_S
	_note.modulate.a = 1.0


## A hit on one of ours shows the damage; a hit on the enemy only says it landed.
## `at` is the screen point over the man who was hit ((-1, -1) when he is off screen: the middle is used).
func on_hit(info: Dictionary, at: Vector2, target_team: int = 1) -> void:
	var dmg: float = float(info.get("damage", 0.0))
	var res: String = str(info.get("result", ""))
	var l := Label.new()
	if target_team == 0:
		l.text = ("-%d" % roundi(dmg)) if dmg > 0.0 else Loc.t("deck.blocked")
		l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	elif res == "blocked" or res == "guard_broken":
		l.text = Loc.t("deck.blocked")
	elif res == "dodged" or (dmg <= 0.0 and res != "parried"):
		l.text = Loc.t("deck.missed")
	else:
		l.text = Loc.t("deck.hit")
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = (at if at.x >= 0.0 else Vector2(size.x * 0.5, size.y * 0.45)) + Vector2(randf_range(-30.0, 10.0), randf_range(-10.0, 10.0))
	if res == "parried":
		l.text = Loc.t("deck.parry")
		l.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	add_child(l)
	_numbers.append({"label": l, "life": NUMBER_LIFE_S})


func show_result(r: Dictionary) -> void:
	_banner.visible = true
	if r["player_won"]:
		_banner.text = Loc.t("deck.surrender") if r["surrendered"] else Loc.t("deck.victory")
	else:
		_banner.text = Loc.t("deck.defeat")
