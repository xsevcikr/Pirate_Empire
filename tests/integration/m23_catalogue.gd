extends SceneTree
## Shop catalogues in a live port: open the shipyard, flip tabs with page down, install an upgrade by pressing its
## card's button, then buy a musket at the outfitter. Both purchases must reach the event bus.

var _fails: Array[String] = []
var _frames: int = 0
var _w: Node
var _screen: CatalogueScreen
var _trades: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	Session.begin_new("Test", 1, 3)
	Session.state["gold"] = 5000
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _open(screen: CatalogueScreen) -> void:
	var menu: PortMenu = _w.get_node("PortLayer").get_child(0)
	if _screen != null:
		_screen.closed.emit()
	_screen = screen
	menu._open(screen)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _button(id: String) -> Button:
	return _screen.find_child("Buy_" + id.validate_node_name(), true, false) as Button


func _process(_d: float) -> bool:
	_frames += 1
	var s: Dictionary = Session.state
	match _frames:
		10:
			root.get_node("EventBus").trade_made.connect(func(kind: String, id: String, _u: float, _g: int) -> void: _trades.append(kind + ":" + id))
			_w.open_port()
		15:
			_open(ShipyardScreen.new())
		20:
			_check(_screen.category == "cat.ships", "the shipyard opens on ships")
			_check(_screen.find_child("Card_ship_" + str(s["ship_class"]), true, false) != null, "your own ship has a card")
			_press("ui_page_down")
		25:
			_check(_screen.category == "cat.upgrades", "page down moves to the upgrades tab, got %s" % _screen.category)
			var b: Button = _button("upg:hull")
			_check(b != null and not b.disabled, "hull upgrade can be installed")
			if b != null:
				b.pressed.emit()
		30:
			_check(int(s["upgrades"].get("hull", 0)) == 1, "hull upgrade installed")
			_check(int(s["gold"]) == 5000 - Upgrades.cost("hull", 1, s["ship_class"]), "upgrade paid for, gold %d" % s["gold"])
			_check(_trades.has("upgrade:upg:hull"), "upgrade reached the bus: %s" % str(_trades))
			_check(_screen.find_child("Pips", true, false) != null, "tier pips drawn")
			_open(OutfitterScreen.new())
		35:
			var b: Button = _button("weapon:musket")
			_check(b != null and not b.disabled, "musket for sale")
			if b != null:
				b.pressed.emit()
		40:
			_check(s["owned_weapons"].has("musket"), "musket bought")
			_check(_button("weapon:musket") == null, "an owned weapon has no buy button")
			_check(_trades.has("catalogue:weapon:musket"), "weapon purchase reached the bus")
			return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M23 PASS: shop catalogues")
		quit(0)
	else:
		for f in _fails:
			print("M23 FAIL: ", f)
		quit(1)
	return true
