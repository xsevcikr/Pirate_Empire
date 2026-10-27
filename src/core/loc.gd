class_name Loc
extends RefCounted
## Localization hook: string tables from data/i18n/strings.csv with English fallback.

const PATH: String = "res://data/i18n/strings.csv"

static var _table: Dictionary = {}  ## locale -> {key -> text}
static var locale: String = "en"


static func load_table(path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	_table.clear()
	var header: PackedStringArray = f.get_csv_line()
	for col in range(1, header.size()):
		_table[header[col]] = {}
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		for col in range(1, mini(row.size(), header.size())):
			_table[header[col]][row[0]] = row[col]
	return true


static func t(key: String) -> String:
	if _table.is_empty():
		load_table()
	var loc: Dictionary = _table.get(locale, {})
	if loc.has(key) and loc[key] != "":
		return loc[key]
	var en: Dictionary = _table.get("en", {})
	return en.get(key, key)


static func locales() -> Array:
	if _table.is_empty():
		load_table()
	return _table.keys()
