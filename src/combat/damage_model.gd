class_name DamageModel
extends RefCounted
## Local damage: hull sections, flooding, fire, masts, sails, rudder and magazine (spec section 5).

signal section_breached(index: int)
signal mast_fell(index: int)
signal fire_started(index: int)
signal magazine_exploded
signal sank
signal breach_opened(index: int)
signal breach_changed(index: int)

const LEAK_BASE_T_PER_S: float = 0.04  # for a 40-damage hit below the waterline
const BAIL_T_PER_S_PER_4_CREW: float = 0.05
const BREACH_MIN_LEAK_T_PER_S: float = 0.12
const FLOOD_CAPACITY_SHARE: float = 0.5  # sinks when water reaches 50% of displacement
const FIRE_HULL_DPS: float = 8.0
const FIRE_SAIL_DPS: float = 4.0
const RICOCHET_ANGLE_DEG: float = 25.0
const HULL_SEA_CAP: float = 0.6  # repairs at sea bring a section back to 60% at most
const BREACH_MERGE_M: float = 1.6  # a fresh hit this close to an open hole makes the hole bigger instead
## How much of a breach's water still gets in, by the state of the repair on it.
const BREACH_LEAK_SHARE: Dictionary = {"open": 1.0, "stuffed": 0.5, "fothered": 0.25, "patched": 0.0}

var stats: ShipStats
var section_count: int = 4
var section_hp: PackedFloat32Array = PackedFloat32Array()
var section_max: float = 0.0
var water_t: PackedFloat32Array = PackedFloat32Array()
var leak_rate: PackedFloat32Array = PackedFloat32Array()
var fire_level: PackedInt32Array = PackedInt32Array()
var mast_hp: PackedFloat32Array = PackedFloat32Array()
var mast_max: float = 0.0
var mast_down: Array[bool] = []
var sail_hp: PackedFloat32Array = PackedFloat32Array()
var sail_max: float = 0.0
var rudder_hp: float = 0.0
var magazine_alive: bool = true
var sunk: bool = false
var rain: bool = false
var rng := RandomNumberGenerator.new()
## Holes torn by collisions: {section, pos (ship space), size 1-3, leak (t/s when open), state, work}. A patched
## hole stays on the list (and on the hull, as a plank patch) until a shipyard repairs the ship.
var breaches: Array[Dictionary] = []
## Damage control for the player's ship. When set, it does the bailing, patching, fire fighting and repair;
## without it (AI ships) the older automatic rules in tick() do.
var control: DamageControl = null

var _fire_timer: float = 0.0
var _extinguish_progress: float = 0.0
var _patch_timer: float = 0.0
var _repair_accum: float = 0.0


func _init(ship_stats: ShipStats, seed_value: int = 0) -> void:
	stats = ship_stats
	rng.seed = seed_value if seed_value != 0 else randi()
	section_count = stats.section_count
	section_max = stats.hull_hp / section_count
	for i in section_count:
		section_hp.append(section_max)
		water_t.append(0.0)
		leak_rate.append(0.0)
		fire_level.append(0)
	mast_max = stats.sail_hp * 0.25
	sail_max = stats.sail_hp / maxf(stats.mast_count, 1)
	for i in stats.mast_count:
		mast_hp.append(mast_max)
		sail_hp.append(sail_max)
		mast_down.append(false)
	rudder_hp = stats.rudder_hp


func displacement_t() -> float:
	return stats.mass_kg / 1000.0


func hull_hp_total() -> float:
	var t: float = 0.0
	for h in section_hp:
		t += h
	return t


func hull_fraction() -> float:
	return hull_hp_total() / stats.hull_hp


func water_total() -> float:
	var t: float = 0.0
	for w in water_t:
		t += w
	return t


func flood_fraction() -> float:
	return clampf(water_total() / (displacement_t() * FLOOD_CAPACITY_SHARE), 0.0, 1.0)


## 0..1: surviving sail area times sail condition.
func sail_health() -> float:
	var total: float = 0.0
	for i in stats.mast_count:
		if not mast_down[i]:
			total += sail_hp[i] / sail_max
	return total / maxf(stats.mast_count, 1)


