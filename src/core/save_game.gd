class_name SaveGame
extends RefCounted
## Save data: a plain dictionary so it round-trips through JSON. Older versions are migrated on load.

const VERSION: int = 3
const SLOT_PATH: String = "user://save_%d.json"


static func new_state() -> Dictionary:
	return {
		"version": VERSION, "gold": 2000, "hour": 17.3, "day": 0, "ship_class": "sloop", "ship_hull": 1.0,
		"crew": 12, "morale": 70.0, "cargo": {}, "upgrades": {}, "officers": [],
		"rep": Reputation.START_REP.duplicate(), "bounty": {}, "discovery": "", "act": 0, "beat": 0,
		"fleet": [], "bases": [], "marque": "", "seed": 1, "difficulty": 1,
		"captain": "", "pos": [0.0, 420.0], "yaw": -90.0, "sail_level": 3, "playtime": 0.0, "saved_at": 0,
	}


static func to_json(state: Dictionary) -> String:
	return JSON.stringify(state)


static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return migrate(_restore_types(json.data))


## JSON turns ints into floats; put the integer fields back so a round trip compares equal.
static func _restore_types(d: Dictionary) -> Dictionary:
	for k in ["version", "gold", "day", "crew", "act", "beat", "seed", "difficulty", "saved_at"]:
		if d.has(k):
			d[k] = int(d[k])
	return d


static func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 1))
	if v < 2:
		# v1 stored a single "reputation" number and "money"; v2 has per-faction rep and "gold".
		if d.has("money"):
			d["gold"] = int(d["money"])
			d.erase("money")
		if d.has("reputation"):
			var rep: Dictionary = Reputation.START_REP.duplicate()
			rep["navy"] = float(d["reputation"])
			d["rep"] = rep
			d.erase("reputation")
		d["fleet"] = d.get("fleet", [])
		d["bases"] = d.get("bases", [])
		d["marque"] = ""
		d["version"] = 2
	if v < 3:
		# v3 adds the world position and slot metadata; the defaults below fill them in.
		d["version"] = 3
	var base: Dictionary = new_state()
	for k in base.keys():
		if not d.has(k):
			d[k] = base[k]
	return _restore_types(d)


static func capture_discovery(d: Discovery) -> String:
	return Marshalls.raw_to_base64(d.to_bytes())


static func restore_discovery(s: String) -> Discovery:
	return Discovery.from_bytes(Marshalls.base64_to_raw(s)) if s != "" else Discovery.new()


static func write(state: Dictionary, slot: int) -> bool:
	var f := FileAccess.open(SLOT_PATH % slot, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_json(state))
	return true


static func read(slot: int) -> Dictionary:
	var f := FileAccess.open(SLOT_PATH % slot, FileAccess.READ)
	if f == null:
		return {}
	return from_json(f.get_as_text())
