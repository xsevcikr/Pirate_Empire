extends Node
## Player settings, stored in user://settings.cfg.

const PATH: String = "user://settings.cfg"
const PRESETS: PackedStringArray = ["low", "medium", "high", "ultra", "deck"]

var graphics_preset: String = "high"
var master_volume: float = 1.0
var locale: String = "en"
var accessibility := Accessibility.new()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "preset", graphics_preset)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("game", "locale", locale)
	cfg.set_value("access", "camera_shake", accessibility.camera_shake)
	cfg.set_value("access", "fov", accessibility.fov)
	cfg.set_value("access", "subtitles", accessibility.subtitles)
	cfg.set_value("access", "colorblind", accessibility.colorblind_markers)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var preset: String = cfg.get_value("graphics", "preset", graphics_preset)
	if PRESETS.has(preset):
		graphics_preset = preset
	master_volume = clampf(cfg.get_value("audio", "master", master_volume), 0.0, 1.0)
	var loc: String = cfg.get_value("game", "locale", locale)
	if Loc.locales().has(loc):
		locale = loc
	accessibility.set_camera_shake(cfg.get_value("access", "camera_shake", accessibility.camera_shake))
	accessibility.set_fov(cfg.get_value("access", "fov", accessibility.fov))
	accessibility.subtitles = cfg.get_value("access", "subtitles", accessibility.subtitles)
	accessibility.colorblind_markers = cfg.get_value("access", "colorblind", accessibility.colorblind_markers)
	apply()


## Push the values to the engine and tell listeners.
func apply() -> void:
	Loc.locale = locale
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	EventBus.settings_changed.emit()


func _ready() -> void:
	GameInput.register()
	Rebind.load_file()
	load_settings()