func rudder_fraction() -> float:
	return rudder_hp / stats.rudder_hp


## Section for a hit at `local` (ship space, forward is -Z, starboard +X).
func section_for(local: Vector3) -> int:
	var half_len: float = stats.length_m * 0.5
	var along: float = clampf((local.z + half_len) / stats.length_m, 0.0, 0.9999)  # 0 = bow, 1 = stern
	var starboard: bool = local.x >= 0.0
	if section_count == 4:
		if along < 0.2:
			return 0
		if along > 0.8:
			return 3
		return 2 if starboard else 1
	# 8 sections: bow, fore P/S, mid P/S, aft P/S, stern
	if along < 0.1:
		return 0
	if along > 0.9:
		return 7
	var band: int = clampi(int((along - 0.1) / (0.8 / 3.0)), 0, 2)
	return 1 + band * 2 + (1 if starboard else 0)


func section_is_starboard(i: int) -> bool:
	if section_count == 4:
		return i == 2
	return i != 0 and i != 7 and (i - 1) % 2 == 1


func neighbours(i: int) -> Array[int]:
	var out: Array[int] = []
	out.append((i + 1) % section_count)
	out.append((i - 1 + section_count) % section_count)
	return out


## Applies one cannonball. Returns what happened, for effects and tests.
func apply_hit(hit: HitInfo) -> Dictionary:
	var ammo: Dictionary = GunData.AMMO[hit.ammo_id]
	var result: Dictionary = {"hull": 0.0, "sail": 0.0, "killed": 0, "ricochet": false, "rigging": false,
		"section": -1, "leak": 0.0, "mast_fell": -1, "fire": false, "magazine": false}
	if sunk:
		return result
	var grazing: float = 90.0 - rad_to_deg(acos(clampf(-hit.direction.dot(hit.local_normal), -1.0, 1.0)))
	var scale: float = 1.0
	if grazing < RICOCHET_ANGLE_DEG and hit.ammo_id != "explosive":
		scale = 0.2
		result["ricochet"] = true
	var section: int = section_for(hit.local_position)
	result["section"] = section

	if not hit.below_waterline and mast_hp.size() > 0 and rng.randf() < ammo["rigging"]:
		result["rigging"] = true
		var m: int = rng.randi() % mast_hp.size()
		while mast_down[m] and not _all_masts_down():
			m = rng.randi() % mast_hp.size()
		var sdmg: float = hit.damage * ammo["sail"] * scale
		sail_hp[m] = maxf(sail_hp[m] - sdmg, 0.0)
		mast_hp[m] = maxf(mast_hp[m] - sdmg * 0.25, 0.0)
		result["sail"] = sdmg
		var snap: bool = hit.ammo_id == "chain" and mast_hp[m] < mast_max * 0.25 and rng.randf() < 0.15
		var crit: float = (hit.source as Ship).broadside.mast_crit if hit.source is Ship else 0.0
		if crit > 0.0 and mast_hp[m] < mast_max * 0.5 and rng.randf() < crit:
			snap = true
		if (mast_hp[m] <= 0.0 or snap) and not mast_down[m]:
			mast_down[m] = true
			result["mast_fell"] = m
			mast_fell.emit(m)
			if rng.randf() < 0.3:
				result["killed"] += rng.randi_range(2, 6)
		return result

	var armor_factor: float = 100.0 / (100.0 + stats.armor)
	var dmg: float = hit.damage * ammo["hull"] * armor_factor * scale
	if hit.below_waterline:
		dmg *= 1.5
	result["hull"] = dmg
	# Damage beyond a destroyed section spills into its neighbours.
	var remaining: float = dmg
	var target_section: int = section
	for _hop in section_count:
		var before: float = section_hp[target_section]
		var taken: float = minf(before, remaining)
		section_hp[target_section] = before - taken
		remaining -= taken
		if before > 0.0 and section_hp[target_section] <= 0.0:
			leak_rate[target_section] = maxf(leak_rate[target_section] * 3.0, BREACH_MIN_LEAK_T_PER_S)
			section_breached.emit(target_section)
		if remaining <= 0.0:
			break
		var opts: Array[int] = neighbours(target_section)
		target_section = opts[rng.randi() % opts.size()]
	if hit.below_waterline and not result["ricochet"]:
		var leak: float = LEAK_BASE_T_PER_S * hit.damage / 40.0
		leak_rate[section] += leak
		result["leak"] = leak
	# Casualties
	if hit.ammo_id == "grape":
		result["killed"] += int(round(ammo["crew"] * rng.randf_range(0.5, 2.0)))
	elif not result["ricochet"] and rng.randf() < 0.3:
		result["killed"] += rng.randi_range(1, 3)
	# Fire
	if ammo["fire"] > 0.0 and not result["ricochet"] and rng.randf() < ammo["fire"]:
		ignite(section)
		result["fire"] = true
	# Magazine
	if hit.below_waterline and section_count > 0 and absf(hit.local_position.z) < stats.length_m * 0.25:
		var chance: float = 0.005 * (4.0 if fire_level[section] > 0 else 1.0)
		if magazine_alive and rng.randf() < chance:
			magazine_alive = false
			result["magazine"] = true
			var burst: float = stats.hull_hp * 0.4 / section_count
			for i in section_count:
				section_hp[i] = maxf(section_hp[i] - burst, 0.0)
			magazine_exploded.emit()
	_check_sunk()
	return result


