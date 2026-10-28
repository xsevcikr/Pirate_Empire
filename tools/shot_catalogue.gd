extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_catalogue.gd -- /tmp/cat
## The shipyard catalogue on each tab, and the outfitter's weapons, in the harbour of the start port.

var _prefix: String = "user://cat"
var _frames: int = 0
var _w: Node
var _screen: CatalogueScreen


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	var s: Dictionary = Session.state
	s["gold"] = 6500
	s["fame"] = 120
	s["ship_hull"] = 0.72
	s["upgrades"] = {"hull": 2, "sails": 1, "cannons": 4, "quarters": 5}
	s["owned_weapons"].append("cutlass")
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _open(screen: CatalogueScreen) -> void:
	var menu: PortMenu = _w.get_node("PortLayer").get_child(0)
	if _screen != null:
		_screen.closed.emit()
	_screen = screen
	menu._open(screen)


func _process(_d: float) -> bool:
	_frames += 1
	match _frames:
		10:
			_w.open_port()
		20:
			_open(ShipyardScreen.new())
		50:
			_shot("shipyard_ships")
			_screen.select("cat.upgrades")
		80:
			_shot("shipyard_upgrades")
			_screen.select("cat.services")
		110:
			_shot("shipyard_services")
			_open(OutfitterScreen.new())
		140:
			_shot("outfitter_weapons")
			_screen.select("cat.ammo")
		170:
			_shot("outfitter_ammo")
			quit(0)
			return true
	return false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
	print("shot ", name)
