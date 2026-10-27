class_name PortScreen
extends MenuScreen
## Base for the screens of a port: a header with gold and cargo, a scrolling list of rows, a back button.

var port_id: String = PortData.START_PORT
var _list: VBoxContainer


func _init() -> void:
	super()
	dim = 0.0


func state() -> Dictionary:
	return Session.state


func market() -> Market:
	return PortService.market_of(Session.state, port_id)


func save_market(m: Market) -> void:
	PortService.store_market(Session.state, port_id, m)


func _rebuild() -> void:
	var keep: float = 0.0
	var scroll: ScrollContainer = find_child("Scroll", true, false)
	if scroll != null:
		keep = scroll.scroll_vertical
	super()
	if keep > 0.0:
		_restore_scroll.call_deferred(keep)


func _restore_scroll(v: float) -> void:
	var scroll: ScrollContainer = find_child("Scroll", true, false)
	if scroll != null:
		scroll.scroll_vertical = int(v)


## Gold, cargo and food line under the title.
func add_header() -> void:
	var s: Dictionary = state()
	var l := Label.new()
	l.text = Loc.t("port.header") % [int(s["gold"]), PortService.cargo_used(s), PortService.cargo_capacity(s), PortService.food_days(s)]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func begin_list(height: float = 380.0) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_box.add_child(scroll)


func add_text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)
	return l


## A row with a description and buttons given as [[label, callable], ...]. A button whose callable is invalid is disabled.
func add_item_row(text: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	for spec: Array in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_ALL
		var cb: Callable = spec[1]
		if cb.is_valid():
			b.pressed.connect(cb)
		else:
			b.disabled = true
		row.add_child(b)
	_list.add_child(row)


func toast(key: String, args: Array = []) -> void:
	var text: String = Loc.t(key) % args if not args.is_empty() else Loc.t(key)
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)


func emit_bus(signal_name: String, args: Array) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.callv("emit_signal", [signal_name] + args)