## Applies a collision of `dmg` hull damage to the section that touched, spilling into neighbours like a cannonball.
## `leak_t_per_s` is added to that section when the hit was big enough to open one. Returns what happened.
func apply_impact(section: int, dmg: float, leak_t_per_s: float, breaks_mast: bool) -> Dictionary:
	var result: Dictionary = {"hull": dmg, "breached": false, "mast_fell": -1}
	var remaining: float = dmg
	var target: int = clampi(section, 0, section_count - 1)
	for _hop in section_count:
		var before: float = section_hp[target]
		var taken: float = minf(before, remaining)
		section_hp[target] = before - taken
		remaining -= taken
		if before > 0.0 and section_hp[target] <= 0.0:
			leak_rate[target] = maxf(leak_rate[target] * 3.0, BREACH_MIN_LEAK_T_PER_S)
			section_breached.emit(target)
			result["breached"] = true
		if remaining <= 0.0:
			break
		target = neighbours(target)[rng.randi() % 2]
	if leak_t_per_s > 0.0:
		leak_rate[section] += leak_t_per_s
	if breaks_mast:
		for i in mast_hp.size():
			if not mast_down[i]:
				mast_hp[i] = 0.0
				mast_down[i] = true
				result["mast_fell"] = i
				mast_fell.emit(i)
				break
	_check_sunk()
	return result


func ignite(section: int) -> void:
	if fire_level[section] == 0:
		fire_level[section] = 1
		fire_started.emit(section)


func _all_masts_down() -> bool:
	for d in mast_down:
		if not d:
			return false
	return true


func _check_sunk() -> void:
	if sunk:
		return
	if hull_hp_total() <= 0.0 or flood_fraction() >= 1.0:
		sunk = true
		sank.emit()


## Advances flooding, bailing, fire and repair by `dt` seconds.
func tick(dt: float, repair_crew: float) -> void:
	if sunk:
		return
	# Flooding
	for i in section_count:
		water_t[i] += leak_rate[i] * dt
	if control == null:
		bail(repair_crew / 4.0 * BAIL_T_PER_S_PER_4_CREW * dt)
		# Patch the biggest leak every 12 s while crew are repairing
		if repair_crew >= 1.0:
			_patch_timer += dt
			if _patch_timer >= 12.0:
				_patch_timer = 0.0
				var big: int = 0
				for i in section_count:
					if leak_rate[i] > leak_rate[big]:
						big = i
				for b in breaches.size():
					if int(breaches[b]["section"]) == big:
						set_breach_state(b, "patched")
				leak_rate[big] = 0.0
	# Fire
	var any_fire: bool = false
	for i in section_count:
		if fire_level[i] > 0:
			any_fire = true
			section_hp[i] = maxf(section_hp[i] - FIRE_HULL_DPS * fire_level[i] * dt, 0.0)
			if fire_level[i] >= 3 and stats.mast_count > 0:
				var m: int = i % stats.mast_count
				sail_hp[m] = maxf(sail_hp[m] - FIRE_SAIL_DPS * dt, 0.0)
	if any_fire:
		_fire_timer += dt
		if _fire_timer >= 5.0:
			_fire_timer = 0.0
			_spread_fire()
		if control == null:
			fight_fire(repair_crew / 3.0 * dt / 6.0)
	if control == null:
		# Slow repair of hull sections up to 60% by the repair crew
		_repair_accum += repair_crew / 4.0 * 0.5 * dt
		if _repair_accum >= 1.0:
			var amount: float = floorf(_repair_accum)
			_repair_accum -= amount
			repair_hull(amount)
	_check_sunk()


