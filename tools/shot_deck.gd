extends SceneTree
## Renders a deck fight to a PNG: xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_deck.gd -- out.png

var _scene: DeckFightScene
var _frames: int = 0
var _out: String = "user://deck.png"
var _at: int = 100


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_at = int(args[1])
	GameInput.register()
	var s: Dictionary = SaveGame.new_state()
	for i in 12:
		s["roster"].append({"name": "Hand", "type": ["green", "seasoned", "swordsman", "gunner"][i % 4], "level": 1, "xp": 0})
	var c: DeckCombat = DeckBridge.build(13, 1.0, 70.0, "navy", 14, 1.0, 70.0, s, 9)
	_scene = DeckFightScene.new()
	root.add_child(_scene)
	_scene.start(c)
	root.size = Vector2i(1280, 720)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		return false
	DeckBridge.autopilot(_scene.combat, 1.0 / 60.0)
	if _frames == _at:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " t=", _scene.combat.time_s, " mine=", _scene.combat.standing_on_screen(0), " theirs=", _scene.combat.standing_on_screen(1))
		quit()
	return false
