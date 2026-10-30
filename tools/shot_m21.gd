extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m21.gd -- /tmp/m21
## The skills page, the captain's log and achievements, customize, the games table and a ship with custom sails.

var _prefix: String = "user://m21"
var _frames: int = 0
var _w: Node
const SHOTS: Array[int] = [30, 70, 110, 150, 190, 230]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _close() -> void:
	var l: Node = _w.get_node_or_null("MapLayer")
	if l != null:
		_w.remove_child(l)
		l.queue_free()


func _process(_d: float) -> bool:
	_frames += 1
	var st: Dictionary = Session.state
	match _frames:
		5:
			var bus: Node = Svc.node("EventBus")
			bus.ship_sunk.emit(Vector2(900.0, 900.0), "brigantine")
			bus.prize_taken.emit({"class_id": "frigate", "rival": ""})
			bus.boarding_resolved.emit(true, 11, true)
			Progression.add_xp(st, ProgressionData.xp_to_reach(9))
			for id in ["gunnery.reload", "gunnery.reload", "gunnery.spread", "seamanship.speed", "swordplay.damage", "trade.cargo", "leadership.hiring"]:
				Progression.spend(st, id)
			Achievements.record(st, "ships_sunk", 3.0)
			Achievements.check(st)
			CaptainLog.add(st, "discovery", "island", "Skull Atoll")
			CaptainLog.add(st, "tour", "tour_done", "The Drowned Purse")
			Customization.set_sail(st, 2, 2)
			Customization.set_flag(st, 4, 1, 1)
			Customization.set_hull(st, 2, 0, 1, false)
			Customization.set_figurehead(st, "siren")
			_w.apply_customization()
			_w.open_skills()
		30:
			_save("skills")
			_close()
			var j: JournalScreen = JournalScreen.new()
			j.tab = "achievements"
			_open(j)
		70:
			_save("achievements")
			_close()
			_w.open_log()
		110:
			_save("log")
			_close()
			_w.open_customize()
		150:
			_save("customize")
			_close()
			var layer := CanvasLayer.new()
			layer.name = "MapLayer"
			_w.add_child(layer)
			var m := MiniGameMenu.new()
			m.port_id = "blackwater"
			layer.add_child(m)
		190:
			_save("games")
			_close()
			var layer2 := CanvasLayer.new()
			layer2.name = "MapLayer"
			_w.add_child(layer2)
			layer2.add_child(DiceScreen.make(50, false, 12))
		230:
			_save("dice")
			_close()
			_w.ship.linear_velocity = Vector3.ZERO
		260:
			_save("ship")
			quit()
	return false


func _open(s: MenuScreen) -> void:
	var layer := CanvasLayer.new()
	layer.name = "MapLayer"
	layer.layer = 52
	_w.add_child(layer)
	layer.add_child(s)


func _save(n: String) -> void:
	var p: String = "%s_%s.png" % [_prefix, n]
	root.get_texture().get_image().save_png(p)
	print("saved ", p)
