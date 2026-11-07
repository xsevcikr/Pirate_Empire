extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_bounty.gd -- out_prefix
## Two pictures: the sea with three navy stars on the wanted badge and a wave of hunters astern, and the wanted board
## in a pirate haven with bounties to bribe down, navy rewards owed and the crews' posters.

var _prefix: String = "user://bounty"
var _frames: int = 0
var _w: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	var st: Dictionary = Session.state
	if _frames == 5:
		st["fame"] = 160
		Bounty.set_value(st, "navy", 320.0)
		Bounty.set_value(st, "merchant", 80.0)
		st["bounty_claims"] = 540
		st["gold"] = 25000
		var p: Vector3 = _w.ship.global_position
		var fwd: Vector3 = -_w.ship.global_transform.basis.z
		var side: Vector3 = fwd.cross(Vector3.UP)
		var a: Ship = _w.bounties.spawn_hunter("frigate", "navy", 0)
		var b: Ship = _w.bounties.spawn_hunter("brigantine", "navy", 1)
		a.global_position = p + fwd * 110.0 + side * 45.0
		b.global_position = p + fwd * 170.0 - side * 50.0
	if _frames == 60:
		root.get_texture().get_image().save_png(_prefix + "_sea.png")
		print("saved sea")
		_w.ship.global_position = Vector3(0.0, _w.ship.global_position.y, 360.0)
		_w.open_port()
		var menu: PortMenu = _w.get_node("PortLayer").get_child(0) as PortMenu
		menu._open(WantedBoardScreen.new())
	if _frames == 90:
		root.get_texture().get_image().save_png(_prefix + "_board.png")
		print("saved board")
		quit()
	return false
