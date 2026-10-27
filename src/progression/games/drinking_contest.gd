class_name DrinkingContest
extends RefCounted
## Drinking contest: each drink the screen sways more and you must hold the balance steady. `steadiness` is how well
## the player kept the balance that round (0..1); the contest ends when sway outgrows it.

var drinks: int = 0
var fell: bool = false
var rng: RandomNumberGenerator


func _init(r: RandomNumberGenerator) -> void:
	rng = r


func sway() -> float:
	return float(GameData.DRINKING["sway_base"]) + float(GameData.DRINKING["sway_per_drink"]) * float(drinks)


## One more drink. Returns true while still standing. The sway beats you when it is more than your steadiness
## allows; a little luck either way.
func drink(steadiness: float) -> bool:
	if fell:
		return false
	drinks += 1
	var wobble: float = sway() * (0.85 + 0.3 * rng.randf())
	if wobble > float(GameData.DRINKING["fall_at"]) * (0.4 + 0.6 * clampf(steadiness, 0.0, 1.0)) + 0.25:
		fell = true
		return false
	return drinks < int(GameData.DRINKING["rounds_max"])


func rounds_won() -> int:
	return drinks - (1 if fell else 0)


func gold() -> int:
	return rounds_won() * int(GameData.DRINKING["gold_per_round"])


func rival_rumour() -> bool:
	return rounds_won() >= int(GameData.DRINKING["rival_rumour_rounds"])
