extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m18.gd -- journal.png encounter.png
## The treasure journal with a map joined and hints opened, and the Shell King fight panel mid-telegraph.

var _out1: String = "user://m18_journal.png"
var _out2: String = "user://m18_fight.png"
var _frames: int = 0
var _w: Node
var _fight: MonsterFight


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out1 = args[0]
	if args.size() > 1:
		_out2 = args[1]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	var st: Dictionary = Session.state
	if _frames == 5:
		for n in 3:
			MapFragments.add(st, TourData.fragment_id("drowned_purse", n + 1))
		var d: TourDirector = _w.tours
		while TourState.progress(st, "drowned_purse")["step"] == 0:
			d.rotate_piece("drowned_purse", MapFragments.next_piece(d.puzzle_turns("drowned_purse")))
		TourState.hint(st, "drowned_purse", 1)
		TourState.hint(st, "drowned_purse", 2)
		var at: Vector2 = TourData.step_pos(TourData.steps("drowned_purse")[1])
		_w.ship.global_position = Vector3(at.x + 300.0, 0.5, at.y)
		_w.open_journal()
	if _frames == 40:
		root.get_texture().get_image().save_png(_out1)
		print("saved ", _out1)
		_w.get_node("MapLayer").queue_free()
		TourState.progress(st, "drowned_purse")["step"] = 4
		_fight = _w.tours.start_guardian("drowned_purse")
		var screen := TourEncounterScreen.new()
		screen.director = _w.tours
		screen.tour_id = "drowned_purse"
		screen.fight = _fight
		var layer := CanvasLayer.new()
		layer.name = "MapLayer"
		layer.layer = 52
		_w.add_child(layer)
		layer.add_child(screen)
		_fight.boss.damage(300.0)
	if _frames > 40 and _frames < 400 and _fight != null and _fight.telegraph() == "" and _frames % 2 == 0:
		_fight.tick(0.1)
	if _frames == 400 or (_frames > 60 and _fight != null and _fight.telegraph() != "" and _fight.boss.telegraph_left_s < 1.2):
		root.get_texture().get_image().save_png(_out2)
		print("saved ", _out2)
		quit()
	return false
