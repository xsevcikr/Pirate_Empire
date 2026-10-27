class_name Loot
extends RefCounted
## Loot rolled from a boarded or sunk ship.

const SINK_CARGO_FRACTION: float = 0.25
const GREEDY_HIDDEN_FRACTION: float = 0.5


## Cargo value recovered from a sunk ship's barrels.
static func sinking_barrels(cargo_value: float) -> float:
	return cargo_value * SINK_CARGO_FRACTION


## Loot available when boarding. Greedy merchant captains hide half of it unless they were beaten in a duel.
static func boarding_loot(cargo_value: float, gold: float, personality: String, captain_beaten: bool) -> float:
	var total: float = cargo_value + gold
	if personality == "greedy" and not captain_beaten:
		total *= 1.0 - GREEDY_HIDDEN_FRACTION
	return total


## Player's share after the crew takes theirs (quartermaster officer lowers the crew cut).
static func captain_share(total: float, quartermaster_level: int = 0) -> float:
	return total * clampf(0.5 + 0.02 * quartermaster_level, 0.0, 0.8)
