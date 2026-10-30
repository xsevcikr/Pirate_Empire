class_name Grounding
extends RefCounted
## A ship aground on sand: stuck until kedged free (30 s hold), until the tide has risen, or until cargo is dumped.

const TIDE_FREES_M: float = 0.6
const DUMP_FRACTION: float = 0.5

var stuck: bool = false
var material: String = "sand"
var progress_s: float = 0.0
var tide_when_stuck: float = 0.0
var normal: Vector2 = Vector2.ZERO  ## away from the shore, to push the ship off when freed


## Called on contact. Returns the CollisionModel verdict and records being stuck.
func touch(mat: String, speed_kn: float, tide_m: float, away: Vector2) -> String:
	var verdict: String = CollisionModel.grounding(mat, speed_kn)
	if verdict == "stuck" and not stuck:
		stuck = true
		material = mat
		progress_s = 0.0
		tide_when_stuck = tide_m
		normal = away
	return verdict


## Winch for `dt` seconds. Returns true the moment the ship comes free.
func kedge(dt: float, holding: bool) -> bool:
	if not stuck:
		return false
	if not holding:
		progress_s = maxf(progress_s - dt * 0.5, 0.0)
		return false
	progress_s += dt
	if progress_s >= CollisionModel.KEDGE_HOLD_S:
		release()
		return true
	return false


func tide_check(tide_m: float) -> bool:
	if stuck and tide_m - tide_when_stuck >= TIDE_FREES_M:
		release()
		return true
	return false


## Dump cargo overboard to float free. Returns how many units of each good were thrown over.
func dump_cargo(cargo: Dictionary) -> Dictionary:
	var dumped: Dictionary = {}
	if not stuck:
		return dumped
	for g: String in cargo.keys():
		var n: float = floorf(float(cargo[g]) * DUMP_FRACTION)
		if n > 0.0:
			dumped[g] = n
			cargo[g] = float(cargo[g]) - n
	release()
	return dumped


func release() -> void:
	stuck = false
	progress_s = 0.0
