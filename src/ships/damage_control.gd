class_name DamageControl
extends RefCounted
## Damage control for the player's ship: the repair hands split between the pumps, patching holes, fighting
## fire, jury-rigging fallen masts and mending the hull, using the ship's timber, canvas and tools. Carpenters
## do the skilled work (patching, rigging, hull) faster. On "auto" the bosun sends hands where it is worst;
## otherwise the player's weights decide, and a job with nothing to do hands its men to the others.

const JOBS: Array[String] = ["pump", "patch", "fire", "rig", "hull"]
const MAX_WEIGHT: int = 5
## Hand-seconds to plank a hole of size 1-3, and the timber it takes.
const PATCH_WORK: Array[float] = [0.0, 60.0, 140.0, 280.0]
const PATCH_TIMBER: Array[float] = [0.0, 1.0, 2.0, 4.0]
const FOTHER_WORK_SHARE: float = 0.35  ## drawing a sail under the hull over the hole: quick, one bolt of canvas
const STUFF_WORK_SHARE: float = 0.6  ## no timber, no canvas: hammocks and oakum rammed into the hole
const TOOLS_SPEED: float = 1.5  ## a carpenter's chest of tools on board
const TOOLS_WEAR_PER_PATCH: float = 0.25
const RIG_WORK: float = 240.0  ## hand-seconds to step a jury mast from a spare spar
const RIG_TIMBER: float = 3.0
const RIG_CANVAS: float = 2.0
const JURY_SHARE: float = 0.5  ## a jury mast carries half the sail
const SAIL_WORK_PER_CANVAS: float = 40.0
const SAIL_PER_CANVAS: float = 0.25  ## one bolt mends a quarter of one mast's sails
const HULL_HP_PER_HAND_S: float = 0.125  ## half an HP a second for every four hands, as the older rule
const PUMP_T_PER_HAND_S: float = DamageModel.BAIL_T_PER_S_PER_4_CREW / 4.0
const FIRE_PER_HAND_S: float = 1.0 / 18.0
const RUDDER_SEA_CAP: float = 0.6
const CARPENTER_FIRST: float = 2.0
const CARPENTER_EXTRA: float = 0.25
const CARPENTER_MAX: float = 3.0

signal event(kind: String, info: Dictionary)

var damage: DamageModel
var auto: bool = true
var weights: Dictionary = {"pump": 2, "patch": 3, "fire": 3, "rig": 1, "hull": 1}
## The state's supplies dictionary, shared and spent directly. Null means unlimited (AI ships, tests).
var supplies = null
var carpenters: int = 0
## Hands on each job after the last tick, for the HUD.
var hands_on: Dictionary = {}
var _rig_work: float = 0.0
var _sail_work: float = 0.0
var _timber_warned: bool = false


func _init(model: DamageModel) -> void:
	damage = model
	model.control = self
	for j in JOBS:
		hands_on[j] = 0.0


## Work speed for skilled jobs from the carpenters aboard: x2 with one, +0.25 for each more, at most x3.
func skill_mult() -> float:
	if carpenters <= 0:
		return 1.0
	return minf(CARPENTER_FIRST + CARPENTER_EXTRA * float(carpenters - 1), CARPENTER_MAX)


func tools_mult() -> float:
	return TOOLS_SPEED if have("tools") >= 1.0 else 1.0


func have(id: String) -> float:
	if supplies == null:
		return 999.0
	return float(supplies.get(id, 0.0))


func _spend(id: String, units: float) -> void:
	if supplies != null:
		supplies[id] = maxf(float(supplies.get(id, 0.0)) - units, 0.0)


## String key naming a hull section: bow, stern, port, starboard, or fore/mid/aft on the bigger ships.
static func section_key(model: DamageModel, i: int) -> String:
	if model.section_count == 4:
		return "dmg.sec." + ["bow", "port", "starboard", "stern"][clampi(i, 0, 3)]
	if i <= 0:
		return "dmg.sec.bow"
	if i >= model.section_count - 1:
		return "dmg.sec.stern"
	var band: String = ["fore", "mid", "aft"][clampi((i - 1) / 2, 0, 2)]
	return "dmg.sec.%s_%s" % [band, "starboard" if (i - 1) % 2 == 1 else "port"]


