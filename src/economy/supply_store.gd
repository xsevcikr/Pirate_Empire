class_name SupplyStore
extends RefCounted
## The chandler's shop in a city: tops the hold up with food, water and rum for a voyage of a chosen length in one go,
## as far as gold and room in the hold allow. Prices are the port's supply prices.

const RESTOCK_DAYS: Array[int] = [7, 14, 30]
const VOYAGE: Array[String] = ["food", "water", "rum"]


## Units of each of food, water and rum needed so each lasts `days`.
static func shortfall(state: Dictionary, days: float) -> Dictionary:
	var out: Dictionary = {}
	for id in VOYAGE:
		var per_day: float = {"food": CrewLife.food_per_day(state), "water": CrewLife.water_per_day(state), "rum": CrewLife.rum_per_day(state)}[id]
		out[id] = maxi(ceili(per_day * days - float(state["supplies"].get(id, 0.0))), 0)
	return out


## Gold the shortfall would cost at today's prices.
static func restock_cost(state: Dictionary, market: Market, days: float) -> int:
	var need: Dictionary = shortfall(state, days)
	var cost: float = 0.0
	for id: String in need:
		cost += PortService.supply_price(state, market, id) * int(need[id])
	return ceili(cost)


## Buys towards `days` of food, water and rum, a unit at a time in turn so a thin purse spreads over all three.
## Returns the units bought of each.
static func restock(state: Dictionary, market: Market, days: float) -> Dictionary:
	var need: Dictionary = shortfall(state, days)
	var got: Dictionary = {"food": 0, "water": 0, "rum": 0}
	var progress: bool = true
	while progress:
		progress = false
		for id in VOYAGE:
			if int(got[id]) < int(need[id]) and PortService.buy_supply(state, market, id, 1):
				got[id] = int(got[id]) + 1
				progress = true
	return got
