class_name Digging
extends RefCounted
## The digging mini-game: five swings, then the hole gives up what it holds.

var swings: int = 0
var power: float = 0.0
var empties: int = 0  ## holes without the chest so far at a tour spot, for the pity rule
var tour_spot: bool = false
var rng: RandomNumberGenerator


func _init(rng_in: RandomNumberGenerator, on_tour_spot: bool = false) -> void:
	rng = rng_in
	tour_spot = on_tour_spot


## One swing; accuracy 0..1 adds to the depth. Returns the result once the fifth swing lands, otherwise "".
func swing(accuracy: float) -> String:
	if swings >= TourData.DIG_SWINGS:
		return ""
	swings += 1
	power += clampf(accuracy, 0.0, 1.0)
	if swings < TourData.DIG_SWINGS:
		return ""
	return result()


func result() -> String:
	var r: float = rng.randf()
	var acc: float = 0.0
	var pick: String = "nothing"
	for k: String in TourData.DIG_TABLE.keys():
		acc += float(TourData.DIG_TABLE[k])
		if r <= acc:
			pick = k
			break
	if tour_spot:
		if pick != "chest" and empties >= TourData.DIG_PITY_EMPTY:
			pick = "chest"
		if pick != "chest":
			empties += 1
	return pick


func reset() -> void:
	swings = 0
	power = 0.0
