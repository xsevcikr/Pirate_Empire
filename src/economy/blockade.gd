class_name Blockade
extends RefCounted
## Armed ships parked near a port. Hold 24 game hours inside 1.5 km and the port's goods cost 50% more
## (the existing blockade event) and its faction thinks less of you.


## Call every game hour with the number of armed hostile ships within BLOCKADE_RADIUS_M of the port.
## Returns true on the hour the blockade is declared.
static func tick(state: Dictionary, port_id: String, armed_ships: int, hours: float = 1.0) -> bool:
	var held: Dictionary = state["blockade"]
	if armed_ships <= 0:
		held[port_id] = 0.0
		return false
	held[port_id] = float(held.get(port_id, 0.0)) + hours
	if float(held[port_id]) < TradeData.BLOCKADE_HOURS:
		return false
	held[port_id] = 0.0
	var m: Market = PortService.market_of(state, port_id)
	m.events["blockade"] = TradeData.BLOCKADE_EVENT_H
	PortService.store_market(state, port_id, m)
	var f: String = PortData.PORTS[port_id]["faction"]
	state["rep"][f] = clampf(float(state["rep"][f]) + TradeData.BLOCKADE_REP, -100.0, 100.0)
	return true


static func armed_near(port_id: String, ship_positions: Array[Vector2]) -> int:
	var dock: Vector2 = PortData.PORTS[port_id]["dock"]
	var n: int = 0
	for p in ship_positions:
		if p.distance_to(dock) <= TradeData.BLOCKADE_RADIUS_M:
			n += 1
	return n


## A harbour building was destroyed: the port holds 20% less stock for three days.
static func building_destroyed(state: Dictionary, port_id: String) -> void:
	var cut: Dictionary = state["port_damage"]
	var entry: Dictionary = cut.get(port_id, {"cut": 0.0, "days": 0.0})
	entry["cut"] = minf(float(entry["cut"]) + TradeData.BUILDING_STOCK_CUT, 0.8)
	entry["days"] = TradeData.BUILDING_STOCK_DAYS
	cut[port_id] = entry
	var m: Market = PortService.market_of(state, port_id)
	for g in Goods.ids():
		m.target[g] = PortData.PORTS[port_id]["target_units"] * (1.0 - float(entry["cut"]))
	PortService.store_market(state, port_id, m)


## Daily: damaged ports heal. Returns nothing; targets come back through PortData.build_market once the cut ends.
static func heal_days(state: Dictionary, days: float) -> void:
	for id in state["port_damage"].keys():
		state["port_damage"][id]["days"] = float(state["port_damage"][id]["days"]) - days
		if float(state["port_damage"][id]["days"]) <= 0.0:
			state["port_damage"].erase(id)
