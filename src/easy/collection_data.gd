class_name CollectionData
extends RefCounted
## Things to collect for the collection book: seashells (found in hidden loot the parrot spots near islands), flags
## (one from every faction whose ship you sink or capture, and rare pirate flags found in hidden loot) and ship
## cards (one for every class you sink, capture or own; the giants are the rare ones). Text keys "coll.<id>".

const SHELLS: Array[Dictionary] = [
	{"id": "shell_scallop", "weight": 30, "colour": Color(1.0, 0.72, 0.55)},
	{"id": "shell_spiral", "weight": 25, "colour": Color(0.98, 0.9, 0.75)},
	{"id": "shell_conch", "weight": 20, "colour": Color(1.0, 0.6, 0.65)},
	{"id": "shell_starfish", "weight": 15, "colour": Color(1.0, 0.5, 0.25)},
	{"id": "shell_sand_dollar", "weight": 8, "colour": Color(0.92, 0.88, 0.8)},
	{"id": "shell_pearl", "weight": 2, "colour": Color(0.95, 0.95, 1.0)},
]
## Faction flags come from ships of that faction; the "found" ones only from hidden loot.
const FLAGS: Array[Dictionary] = [
	{"id": "flag_navy", "faction": "navy", "cloth": Color(0.2, 0.32, 0.75), "mark": Color(1, 1, 1)},
	{"id": "flag_merchant", "faction": "merchant", "cloth": Color(0.95, 0.85, 0.3), "mark": Color(0.3, 0.55, 0.25)},
	{"id": "flag_pirate", "faction": "pirate", "cloth": Color(0.12, 0.12, 0.15), "mark": Color(1, 1, 1)},
	{"id": "flag_reef_folk", "faction": "reef_folk", "cloth": Color(0.15, 0.7, 0.7), "mark": Color(1.0, 0.6, 0.4)},
	{"id": "flag_iron_dominion", "faction": "iron_dominion", "cloth": Color(0.5, 0.52, 0.58), "mark": Color(0.85, 0.2, 0.15)},
	{"id": "flag_red_jack", "faction": "", "cloth": Color(0.8, 0.15, 0.15), "mark": Color(0.1, 0.1, 0.1)},
	{"id": "flag_golden_skull", "faction": "", "cloth": Color(0.15, 0.1, 0.25), "mark": Color(1.0, 0.8, 0.2)},
	{"id": "flag_rainbow", "faction": "", "cloth": Color(0.6, 0.3, 0.9), "mark": Color(1.0, 0.95, 0.4)},
]
const KINDS: PackedStringArray = ["shells", "flags", "ships"]


static func shell_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for s in SHELLS:
		out.append(str(s["id"]))
	return out


static func flag_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for f in FLAGS:
		out.append(str(f["id"]))
	return out


static func found_flag_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for f in FLAGS:
		if str(f["faction"]) == "":
			out.append(str(f["id"]))
	return out


static func flag_of_faction(faction: String) -> String:
	if faction == "":
		return ""
	for f in FLAGS:
		if f["faction"] == faction:
			return str(f["id"])
	return ""


static func ship_card(class_id: String) -> String:
	return "card_" + class_id


static func ship_card_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for c in PortData.CLASS_ORDER:
		out.append(ship_card(c))
	return out


static func is_rare_card(card_id: String) -> bool:
	return card_id.begins_with("card_") and PortData.is_giant(card_id.trim_prefix("card_"))


static func ids_of(kind: String) -> PackedStringArray:
	match kind:
		"shells":
			return shell_ids()
		"flags":
			return flag_ids()
		"ships":
			return ship_card_ids()
	return PackedStringArray()


static func entry(id: String) -> Dictionary:
	for s in SHELLS:
		if s["id"] == id:
			return s
	for f in FLAGS:
		if f["id"] == id:
			return f
	return {}


## The picture shown on the book's card: a primitive model for shells and flags, the ship's own Kenney model.
static func icon(id: String) -> String:
	if id.begins_with("card_"):
		return ShipyardCatalogue.ship_icon(id.trim_prefix("card_"))
	return "proc/" + id


static func icon_list() -> PackedStringArray:
	var out: PackedStringArray = []
	for kind in KINDS:
		for id in ids_of(kind):
			var ic: String = icon(id)
			if not out.has(ic):
				out.append(ic)
	out.append("proc/parrot")
	return out


## Name shown for an entry: ship cards use the ship's own name.
static func display_name(id: String) -> String:
	if id.begins_with("card_"):
		return Loc.t("ship." + id.trim_prefix("card_"))
	return Loc.t("coll." + id)
