class_name PixelFlagScreen
extends MenuScreen
## The 16x16 pixel flag editor: pick a palette colour, click squares to paint them.

var _pixels: Array = []
var _brush: int = 1
var _grid: Control


func _init() -> void:
	super()
	_title_key = "custom.pixel_flag"
	dim = 0.7


func build() -> void:
	var s: Dictionary = Session.state
	var saved: Array = Customization.get_custom(s)["flag"]["pixels"]
	if _pixels.is_empty():
		_pixels = saved.duplicate() if saved.size() == CustomizationData.PIXEL_SIZE * CustomizationData.PIXEL_SIZE else _blank()
	var palette := HBoxContainer.new()
	for i in CustomizationData.PIXEL_PALETTE.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.text = "x" if i == 0 else ""
		var sb := StyleBoxFlat.new()
		sb.bg_color = CustomizationData.PIXEL_PALETTE[i] if i > 0 else Color(0.2, 0.2, 0.2)
		b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func() -> void: _brush = i)
		palette.add_child(b)
	_box.add_child(palette)
	_grid = PixelGrid.new()
	_grid.set("owner_screen", self)
	_grid.custom_minimum_size = Vector2(384, 384)
	_box.add_child(_grid)
	add_button("custom.save", _save)
	add_button("custom.clear", func() -> void:
		_pixels = _blank()
		_grid.queue_redraw())
	add_button("menu.back", close)


static func _blank() -> Array:
	var a: Array = []
	a.resize(CustomizationData.PIXEL_SIZE * CustomizationData.PIXEL_SIZE)
	a.fill(0)
	return a


func paint(x: int, y: int) -> void:
	_pixels[y * CustomizationData.PIXEL_SIZE + x] = _brush
	_grid.queue_redraw()


func pixel(x: int, y: int) -> int:
	return int(_pixels[y * CustomizationData.PIXEL_SIZE + x])


func _save() -> void:
	Customization.set_pixels(Session.state, _pixels)
	close()


## The clickable grid.
class PixelGrid extends Control:
	var owner_screen: PixelFlagScreen
	const CELL: float = 24.0

	func _draw() -> void:
		for y in CustomizationData.PIXEL_SIZE:
			for x in CustomizationData.PIXEL_SIZE:
				var i: int = owner_screen.pixel(x, y)
				var c: Color = CustomizationData.PIXEL_PALETTE[i] if i > 0 else Color(0.18, 0.18, 0.2)
				draw_rect(Rect2(x * CELL, y * CELL, CELL - 1.0, CELL - 1.0), c)

	func _gui_input(event: InputEvent) -> void:
		var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		if not pressed:
			return
		var p: Vector2 = (event as InputEventMouse).position
		var x: int = int(p.x / CELL)
		var y: int = int(p.y / CELL)
		if x >= 0 and y >= 0 and x < CustomizationData.PIXEL_SIZE and y < CustomizationData.PIXEL_SIZE:
			owner_screen.paint(x, y)
