class_name FleetOrders
extends RefCounted
## Orders for non-flagship ships and their simulated outcomes.

enum Order { TRADE_ROUTE, PATROL, RAID, ESCORT, STATION }

const PIRACY_RISK_PER_TRIP: float = 0.10
const SKIM_FRACTION: float = 0.10
const HONESTY_SKIM_BELOW: int = 4
const PATROL_SPAWN_REDUCTION: float = 0.60


## Predicted gold for a round trip: cargo units x price spread, minus expected piracy loss and skimming.
static func predicted_trip(cargo_units: float, spread_per_unit: float, honesty: int) -> float:
	var gross: float = cargo_units * spread_per_unit
	var skim: float = SKIM_FRACTION if honesty < HONESTY_SKIM_BELOW else 0.0
	return gross * (1.0 - PIRACY_RISK_PER_TRIP) * (1.0 - skim)


## One simulated trip: with PIRACY_RISK the cargo is lost; market noise of +-10% on the spread.
static func simulate_trip(cargo_units: float, spread_per_unit: float, honesty: int, rng: RandomNumberGenerator) -> float:
	if rng.randf() < PIRACY_RISK_PER_TRIP:
		return 0.0
	var gross: float = cargo_units * spread_per_unit * rng.randf_range(0.9, 1.1)
	return gross * (1.0 - (SKIM_FRACTION if honesty < HONESTY_SKIM_BELOW else 0.0))
