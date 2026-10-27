class_name GunneryRange
extends RefCounted
## Gunnery range at a fort town: floating targets drift past at a range; fire at a (bearing 0..1, range in metres)
## aim point before they leave. Sixty seconds on the clock.

var rng: RandomNumberGenerator
var time_left: float = float(GameData.RANGE["duration_s"])
var targets: Array[Dictionary] = []  ## {"x": 0..1 across, "range": m, "dir": +-1}
var hits: int = 0
var shots: int = 0
var _spawn_in: float = 0.0


func _init(r: RandomNumberGenerator) -> void:
	rng = r
	_spawn()


func _spawn() -> void:
	targets.append({
		"x": 0.0 if rng.randf() < 0.5 else 1.0, "range": rng.randf_range(float(GameData.RANGE["range_min_m"]), float(GameData.RANGE["range_max_m"])),
	})
	targets.back()["dir"] = 1.0 if targets.back()["x"] == 0.0 else -1.0


func over() -> bool:
	return time_left <= 0.0


func step(dt: float) -> void:
	if over():
		return
	time_left = maxf(time_left - dt, 0.0)
	_spawn_in -= dt
	if _spawn_in <= 0.0:
		_spawn_in = float(GameData.RANGE["spawn_every_s"])
		_spawn()
	var keep: Array[Dictionary] = []
	for t in targets:
		t["x"] = float(t["x"]) + float(t["dir"]) * dt * 0.12 * float(GameData.RANGE["speed"]) / 3.0
		if float(t["x"]) >= 0.0 and float(t["x"]) <= 1.0:
			keep.append(t)
	targets = keep


## Fire at the aim point; a target is hit when the aim is within its radius (scaled by range). Returns true on a hit.
func fire(aim_x: float, aim_range: float) -> bool:
	if over():
		return false
	shots += 1
	for t in targets:
		var radius: float = float(GameData.RANGE["target_radius"]) / maxf(float(t["range"]) / 100.0, 0.5) * 0.05
		var d: float = Vector2(float(t["x"]) - aim_x, (float(t["range"]) - aim_range) / 400.0).length()
		if d <= radius + 0.03:
			hits += 1
			targets.erase(t)
			return true
	return false


func gunnery_xp() -> int:
	return hits * int(GameData.RANGE["xp_per_hit"])


func crew_xp() -> int:
	return (hits / 5) * int(GameData.RANGE["crew_xp_per_5_hits"])
