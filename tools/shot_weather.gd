extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility --fixed-fps 30 -s res://tools/shot_weather.gd -- /tmp/wx
## Weather and the day: a clear morning, fog, a storm with rain and St Elmo's fire, the lightning strike, a red
## dusk, a clear night with stars and lanterns, and a storm by night. The game camera and HUD, as the player sees it.

const SHOTS: Array = [
	["clear_day", "clear", 10.5],
	["fog", "fog", 8.0],
	["storm", "storm", 14.0],
	["st_elmo", "storm", 14.0],
	["lightning", "storm", 14.0],
	["dusk", "clear", 17.6],
	["night", "clear", 22.5],
	["storm_night", "storm", 1.0],
]

var _shots: Array = SHOTS.duplicate()
var _prefix: String = "user://wx"
var _frames: int = 0
var _i: int = -1
var _at: int = 0
var _w: Node
var _ws: WeatherSystem
var _ship: Ship
var _others: Array[Ship] = []
var _struck: int = -1


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	if args.size() > 1:  # only these shots, comma separated
		var only: PackedStringArray = args[1].split(",")
		_shots.assign(SHOTS.filter(func(s: Array) -> bool: return only.has(s[0])))
	Session.begin_new("Rob", 1, 7)
	Session.state["ship_class"] = "brigantine"
	Session.state["ship_hull"] = 1.0
	Session.state["tutorial"] = "done"
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _next() -> void:
	_i += 1
	if _i >= _shots.size():
		quit()
		return
	var s: Array = _shots[_i]
	_ws.force = s[1]
	_ws.set_now(s[1])
	root.get_node("GameClock").hour = float(s[2])
	_at = _frames
	if s[0] == "st_elmo" or s[0] == "lightning":
		_ws.warn_lightning(_ship)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_ship = _w.ship
		_ws = _w.weather
		var at := Vector3(600.0, 0.3, 1400.0)
		_ship.global_position = at
		_ship.rotation = Vector3(0, deg_to_rad(-60.0), 0)
		_ship.sail_level = 2
		_others.append(_w._make_ship(load("res://data/ships/brigantine.tres"), at + Vector3(-30.0, 0, -70.0), 70.0, "navy"))
		_others.append(_w._make_ship(load("res://data/ships/sloop.tres"), at + Vector3(50.0, 0, -120.0), 120.0, "merchant"))
		for o in _others:
			o.sail_level = 1
		_ws.lightning.connect(func(_t: Ship, _r: Dictionary) -> void: _struck = _frames)
		_next()
		return false
	if _i < 0 or _i >= _shots.size():
		return false
	var name: String = _shots[_i][0]
	var due: bool = _frames - _at == 150
	if name == "st_elmo":
		due = _frames - _at == 60
	elif name == "lightning":
		due = _struck > 0 and _frames == _struck + 2
	if due:
		root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
		print("shot ", name)
		_struck = -1
		_next()
	return false
