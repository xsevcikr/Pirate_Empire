class_name SaveGame
extends RefCounted
## Save data: a plain dictionary so it round-trips through JSON. Older versions are migrated on load.

const VERSION: int = 13
const SLOT_PATH: String = "user://save_%d.json"


static func new_state() -> Dictionary:
	return {
		"version": VERSION, "gold": 100, "hour": 9.0, "day": 0, "ship_class": "cutter", "ship_name": "The Driftwood",
		"ship_hull": 0.7, "crew": 0, "roster": [], "morale": 70.0, "cargo": {}, "upgrades": {}, "officers": [],
		"supplies": PortData.START_SUPPLIES.duplicate(), "ammo": {"round": WeaponData.SWIVEL_START_SHOTS, "chain": 0, "grape": 0, "heated": 0, "explosive": 0},
		"captain_hp": 100, "melee": "rusty_cutlass", "pistol": "flintlock", "pistol_shots": WeaponData.PISTOL_START_SHOTS,
		"owned_weapons": ["rusty_cutlass", "flintlock"], "fame": 0, "docked_at": PortData.START_PORT, "starter_exchange": true,
		"tutorial": "leave_dock", "captain_cut": Morale.CUT_DEFAULT, "captain_level": 1, "rum_ration": true, "wounded": 0,
		"starve_days": 0, "thirst_days": 0, "unpaid_days": 0, "death_accum": 0.0, "wound_accum": 0.0, "desert_accum": 0.0,
		"mutiny_shield_day": -99, "last_tick_day": 1, "offers_window": -1, "offers_taken": [], "quests": [], "quests_done": [], "map_fragments": [], "markets": {}, "log": [],
		"rep": Reputation.START_REP.duplicate(), "bounty": {}, "discovery": "", "streams_known": [], "course": [], "wrecks": [], "destroyed": {}, "tours": {}, "rivals": {}, "sea_events": {}, "prizes_taken": 0, "captain_xp": 0, "skills": {}, "skill_points_spent": 0, "stats": {}, "achievements": {}, "islands_seen": [], "trade_rem": 0, "custom": {}, "ship_damage": {}, "siren_paid": false, "act": 0, "beat": 0,
		"fleet": [], "bases": [], "convoys": [], "convoy_clock_h": 0.0, "convoy_seq": 0, "convoys_lost": 0, "bank": 0, "insured": false, "blockade": {}, "port_damage": {}, "marque": "", "seed": 1, "difficulty": 1,
		"captain": "", "pos": [0.0, 420.0], "yaw": -90.0, "sail_level": 0, "playtime": 0.0, "saved_at": 0,
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
	for k in ["version", "gold", "day", "crew", "act", "beat", "seed", "difficulty", "saved_at", "wounded", "starve_days", "thirst_days", "unpaid_days", "mutiny_shield_day", "last_tick_day", "captain_level", "captain_xp", "skill_points_spent", "trade_rem", "bank", "convoy_seq", "convoys_lost"]:
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
	if v < 4:
		# v4 adds the port-and-supplies layer. Old saves keep their own ship, gold and crew; the rest takes defaults.
		d["version"] = 4
	if v < 5:
		# v5 adds crew life: rations, wounded, wages and the loot cut. Defaults below fill them in.
		d["version"] = 5
	if v < 6:
		# v6 adds the living economy: convoys, bank, insurance, blockade counters and harbour damage.
		d["version"] = 6
	if v < 7:
		# v7 adds the named world: streams the player has sailed and the course set on the chart.
		d["version"] = 7
	if v < 8:
		# v8 adds destruction: wrecks left on the seabed and harbour buildings waiting to be rebuilt.
		d["version"] = 8
	if v < 9:
		# v9 adds the treasure tours: progress, hints bought, perks won. Fragments already in map_fragments stay.
		d["version"] = 9
	if v < 10:
		# v10 adds generated treasure maps and boss perks inside the tours record; nothing to convert.
		d["version"] = 10
	if v < 11:
		# v11 adds the rivals' memory, the random-event running totals and the count of prizes taken.
		d["version"] = 11
	if v < 12:
		# v12 adds captain XP, skills, lifetime stats, achievements, islands seen and the ship's look. An old save
		# keeps its captain level: its XP is what that level needs.
		d["captain_xp"] = ProgressionData.xp_to_reach(int(d.get("captain_level", 1)))
		d["version"] = 12
	if v < 13:
		# v13 adds crash breaches and damage control: the holes, water and fallen masts kept in ship_damage, and
		# canvas and tools among the supplies. An old ship sails on as it was, with none of the new stores.
		var sup: Dictionary = d.get("supplies", {})
		for k in ["canvas", "tools"]:
			if not sup.has(k):
				sup[k] = 0.0
		d["supplies"] = sup
		d["ship_damage"] = d.get("ship_damage", {})
		d["version"] = 13
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
