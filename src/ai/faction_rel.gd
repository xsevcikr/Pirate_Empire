class_name FactionRel
extends RefCounted
## Who shoots at whom. Merchants never attack; everyone else attacks the player and rival flags.

const HOSTILE_PAIRS: Array = [
	["navy", "player"], ["navy", "pirate"], ["pirate", "player"], ["pirate", "merchant"], ["player", "iron"], ["navy", "iron"],
	["iron", "merchant"], ["iron", "pirate"],
]


static func hostile(a: String, b: String) -> bool:
	if a == b:
		return false
	for pair: Array in HOSTILE_PAIRS:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


## Whether `a` will actively start a fight with `b` (merchants only flee).
static func aggressive_toward(a: String, b: String) -> bool:
	return a != "merchant" and hostile(a, b)
