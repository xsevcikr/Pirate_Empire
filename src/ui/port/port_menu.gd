class_name PortMenu
extends MenuScreen
## The hub of a port: market, shipyard, tavern, outfitter, quest board, and setting sail again.

var port_id: String = PortData.START_PORT
var world: Node


func _init() -> void:
	super()
	dim = 0.55


func _ready() -> void:
	_title_key = ""
	get_tree().paused = true
	super()


func build() -> void:
	var title := Label.new()
	title.text = PortData.PORTS[port_id]["name"]
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_box.move_child(title, 0)
	add_button("port.market", func() -> void: _open(MarketScreen.new()))
	add_button("port.shipyard", func() -> void: _open(ShipyardScreen.new()))
	add_button("port.tavern", func() -> void: _open(TavernScreen.new()))
	add_button("port.outfitter", func() -> void: _open(OutfitterScreen.new()))
	add_button("port.quests", func() -> void: _open(QuestBoardScreen.new()))
	add_button("port.set_sail", close)


func _open(screen: PortScreen) -> void:
	screen.port_id = port_id
	open_child(screen)


func close() -> void:
	get_tree().paused = false
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.port_undocked.emit(port_id)
	closed.emit()
	queue_free()
