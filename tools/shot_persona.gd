extends SceneTree
## Renders crew personalities and loyalty to PNGs:
##   xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_persona.gd -- <mode> out.png
## modes: crew (the crew screen's roster with traits and loyalty), mutiny (ringleader and loyal hands),
## deck (the deck fight with the named hands, the brave rallying and the cowards hanging back)

var _scene: DeckFightScene
var _frames: int = 0
var _mode: String = "crew"
var _out: String = "user://persona.png"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if args.size() > 1:
		_out = args[1]
	GameInput.register()
	var s: Dictionary = SaveGame.new_state()
	var names: Array[String] = ["Bones", "Mags", "Finn", "Patch", "Old Tom", "Red Ned", "Sully", "Kit", "Dutch", "Wren", "Hob", "Jory"]
	var traits: Array[String] = ["brave", "greedy", "cheerful", "coward", "drunkard", "hothead", "steadfast", "superstitious", "brave", "greedy", "coward", "cheerful"]
	var loyal: Array[float] = [92.0, 41.0, 74.0, 14.0, 33.0, 58.0, 85.0, 47.0, 66.0, 22.0, 9.0, 81.0]
	for i in 12:
		s["roster"].append({"name": names[i], "type": ["carpenter", "seasoned", "swordsman", "gunner", "green", "musketeer"][i % 6], "level": 1 + i % 3,
			"xp": 40 * i, "trait": traits[i], "loyalty": loyal[i]})
	s["crew"] = 30
	s["morale"] = 12.0 if _mode == "mutiny" else 64.0
	s["gold"] = 2400
	Session.state = s
	root.size = Vector2i(1600, 900)
	var c: DeckCombat = DeckBridge.build(13, 1.0, 70.0, "merchant", 14, 1.0, 60.0, s, 4)
	_scene = DeckFightScene.new()
	root.add_child(_scene)
	_scene.start(c)
	if _mode == "deck":
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	layer.add_child(CrewScreen.new() if _mode == "crew" else MutinyScreen.new())


func _process(_delta: float) -> bool:
	_frames += 1
	if _mode == "deck" and _frames > 1:
		DeckBridge.autopilot(_scene.combat, 1.0 / 60.0)
	if _frames == (200 if _mode == "deck" else 30):
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
