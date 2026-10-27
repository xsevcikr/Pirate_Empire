class_name ArmWrestle
extends RefCounted
## Arm wrestling: first a timing bar (how close to the sweet spot you stopped it, 0 to 1), then button mashing.


## Your strength from timing accuracy (0..1) and the number of mashes in the time allowed.
static func power(accuracy: float, mashes: int) -> float:
	var w: Dictionary = GameData.ARM_WRESTLE
	return float(w["timing_weight"]) * clampf(accuracy, 0.0, 1.0) + float(w["mash_weight"]) * clampf(float(mashes) / float(w["mash_cap"]), 0.0, 1.0)


## Win chance of a given power against an opponent kind ("dockhand", "sailor" or "brute").
static func win_chance(p: float, opponent: String) -> float:
	var opp: float = float(GameData.ARM_WRESTLE["opponents"][opponent])
	return clampf(0.5 + (p - opp) * 1.2, 0.05, 0.95)


static func resolve(accuracy: float, mashes: int, opponent: String, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < win_chance(power(accuracy, mashes), opponent)