## Pumps `tonnes` out of the wettest compartments first. Returns what was actually pumped.
func bail(tonnes: float) -> float:
	var left: float = tonnes
	while left > 0.0:
		var worst: int = 0
		for i in section_count:
			if water_t[i] > water_t[worst]:
				worst = i
		if water_t[worst] <= 0.0:
			break
		var take: float = minf(left, water_t[worst])
		water_t[worst] -= take
		left -= take
	return tonnes - left


## Fire fighting: every whole unit of `progress` takes one level off the worst fire.
func fight_fire(progress: float) -> void:
	_extinguish_progress += progress
	while _extinguish_progress >= 1.0:
		_extinguish_progress -= 1.0
		_reduce_one_fire()


## Puts up to `hp` back into the weakest damaged section, never past the sea cap. Returns HP repaired.
func repair_hull(hp: float) -> float:
	var weakest: int = -1
	for i in section_count:
		if section_hp[i] > 0.0 and section_hp[i] < section_max * HULL_SEA_CAP:
			if weakest == -1 or section_hp[i] < section_hp[weakest]:
				weakest = i
	if weakest == -1:
		return 0.0
	var before: float = section_hp[weakest]
	section_hp[weakest] = minf(before + hp, section_max * HULL_SEA_CAP)
	return section_hp[weakest] - before


## The deck-fight repair party: `amount` HP spread over the weakest sections in turn, to the same sea cap as
## repair_hull. Returns the HP actually put back.
func patch_hull(amount: float) -> float:
	var left: float = amount
	while left > 0.001:
		var got: float = repair_hull(left)
		if got <= 0.0:
			break
		left -= got
	return amount - left


## HP the crew could still put back at sea.
func hull_repairable() -> float:
	var t: float = 0.0
	for i in section_count:
		if section_hp[i] > 0.0:
			t += maxf(section_max * HULL_SEA_CAP - section_hp[i], 0.0)
	return t


# ---- breaches -----------------------------------------------------------------------------------------------

## Tears a hole of `size` (1-3) at `pos` (ship space) in `section`. A hole right next to an open one grows it.
## Returns the breach index.
func open_breach(section: int, pos: Vector3, size: int, leak: float) -> int:
	section = clampi(section, 0, section_count - 1)
	size = clampi(size, 1, 3)
	for b in breaches.size():
		var br: Dictionary = breaches[b]
		if br["state"] != "patched" and int(br["section"]) == section and (br["pos"] as Vector3).distance_to(pos) < BREACH_MERGE_M:
			var old_leak: float = _breach_flow(br)
			br["size"] = mini(int(br["size"]) + size, 3)
			br["leak"] = maxf(float(br["leak"]), leak) + leak * 0.5
			br["state"] = "open"
			br["work"] = 0.0
			leak_rate[section] = maxf(leak_rate[section] - old_leak + _breach_flow(br), 0.0)
			breach_opened.emit(b)
			return b
	breaches.append({"section": section, "pos": pos, "size": size, "leak": leak, "state": "open", "work": 0.0})
	leak_rate[section] += leak
	breach_opened.emit(breaches.size() - 1)
	return breaches.size() - 1


## Water still coming in through one breach, by the state of its repair.
func _breach_flow(br: Dictionary) -> float:
	return float(br["leak"]) * float(BREACH_LEAK_SHARE[br["state"]])


