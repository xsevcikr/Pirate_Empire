extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility --fixed-fps 30 -s res://tools/shot_boss_fight.gd -- /tmp/fight
## The whole fight screen (stage, panel, buttons) during a tell, one picture per monster.

var _prefix: String = "user://fight"
var _ids: Array[String] = []
var _i: int = -1
var _frame: int = 0
var _screen: TourEncounterScreen


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	root.size = Vector2i(1280, 720)
	_ids.assign(BossModel.KINDS)


func _process(_delta: float) -> bool:
	if _screen == null:
		_i += 1
		if _i >= _ids.size():
			quit()
			return true
		var f := MonsterFight.new(_ids[_i], 1)
		f.god = true
		f.player_hp = f.player_max * 0.62
		f.effects["poison"] = 4.0
		_screen = TourEncounterScreen.new()
		_screen.fight = f
		root.add_child(_screen)
		_frame = 0
		return false
	_frame += 1
	var f: MonsterFight = _screen.fight
	if f.telegraph() == "" and _frame < 1200:
		f.boss._timer_s = 99.0  # skip the wait for the first attack
	if f.telegraph() != "" and f.boss.telegraph_left_s < BossAttacks.tele_s(f.id, f.telegraph()) * 0.3:
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_prefix, f.id])
		_screen.queue_free()
		_screen = null
	return false
