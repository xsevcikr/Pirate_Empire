extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility --fixed-fps 30 -s res://tools/shot_boss_attacks.gd -- /tmp/atk [boss]
## Two pictures per boss attack on the fight stage: the tell (the wind-up and the red ring) and the moment it lands.

const STEPS: int = 14  ## frames the tell is held before the first picture
const AFTER: int = 5  ## frames after the hit before the second picture

var _prefix: String = "user://atk"
var _only: String = ""
var _jobs: Array[Array] = []
var _job: int = -1
var _frame: int = 0
var _stage: BossStage
var _fight: MonsterFight
var _caption: Label
var _vp: SubViewport


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	if args.size() > 1:
		_only = args[1]
	root.size = Vector2i(1280, 720)
	for id: String in BossModel.KINDS:
		if _only != "" and id != _only:
			continue
		for atk: String in BossAttacks.ATTACKS[id].keys():
			_jobs.append([id, atk])
	var ui := CanvasLayer.new()
	root.add_child(ui)
	_caption = Label.new()
	_caption.position = Vector2(24, 18)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 8)
	ui.add_child(_caption)


func _next() -> bool:
	if _stage != null:
		_stage.queue_free()
		_stage = null
	_job += 1
	if _job >= _jobs.size():
		return false
	var id: String = _jobs[_job][0]
	_fight = MonsterFight.new(id, 1)
	_fight.god = true
	_stage = BossStage.make(_fight)
	root.add_child(_stage)
	_frame = 0
	return true


func _hold_tell(atk: String, p: float) -> void:
	var tele: float = BossAttacks.tele_s(_fight.id, atk)
	_fight.boss.special_pending = atk
	_fight.boss.telegraph_left_s = tele * (1.0 - p)


func _process(delta: float) -> bool:
	if _job < 0 or _stage == null:
		if not _next():
			quit()
			return true
	var atk: String = _jobs[_job][1]
	_frame += 1
	if _frame <= STEPS:
		_hold_tell(atk, 0.25 + 0.55 * float(_frame) / float(STEPS))
		_stage.follow(delta, "")
		_caption.text = "%s: %s\n%s" % [Loc.t("atk." + atk), Loc.t(BossAttacks.answer_key(_fight.id, atk)), Loc.t("tell." + atk)]
		return false
	if _frame == STEPS + 1:
		_save("tell", atk)  # the viewport still holds the last frame drawn: the tell
		_fight.boss.special_pending = ""
		_fight.boss.telegraph_left_s = 0.0
		_fight.last_outcome = "hit"
		_stage.follow(delta, atk)
		_caption.text = Loc.t("fight.outcome.hit") % Loc.t("atk." + atk)
		return false
	if _frame == STEPS + 2 + AFTER:
		_save("hit", atk)
		_stage.queue_free()
		_stage = null
		return false
	_stage.follow(delta, "")
	return false


func _save(tag: String, atk: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s_%s_%s_%s.png" % [_prefix, _fight.id, atk, tag])