func set_weight(job: String, w: int) -> void:
	weights[job] = clampi(w, 0, MAX_WEIGHT)
	auto = false


## Is there anything for this job to do (and the stores to do it)?
func has_work(job: String) -> bool:
	match job:
		"pump":
			return damage.water_total() > 0.01
		"patch":
			return _patch_target()[0] >= 0
		"fire":
			return damage.fires_burning() > 0
		"rig":
			return _rig_target() >= 0 or _sail_target() >= 0
		"hull":
			return have("timber") > 0.0 and (damage.hull_repairable() > 0.5 or damage.rudder_fraction() < RUDDER_SEA_CAP)
	return false


## Weights the bosun would pick: fire first, then the holes, the pumps by how deep the water is, then the rest.
func auto_weights() -> Dictionary:
	var w: Dictionary = {}
	var flood: float = damage.flood_fraction()
	w["fire"] = 5 if damage.fires_burning() > 0 else 0
	w["patch"] = (5 if flood > 0.3 else 4) if has_work("patch") else 0
	w["pump"] = clampi(1 + int(flood * 8.0), 1, 5) if has_work("pump") else 0
	w["rig"] = 1 if has_work("rig") else 0
	w["hull"] = 1 if has_work("hull") else 0
	return w


## Splits `hands` over the jobs that have work, by weight. Idle jobs give their share to the others.
func split(hands: float) -> Dictionary:
	var w: Dictionary = auto_weights() if auto else weights
	var out: Dictionary = {}
	var total: float = 0.0
	for j in JOBS:
		out[j] = 0.0
		if int(w.get(j, 0)) > 0 and has_work(j):
			total += float(w[j])
	if total <= 0.0:
		return out
	for j in JOBS:
		if int(w.get(j, 0)) > 0 and has_work(j):
			out[j] = hands * float(w[j]) / total
	return out


