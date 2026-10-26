extends Node
## Player settings, stored in user://settings.cfg.

const PATH: String = "user://settings.cfg"
const PRESETS: PackedStringArray = ["low", "medium", "high", "ultra", "deck"]

var graphics_preset: String = "high"
var master_volume: float = 1.0


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "preset", graphics_preset)
	cfg.set_value("audio", "master", master_volume)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var preset: String = cfg.get_value("graphics", "preset", graphics_preset)
	if PRESETS.has(preset):
		graphics_preset = preset
	master_volume = clampf(cfg.get_value("audio", "master", master_volume), 0.0, 1.0)
	EventBus.settings_changed.emit()


func _ready() -> void:
	load_settings()
