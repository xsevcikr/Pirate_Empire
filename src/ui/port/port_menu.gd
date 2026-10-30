class_name PortMenu
extends MenuScreen
## The hub of a port: market, shipyard, tavern, outfitter, quest board, and setting sail again.

var port_id: String = PortData.START_PORT
var world: Node
## Came ashore with F: straight into the street with the crew, and walking back onto the pier sets sail again.
var on_foot: bool = false
var _district: DockDistrict


func _init() -> void:
	super()
	dim = 0.55


func _ready() -> void:
	_title_key = ""
	get_tree().paused = true
	super()
	if on_foot:
		visible = false
		walk_ashore.call_deferred()


func build() -> void:
	var title := Label.new()
	title.text = PortData.PORTS[port_id]["name"]
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_box.move_child(title, 0)
	add_button("port.walk", _walk_the_docks)
	add_button("port.market", func() -> void: _open(MarketScreen.new()))
	add_button("port.shipyard", func() -> void: _open(ShipyardScreen.new()))
	add_button("port.tavern", func() -> void: _open(TavernScreen.new()))
	add_button("port.outfitter", func() -> void: _open(OutfitterScreen.new()))
	add_button("port.quests", func() -> void: _open(QuestBoardScreen.new()))
	if Finance.has_bank(port_id):
		add_button("port.bank", func() -> void: _open(BankScreen.new()))
	add_button("port.set_sail", close)


func _walk_the_docks() -> void:
	if _district != null and is_instance_valid(_district):
		return
	_district = DockDistrict.new()
	_district.port_id = port_id
	if on_foot and Session.has_state():
		_district.shore_party = Mooring.shore_party(Session.state["roster"])
		_district.ship_class = str(Session.state["ship_class"])
	get_tree().current_scene.add_child(_district)
	visible = false
	_district.door_used.connect(_on_door)
	_district.left.connect(func() -> void:
		_district = null
		if on_foot:  # back up the gangway: the walk ashore was the whole visit
			close()
			return
		visible = true
		_rebuild())


## Ashore with the crew: the dock district at once, with the ship tied up at the pier behind them.
func walk_ashore() -> void:
	if is_inside_tree():
		_walk_the_docks()


func _on_door(kind: String) -> void:
	match kind:
		"market":
			_open(MarketScreen.new())
		"shipyard":
			_open(ShipyardScreen.new())
		"tavern":
			_open(TavernScreen.new())
		"outfitter":
			_open(OutfitterScreen.new())
		"quests":
			_open(QuestBoardScreen.new())
		"bank":
			_open(BankScreen.new())


func _on_child_closed(screen: MenuScreen) -> void:
	super(screen)
	if _district != null and is_instance_valid(_district):
		visible = false
		_district.active = true


func _open(screen: PortScreen) -> void:
	screen.port_id = port_id
	open_child(screen)


func close() -> void:
	if _district != null and is_instance_valid(_district):
		_district.queue_free()
	get_tree().paused = false
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.port_undocked.emit(port_id)
	closed.emit()
	queue_free()
