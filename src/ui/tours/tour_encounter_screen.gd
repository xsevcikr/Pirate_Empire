class_name TourEncounterScreen
extends MenuScreen
## One tour encounter on a panel: a dungeon run (rooms, traps, puzzles, a chest, the skeleton) or a guardian
## fight (telegraph, dodge, parry, strike). The rules are in Dungeon and MonsterFight; this only shows them.

var director: TourDirector
var tour_id: String = ""
var run: Dungeon
var fight: MonsterFight
var _spotted: bool = false
var _info: Label


func _init() -> void:
	super()
	_title_key = "tour.encounter"
	dim = 0.6


func _process(delta: float) -> void:
	if fight != null and not fight.is_over():
		fight.tick(delta)
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
		for a in fight.actions():
			add_button("act." + a, fight.do.bind(a))
	elif run != null:
		_build_room()
	add_button("menu.back", _leave)
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	if fight != null:
		var t: String = fight.telegraph()
		var lines: Array[String] = ["%s  %d / %d" % [str(fight.boss.def()["name"]), int(fight.boss.hp), int(fight.boss.max_hp)],
			"HP %d / %d" % [int(fight.player_hp), int(fight.player_max)]]
		if t != "":
			lines.append(Loc.t("tour.telegraph") % Loc.t("atk." + t))
		if fight.is_exposed():
			lines.append(Loc.t("tour.exposed"))
		_info.text = "\n".join(lines)
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
			for i in (3 if run.puzzle.kind != "rhyme" else 6):
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
