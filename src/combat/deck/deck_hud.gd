class_name DeckHud
extends Control
## Fight HUD: captain health and stamina, weapon and pistol, the tug-of-war between the two decks, the enemy's
## morale, the squad command and floating damage numbers.

const COMMAND_KEYS: Array[String] = ["deck.cmd_charge", "deck.cmd_hold", "deck.cmd_protect", "deck.cmd_focus", "deck.cmd_fall_back"]
const NUMBER_LIFE_S: float = 0.9

var combat: DeckCombat
var _hp: ProgressBar
var _stamina: ProgressBar
var _tug: ProgressBar
var _enemy_morale: ProgressBar
var _weapon: Label
var _counts: Label
var _command: Label
var _banner: Label
var _numbers: Array[Dictionary] = []  ## {label, life}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 16.0
	add_child(top)
	_counts = _label(top, 28)
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tug = _bar(top, Color(0.2, 0.45, 0.8), 18.0)
	_enemy_morale = _bar(top, Color(0.8, 0.3, 0.25), 10.0)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 24.0
	bottom.offset_top = -170.0
	bottom.offset_bottom = -20.0
	bottom.custom_minimum_size = Vector2(360, 0)
	add_child(bottom)
	_hp = _bar(bottom, Color(0.8, 0.2, 0.2), 20.0)
	_stamina = _bar(bottom, Color(0.9, 0.8, 0.2), 12.0)
	_weapon = _label(bottom, 20)
	_command = _label(bottom, 18)
	var help := _label(bottom, 14)
	help.text = Loc.t("deck.help")
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.add_theme_font_size_override("font_size", 56)
	_banner.visible = false
	add_child(_banner)


func _label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, height)
	b.show_percentage = false
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
	_stamina.max_value = DeckData.STAMINA_MAX
	_stamina.value = p.stamina
	var mine: float = combat.total_power(0)
	var theirs: float = combat.total_power(1)
	_tug.max_value = 1.0
	_tug.value = mine / maxf(mine + theirs, 1.0)
	_enemy_morale.max_value = 100.0
	_enemy_morale.value = combat.morale[1]
	_counts.text = Loc.t("deck.counts") % [combat.standing_on_screen(0) + combat.reserve_of(0), combat.standing_on_screen(1) + combat.reserve_of(1)]
	var pistol: String = Loc.t("deck.pistol") % [p.charges, p.ranged_ammo] if p.ranged != "" else ""
	_weapon.text = "%s    %s" % [Loc.t("weapon." + p.melee) if p.melee != "" else "", pistol]
	_command.text = "%s: %s" % [Loc.t("deck.command"), Loc.t(COMMAND_KEYS[combat.command])]
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i]["life"] -= delta
		var l: Label = _numbers[i]["label"]
		l.position.y -= 40.0 * delta
		l.modulate.a = clampf(float(_numbers[i]["life"]) / NUMBER_LIFE_S, 0.0, 1.0)
		if _numbers[i]["life"] <= 0.0:
			l.queue_free()
			_numbers.remove_at(i)


func on_hit(info: Dictionary, _at: Vector2) -> void:
	var dmg: float = float(info.get("damage", 0.0))
	var l := Label.new()
	l.text = ("%d" % roundi(dmg)) if dmg > 0.0 else Loc.t("deck.blocked")
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(size.x * 0.5 + randf_range(-60.0, 60.0), size.y * 0.45)
	if str(info.get("result", "")) == "parried":
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
