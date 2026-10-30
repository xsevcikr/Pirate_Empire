class_name LoadingScreen
extends CanvasLayer
## Loads a scene on a thread behind a progress bar, then makes it the current scene.

signal loaded

var target_path: String = ""
var _bar: ProgressBar
var _requested: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	center.add_child(box)
	var l := Label.new()
	l.text = Loc.t("menu.loading")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	box.add_child(l)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	box.add_child(_bar)
	var tip := Label.new()
	tip.text = Loc.t("menu.tip_%d" % (randi() % 3))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	_requested = ResourceLoader.load_threaded_request(target_path) == OK


func _process(_delta: float) -> void:
	if not _requested:
		return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_path, progress)
	if progress.size() > 0:
		_bar.value = progress[0]
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_requested = false
		var packed: PackedScene = ResourceLoader.load_threaded_get(target_path)
		var scene: Node = packed.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		loaded.emit()
		queue_free()
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		_requested = false
		push_error("Could not load " + target_path)
		Session.quit_to_menu(get_tree())
		queue_free()
