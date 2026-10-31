class_name TourEncounterScreen
extends MenuScreen
## One tour encounter on a panel: a dungeon run (rooms, traps, puzzles, a chest, the skeleton) or a boss fight
## (the boss winds up, you dodge, block or use its weakness, then strike). The rules are in Dungeon and
## MonsterFight; a boss fight plays out on a BossStage behind the panel. Only your own health is shown.

var director: TourDirector
var tour_id: String = ""
var run: Dungeon
var fight: MonsterFight
var _spotted: bool = false
var _info: Label
var _stage: BossStage
var _shown_events: int = 0
var _outcome: String = ""


func _init() -> void:
	super()
	_title_key = "tour.encounter"
	dim = 0.6


func _process(delta: float) -> void:
	if fight != null and not fight.is_over():
		var landed: String = fight.tick(delta)
		if _stage != null:
			_stage.follow(delta, landed)
		_read_events()
		_refresh()
		if fight.is_over():
			_end()
	elif run != null:
		run.tick(delta)
		_refresh()


func build() -> void:
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_info)
	if fight != null:
		_build_stage()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_box.add_child(row)
		for a in fight.actions():
			var b := Button.new()
			b.text = Loc.t("act." + a)
			b.custom_minimum_size = Vector2(0, 44)
			b.pressed.connect(fight.do.bind(a))
			b.pressed.connect(Sfx.play.bind("ui_click"))
			row.add_child(b)
	elif run != null:
		_build_room()
	add_button("menu.back", _leave)
	_refresh()


## The boss fight seen through a window behind the panel; the panel drops to the bottom of the screen.
func _build_stage() -> void:
	dim = 0.0
	(get_child(0) as ColorRect).color.a = 0.0
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(1280, 720)
	cont.add_child(vp)
	_stage = BossStage.make(fight)
	vp.add_child(_stage)
	add_child(cont)
	move_child(cont, 0)
	var holder: Control = holder()
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	if _title_key != "":
		_box.get_child(0).queue_free()  # the boss's name is in the panel; the stage needs the room
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.72)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_info.add_theme_stylebox_override("normal", sb)
	_info.add_theme_font_size_override("font_size", 20)
	_box.custom_minimum_size = Vector2(540, 0)


func _read_events() -> void:
	while _shown_events < fight.events.size():
		var e: String = fight.events[_shown_events]
		_shown_events += 1
		var kind: String = e.get_slice(":", 0)
		var what: String = e.get_slice(":", 1)
		match kind:
			"hit", "dodged", "blocked", "countered":
				_outcome = Loc.t("fight.outcome." + kind) % Loc.t("atk." + what)
			"phase":
				_outcome = Loc.t("fight.phase." + what)


## What the fight panel says: the boss's name (never its health), your health, what ails you, the tell and what
## answers it, what happened to the last attack.
func status_text() -> String:
	var lines: Array[String] = [str(fight.boss.def()["name"])]
	var mine: String = Loc.t("fight.you" if fight.on_foot() else "fight.hull") % [int(ceil(fight.player_hp)), int(fight.player_max)]
	var ails: Array[String] = []
	for e: String in fight.effects.keys():
		ails.append(Loc.t("fight.effect." + e))
	if not ails.is_empty():
		mine += "   " + ", ".join(ails)
	lines.append(mine)
	var t: String = fight.telegraph()
	if t != "":
		lines.append(Loc.t("tell." + t))
		lines.append(Loc.t("tour.telegraph") % Loc.t("atk." + t) + "  " + Loc.t(BossAttacks.answer_key(fight.id, t)))
	elif _outcome != "":
		lines.append(_outcome)
	if fight.is_exposed():
		lines.append(Loc.t("tour.exposed"))
	return "\n".join(lines)


func _refresh() -> void:
	if _info == null:
		return
	if fight != null:
		_info.text = status_text()
	elif run != null:
		_info.text = "%s %d / %d\nHP %d   torch %d s" % [Loc.t("room." + run.room_kind()), run.room + 1, run.room_count(), int(run.hp), int(run.torch_s)]
		if run.air_s > 0.0:
			_info.text += "   air %d s" % int(run.air_s)


func _build_room() -> void:
	match run.room_kind():
		"trap":
			add_button("act.look", _look)
			add_button("act.cross", _cross)
		"puzzle":
			for i in run.puzzle.symbol_count():
				add_button("act.press", _press.bind(i)).text = "%s %d" % [Loc.t("act.press"), i + 1]
			for lv in range(1, 4):
				add_button("act.hint", _puzzle_hint.bind(lv)).text = "%s %d" % [Loc.t("act.hint"), lv]
		"chest":
			add_button("act.open", func() -> void: run.open_chest(); _rebuild())
		"guard":
			add_button("act.strike", func() -> void: run.hit_skeleton(25.0); _rebuild())
			add_button("act.burn", func() -> void: run.hit_skeleton(25.0, true); _rebuild())
	if run.cleared():
		add_button("act.onward", _onward)


func _look() -> void:
	_spotted = run.spot_trap()


func _cross() -> void:
	run.cross_trap(_spotted)
	_spotted = false
	_rebuild()


func _press(i: int) -> void:
	run.puzzle.press(i)
	_rebuild()


func _puzzle_hint(level: int) -> void:
	var h: Dictionary = run.puzzle.hint(level)
	_info.text = Loc.t(str(h["key"]))


func _onward() -> void:
	if run.is_done():
		_end()
	else:
		run.advance()
		_rebuild()


func _end() -> void:
	if fight != null:
		director.finish_guardian(tour_id, fight)
	elif run != null:
		director.finish_dungeon(tour_id, run)
	close()


func _leave() -> void:
	if run != null:
		director.finish_dungeon(tour_id, run)
	close()
