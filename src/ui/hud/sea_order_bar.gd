class_name SeaOrderBar
extends CanvasLayer
## The crew's order buttons at sea, along the bottom of the screen: Attack, Load cannons, Fire!, Retreat, Repair,
## and a pull of rum for the captain. F1-F6 press them from the keyboard.

const BUTTONS: Array[String] = ["orders.attack", "orders.load", "orders.fire", "orders.retreat", "orders.repair", "orders.rum"]
const ORDER_OF: Array[int] = [CrewOrders.Order.ATTACK, CrewOrders.Order.LOAD, CrewOrders.Order.FIRE, CrewOrders.Order.RETREAT,
	CrewOrders.Order.REPAIR, -1]

signal drink_pressed

var controller: PlayerController
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 6
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -420.0
	bar.offset_right = 420.0
	bar.offset_top = -132.0
	bar.offset_bottom = -88.0
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	for i in BUTTONS.size():
		var b := Button.new()
		b.text = "F%d %s" % [i + 1, Loc.t(BUTTONS[i])]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = ORDER_OF[i] != CrewOrders.Order.FIRE and ORDER_OF[i] >= 0
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 16)
		b.set_meta("kind", "sea_order_button")
		b.pressed.connect(press.bind(i))
		bar.add_child(b)
		_buttons.append(b)


func press(i: int) -> void:
	Sfx.play("ui_click")
	if ORDER_OF[i] < 0:
		drink_pressed.emit()
	elif controller != null:
		controller.give_order(ORDER_OF[i] as CrewOrders.Order)


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var idx: int = k.physical_keycode - KEY_F1
	if idx >= 0 and idx < BUTTONS.size():
		press(idx)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if controller == null:
		return
	for i in _buttons.size():
		if _buttons[i].toggle_mode:
			_buttons[i].set_pressed_no_signal(controller.order == ORDER_OF[i])
