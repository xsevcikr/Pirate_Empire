extends SceneTree
## M14 acceptance: a 12 v 12 sloop boarding on screen, played through to the end, (the per-tick cost is bounded in test_deck.gd).
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m14_deck.gd

const MAX_FRAMES: int = 60 * 130

var _scene: DeckFightScene
var _frames: int = 0
var _failures: Array[String] = []
var _shown_12v12: bool = false
var _result: Dictionary = {}
var _done: bool = false


func _initialize() -> void:
	GameInput.register()
	var s: Dictionary = SaveGame.new_state()
	for i in 12:
		s["roster"].append({"name": "Hand", "type": "seasoned", "level": 1, "xp": 0})
	var c: DeckCombat = DeckBridge.build(13, 1.0, 70.0, "merchant", 12, 1.0, 70.0, s, 21)
	_scene = DeckFightScene.new()
	root.add_child(_scene)
	_scene.start(c)
	_scene.fight_over.connect(func(r: Dictionary) -> void:
		_result = r
		_done = true)
	_check(c.standing_on_screen(0) == 12 and c.standing_on_screen(1) == 12, "12 v 12 men on the deck at the start")
	_check(_scene._men.size() == 24 + 0 or _scene._men.size() == 25, "a capsule for every fighter (%d)" % _scene._men.size())


func _process(_delta: float) -> bool:
	if _done:
		_finish()
		return false
	_frames += 1
	var c: DeckCombat = _scene.combat
	if c.outcome == DeckCombat.Outcome.ONGOING:
		# a captain who fights back: advance on the nearest man, block when he winds up, swing, fire once
		var foe: FighterState = c.nearest_enemy(c.player)
		var i: Dictionary = {}
		if foe != null:
			var d: Vector2 = foe.pos - c.player.pos
			i["move"] = d.normalized() if d.length() > 1.6 else Vector2.ZERO
			i["block"] = foe.state == FighterState.State.SWING and d.length() < 2.4
			i["light"] = d.length() < 1.9
			i["fire"] = _frames == 20
		_scene.intent = i
	if _frames > MAX_FRAMES:
		_check(false, "fight never finished")
		_finish()
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	var c: DeckCombat = _scene.combat if is_instance_valid(_scene) else null
	_check(not _result.is_empty(), "the scene reported a result")
	if not _result.is_empty():
		_check(_result["time_s"] <= 120.0 + 0.1, "fight ends within the time limit (%.1f s)" % _result["time_s"])
		_check(_result["crew_left"] >= 0, "crew count is sane")
	print("M14 deck: %d frames, result won=%s crew_left=%s time=%.1f s" % [_frames, _result.get("player_won"), _result.get("crew_left"), _result.get("time_s", 0.0)])
	print("M14 deck: %s" % ("FAILED" if not _failures.is_empty() else "OK"))
	for f in _failures:
		print("  FAIL " + f)
	quit(1 if not _failures.is_empty() else 0)
