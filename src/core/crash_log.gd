class_name CrashLog
extends RefCounted
## Detects an unclean previous exit via a marker file, and keeps a small rolling session log.

const MARKER: String = "user://session.lock"
const LOG: String = "user://last_session.log"
const MAX_LINES: int = 500

static var _lines: PackedStringArray = PackedStringArray()


## Call at boot. Returns true if the previous session did not exit cleanly.
static func begin(marker: String = MARKER) -> bool:
	var crashed: bool = FileAccess.file_exists(marker)
	var f := FileAccess.open(marker, FileAccess.WRITE)
	if f:
		f.store_string(str(Time.get_unix_time_from_system()))
	return crashed


## Call on a clean quit.
static func end(marker: String = MARKER) -> void:
	if FileAccess.file_exists(marker):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))


static func log_line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)


static func flush(path: String = LOG) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines))


static func line_count() -> int:
	return _lines.size()
