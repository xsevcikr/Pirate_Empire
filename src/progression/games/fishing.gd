class_name Fishing
extends RefCounted
## Fishing from the ship at any stop: cast, wait for a bite, then reel against the line's tension. Reel too hard and
## the line snaps; relax too long and the fish gets away.

enum Phase { WAITING, BITE, REELING, CAUGHT, LOST }

var rng: RandomNumberGenerator
var phase: Phase = Phase.WAITING
var wait_left: float = 0.0
var tension: float = 0.0
var distance: float = 1.0
var fish: String = ""
var _slack_s: float = 0.0


func _init(r: RandomNumberGenerator) -> void:
	rng = r
	wait_left = rng.randf_range(float(GameData.FISHING["bite_min_s"]), float(GameData.FISHING["bite_max_s"]))


static func pick_fish(rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for id: String in GameData.FISHING["fish"]:
		total += float(GameData.FISHING["fish"][id]["weight"])
	var roll: float = rng.randf() * total
	for id: String in GameData.FISHING["fish"]:
		roll -= float(GameData.FISHING["fish"][id]["weight"])
		if roll <= 0.0:
			return id
	return "sardine"


func step(dt: float, reeling: bool) -> void:
	var f: Dictionary = GameData.FISHING
	match phase:
		Phase.WAITING:
			wait_left -= dt
			if wait_left <= 0.0:
				fish = pick_fish(rng)
				phase = Phase.BITE
				distance = float(f["distance_start"])
				tension = float(f["relax_tension"])
		Phase.BITE:
			phase = Phase.REELING
		Phase.REELING:
			var pull: float = float(f["fish"][fish]["pull"]) * float(f["fish_pull"])
			var wiggle: float = (rng.randf() - 0.5) * 0.3 * dt * 10.0
			if reeling:
				tension += (float(f["reel_tension"]) + pull * 0.5 + wiggle) * dt
				distance -= float(f["reel_speed"]) * dt
				_slack_s = 0.0
			else:
				tension -= float(f["relax_tension"]) * dt
				distance += pull * 0.08 * dt
				_slack_s += dt
			tension = maxf(tension, 0.0)
			if tension >= float(f["tension_break"]) or distance >= 1.6 or _slack_s > 4.0:
				phase = Phase.LOST
			elif distance <= 0.0:
				phase = Phase.CAUGHT


func value() -> int:
	return int(GameData.FISHING["fish"][fish]["value"]) if phase == Phase.CAUGHT else 0


## Food (in days of rations) a catch is worth if eaten instead of sold.
func food_days() -> float:
	return float(GameData.FISHING["food_days_per_fish"]) if phase == Phase.CAUGHT else 0.0


func bottle() -> bool:
	return phase == Phase.CAUGHT and rng.randf() < float(GameData.FISHING["bottle_chance"])
