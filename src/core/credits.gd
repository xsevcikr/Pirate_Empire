class_name Credits
extends RefCounted

const PATH: String = "res://data/credits.txt"


static func text() -> String:
	var f := FileAccess.open(PATH, FileAccess.READ)
	return f.get_as_text() if f else ""