## Moves a breach to "open", "stuffed", "fothered" or "patched" and adjusts its section's leak to match.
func set_breach_state(index: int, state: String) -> void:
	var br: Dictionary = breaches[index]
	var s: int = int(br["section"])
	var before: float = _breach_flow(br)
	br["state"] = state
	br["work"] = 0.0
	leak_rate[s] = maxf(leak_rate[s] - before + _breach_flow(br), 0.0)
	breach_changed.emit(index)


## Index of the breach letting in the most water, or -1 when every hole is patched.
func worst_breach() -> int:
	var worst: int = -1
	for b in breaches.size():
		if breaches[b]["state"] == "patched":
			continue
		if worst == -1 or _breach_flow(breaches[b]) > _breach_flow(breaches[worst]):
			worst = b
	return worst


func open_breach_count() -> int:
	var n: int = 0
	for br in breaches:
		if br["state"] != "patched":
			n += 1
	return n


func leak_total() -> float:
	var t: float = 0.0
	for l in leak_rate:
		t += l
	return t


## A shipyard repair: every section, hole, mast, sail and the rudder as new, and the bilges dry.
func reset_all() -> void:
	for i in section_count:
		section_hp[i] = section_max
		water_t[i] = 0.0
		leak_rate[i] = 0.0
		fire_level[i] = 0
	for m in mast_hp.size():
		mast_hp[m] = mast_max
		sail_hp[m] = sail_max
		mast_down[m] = false
	rudder_hp = stats.rudder_hp
	breaches.clear()
	breach_changed.emit(-1)


## The state of the damage worth keeping in a save (JSON safe). Section HP goes through ship_hull instead.
func to_save() -> Dictionary:
	var holes: Array = []
	for br in breaches:
		var p: Vector3 = br["pos"]
		holes.append({"section": br["section"], "pos": [p.x, p.y, p.z], "size": br["size"], "leak": br["leak"], "state": br["state"]})
	var water: Array = []
	for w in water_t:
		water.append(w)
	var masts: Array = []
	for d in mast_down:
		masts.append(d)
	var sails: Array = []
	for i in sail_hp.size():
		sails.append(sail_hp[i] / maxf(sail_max, 0.001))
	return {"breaches": holes, "water": water, "masts_down": masts, "sails": sails}


func load_save(d: Dictionary) -> void:
	breaches.clear()
	for i in section_count:
		leak_rate[i] = 0.0
	for h: Dictionary in d.get("breaches", []):
		var p: Array = h["pos"]
		var br: Dictionary = {"section": clampi(int(h["section"]), 0, section_count - 1), "pos": Vector3(float(p[0]), float(p[1]), float(p[2])),
			"size": int(h["size"]), "leak": float(h["leak"]), "state": str(h["state"]), "work": 0.0}
		breaches.append(br)
		leak_rate[int(br["section"])] += _breach_flow(br)
	var water: Array = d.get("water", [])
	for i in mini(water.size(), section_count):
		water_t[i] = float(water[i])
	var masts: Array = d.get("masts_down", [])
	for i in mini(masts.size(), mast_down.size()):
		mast_down[i] = bool(masts[i])
		if mast_down[i]:
			mast_hp[i] = 0.0
	var sails: Array = d.get("sails", [])
	for i in mini(sails.size(), sail_hp.size()):
		sail_hp[i] = sail_max * clampf(float(sails[i]), 0.0, 1.0)
	breach_changed.emit(-1)


func _spread_fire() -> void:
	var rain_factor: float = 0.5 if rain else 1.0
	var snapshot: PackedInt32Array = fire_level.duplicate()
	for i in section_count:
		if snapshot[i] == 0:
			continue
		if snapshot[i] < 3 and rng.randf() < 0.5:
			fire_level[i] = snapshot[i] + 1
		for n in neighbours(i):
			if fire_level[n] == 0 and rng.randf() < 0.2 * snapshot[i] * rain_factor:
				ignite(n)


func _reduce_one_fire() -> void:
	var worst: int = -1
	for i in section_count:
		if fire_level[i] > 0 and (worst == -1 or fire_level[i] > fire_level[worst]):
			worst = i
	if worst >= 0:
		fire_level[worst] -= 1


func fires_burning() -> int:
	var n: int = 0
	for f in fire_level:
		if f > 0:
			n += 1
	return n