## One step of damage control with `hands` repair crew. Returns the events it raised (also emitted).
func tick(dt: float, hands: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if damage.sunk:
		return events
	hands_on = split(hands)
	var skill: float = skill_mult() * tools_mult()
	if hands_on["pump"] > 0.0:
		damage.bail(hands_on["pump"] * PUMP_T_PER_HAND_S * dt)
	if hands_on["fire"] > 0.0:
		damage.fight_fire(hands_on["fire"] * FIRE_PER_HAND_S * dt)
	if hands_on["patch"] > 0.0:
		_work_patch(hands_on["patch"] * skill * dt, events)
	if hands_on["rig"] > 0.0:
		_work_rig(hands_on["rig"] * skill * dt, events)
	if hands_on["hull"] > 0.0:
		_work_hull(hands_on["hull"] * skill * dt)
	if not _timber_warned and have("timber") < 1.0 and damage.open_breach_count() > 0:
		_timber_warned = true
		events.append({"kind": "no_timber"})
	elif have("timber") >= 1.0:
		_timber_warned = false
	for e in events:
		event.emit(e["kind"], e)
	return events


## The breach to work on next and how: [index, method]. Planks if there is timber, else canvas, else oakum;
## a hole already fothered or stuffed only gets worked again if a better fix is now possible.
func _patch_target() -> Array:
	var best: int = -1
	var best_method: String = ""
	var best_flow: float = -1.0
	for b in damage.breaches.size():
		var br: Dictionary = damage.breaches[b]
		var method: String = _method_for(br)
		if method == "":
			continue
		var flow: float = float(br["leak"]) * float(DamageModel.BREACH_LEAK_SHARE[br["state"]])
		if flow > best_flow:
			best = b
			best_method = method
			best_flow = flow
	return [best, best_method]


func _method_for(br: Dictionary) -> String:
	var state: String = br["state"]
	if state == "patched":
		return ""
	if have("timber") >= PATCH_TIMBER[int(br["size"])]:
		return "patched"
	if state == "open" or state == "stuffed":
		if have("canvas") >= 1.0:
			return "fothered"
	if state == "open":
		return "stuffed"
	return ""


func patch_work(size: int, method: String) -> float:
	var w: float = PATCH_WORK[clampi(size, 1, 3)]
	match method:
		"fothered":
			return w * FOTHER_WORK_SHARE
		"stuffed":
			return w * STUFF_WORK_SHARE
	return w


func _work_patch(work: float, events: Array[Dictionary]) -> void:
	while work > 0.0:
		var t: Array = _patch_target()
		var b: int = t[0]
		if b < 0:
			return
		var method: String = t[1]
		var br: Dictionary = damage.breaches[b]
		var need: float = patch_work(int(br["size"]), method)
		var done: float = float(br.get("work", 0.0)) + work
		if done < need:
			br["work"] = done
			return
		work = done - need
		match method:
			"patched":
				_spend("timber", PATCH_TIMBER[int(br["size"])])
				if have("tools") >= 1.0:
					_spend("tools", TOOLS_WEAR_PER_PATCH)
			"fothered":
				_spend("canvas", 1.0)
		damage.set_breach_state(b, method)
		events.append({"kind": method, "breach": b, "section": int(br["section"]), "size": int(br["size"])})


func _rig_target() -> int:
	if have("timber") < RIG_TIMBER or have("canvas") < RIG_CANVAS:
		return -1
	for m in damage.mast_down.size():
		if damage.mast_down[m]:
			return m
	return -1


func _sail_target() -> int:
	if have("canvas") < 1.0:
		return -1
	var worst: int = -1
	for m in damage.sail_hp.size():
		if damage.mast_down[m]:
			continue
		var cap: float = damage.sail_max * (JURY_SHARE if damage.mast_hp[m] < damage.mast_max else 1.0)
		if damage.sail_hp[m] < cap * 0.95 and (worst == -1 or damage.sail_hp[m] < damage.sail_hp[worst]):
			worst = m
	return worst


func _work_rig(work: float, events: Array[Dictionary]) -> void:
	var m: int = _rig_target()
	if m >= 0:
		_rig_work += work
		if _rig_work >= RIG_WORK:
			_rig_work = 0.0
			_spend("timber", RIG_TIMBER)
			_spend("canvas", RIG_CANVAS)
			damage.mast_down[m] = false
			damage.mast_hp[m] = damage.mast_max * JURY_SHARE
			damage.sail_hp[m] = damage.sail_max * JURY_SHARE
			events.append({"kind": "jury_mast", "mast": m})
		return
	var s: int = _sail_target()
	if s < 0:
		return
	_sail_work += work
	if _sail_work >= SAIL_WORK_PER_CANVAS:
		_sail_work = 0.0
		_spend("canvas", 1.0)
		var cap: float = damage.sail_max * (JURY_SHARE if damage.mast_hp[s] < damage.mast_max else 1.0)
		damage.sail_hp[s] = minf(damage.sail_hp[s] + damage.sail_max * SAIL_PER_CANVAS, cap)
		events.append({"kind": "sail", "mast": s})


func _work_hull(work: float) -> void:
	var hp: float = work * HULL_HP_PER_HAND_S
	var timber_hp: float = have("timber") * CrewLife.REPAIR_HP_PER_TIMBER
	hp = minf(hp, timber_hp)
	if hp <= 0.0:
		return
	var used: float = 0.0
	if damage.rudder_fraction() < RUDDER_SEA_CAP:
		var cap: float = damage.stats.rudder_hp * RUDDER_SEA_CAP
		var r: float = minf(hp, cap - damage.rudder_hp)
		damage.rudder_hp += r
		used += r
	else:
		used += damage.repair_hull(hp)
	_spend("timber", used / CrewLife.REPAIR_HP_PER_TIMBER)


## Progress 0..1 on the job the HUD shows a bar for: the hole being worked, or the jury mast.
func patch_progress() -> float:
	var t: Array = _patch_target()
	if int(t[0]) < 0:
		return 0.0
	var br: Dictionary = damage.breaches[int(t[0])]
	return clampf(float(br.get("work", 0.0)) / patch_work(int(br["size"]), t[1]), 0.0, 1.0)


func rig_progress() -> float:
	return clampf(_rig_work / RIG_WORK, 0.0, 1.0)
