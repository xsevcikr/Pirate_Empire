class_name Grapple
extends RefCounted
## Grappling lines between two ships: three lines lock them together, enemy crew can cut lines.

const LINES_NEEDED: int = 3
const LINE_HP: float = 150.0
const CUT_TIME_S: float = 3.0
const THROW_TIME_S: float = 1.5
const PULL_TIME_S: float = 4.0
const CLOSE_RANGE_M: float = 35.0
const MAX_REL_SPEED_KN: float = 6.0
const LOCK_GAP_M: float = 6.0
const ARC_DEG: float = 60.0

var lines: Array[float] = []
var hold_s: float = 0.0
var pull_s: float = 0.0


## True when the target is close, slow relative to us, and inside the side arc (angle off the beam).
static func can_grapple(range_m: float, rel_speed_kn: float, angle_off_beam_deg: float) -> bool:
	return range_m <= CLOSE_RANGE_M and rel_speed_kn < MAX_REL_SPEED_KN and absf(angle_off_beam_deg) <= ARC_DEG * 0.5


## Feed the grapple button. Returns true the moment hooks are thrown.
func hold(delta: float) -> bool:
	if not lines.is_empty():
		return false
	hold_s += delta
	if hold_s >= THROW_TIME_S:
		for i in LINES_NEEDED:
			lines.append(LINE_HP)
		return true
	return false


func release() -> void:
	if lines.size() < LINES_NEEDED:
		hold_s = 0.0


func damage_line(index: int, amount: float) -> void:
	if index < 0 or index >= lines.size():
		return
	lines[index] -= amount
	if lines[index] <= 0.0:
		lines.remove_at(index)
		pull_s = maxf(pull_s - PULL_TIME_S / LINES_NEEDED, 0.0)


func is_locked() -> bool:
	return lines.size() >= LINES_NEEDED and pull_s >= PULL_TIME_S


## Advance the pull; ships close to LOCK_GAP_M over PULL_TIME_S while all lines hold.
func tick(delta: float) -> void:
	if lines.size() >= LINES_NEEDED:
		pull_s = minf(pull_s + delta, PULL_TIME_S)


## Gap between hulls while being pulled in from `start_gap`.
func gap(start_gap: float) -> float:
	return lerpf(start_gap, LOCK_GAP_M, clampf(pull_s / PULL_TIME_S, 0.0, 1.0))
