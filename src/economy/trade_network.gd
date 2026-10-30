class_name TradeNetwork
extends RefCounted
## Merchant convoys between producer and consumer ports. A convoy carries stock to its destination when it
## arrives; one the player sinks or captures never does, so that port's price stays high. Pure functions on the
## save-state dictionary ("convoys", "convoy_clock_h", "convoy_seq") plus the seeded rng.

enum Status { SAILING, ARRIVED, LOST }


static func dock_of(port_id: String) -> Vector2:
	return PortData.PORTS[port_id]["dock"]


static func travel_hours(from_id: String, to_id: String) -> float:
	var metres: float = dock_of(from_id).distance_to(dock_of(to_id))
	return metres / (TradeData.CONVOY_SPEED_KN * TradeData.M_PER_KN_H)


## The nearest port that consumes `good`, or "" when none does.
static func destination_for(from_id: String, good: String) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: String in PortData.PORTS:
		if id == from_id or not PortData.PORTS[id]["consumer"].has(good):
			continue
		var d: float = dock_of(from_id).distance_to(dock_of(id))
		if d < best_d:
			best_d = d
			best = id
	return best


## Creates the convoys due up to `now_h` (game hours since day 0). Each producer port sends one every 12 h,
## cycling through the goods it makes.
static func spawn_due(state: Dictionary, now_h: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	if float(state["convoy_clock_h"]) <= 0.0:
		state["convoy_clock_h"] = now_h  # first tick: no backlog for the days before the game began
	while float(state["convoy_clock_h"]) + TradeData.CONVOY_INTERVAL_H <= now_h:
		state["convoy_clock_h"] = float(state["convoy_clock_h"]) + TradeData.CONVOY_INTERVAL_H
		var depart: float = state["convoy_clock_h"]
		var round_no: int = int(floor(depart / TradeData.CONVOY_INTERVAL_H))
		for id: String in PortData.PORTS:
			var goods: Array = PortData.PORTS[id]["producer"]
			if goods.is_empty():
				continue
			var good: String = goods[round_no % goods.size()]
			var to: String = destination_for(id, good)
			if to == "":
				continue
			var ships: int = rng.randi_range(TradeData.CONVOY_SHIPS[0], TradeData.CONVOY_SHIPS[1])
			var c: Dictionary = {
				"id": int(state["convoy_seq"]), "good": good, "from": id, "to": to, "ships": ships, "ships_start": ships,
				"escorts": rng.randi_range(TradeData.CONVOY_ESCORTS[0], TradeData.CONVOY_ESCORTS[1]),
				"units": float(ships) * TradeData.UNITS_PER_SHIP, "depart_h": depart, "eta_h": depart + travel_hours(id, to),
				"status": Status.SAILING,
			}
			state["convoy_seq"] = int(state["convoy_seq"]) + 1
			state["convoys"].append(c)
			made.append(c)
	return made


## Where a sailing convoy is at `now_h`, on the straight lane between its ports.
static func position_at(c: Dictionary, now_h: float) -> Vector2:
	var span: float = maxf(float(c["eta_h"]) - float(c["depart_h"]), 0.001)
	var f: float = clampf((now_h - float(c["depart_h"])) / span, 0.0, 1.0)
	return dock_of(c["from"]).lerp(dock_of(c["to"]), f)


## Delivers convoys whose time is up: their cargo joins the destination's stock. Returns the arrivals.
static func advance(state: Dictionary, now_h: float) -> Array[Dictionary]:
	var arrived: Array[Dictionary] = []
	var keep: Array = []
	for c: Dictionary in state["convoys"]:
		if int(c["status"]) == Status.SAILING and float(c["eta_h"]) <= now_h:
			c["status"] = Status.ARRIVED
			deliver(state, c)
			arrived.append(c)
		elif int(c["status"]) == Status.SAILING:
			keep.append(c)
	state["convoys"] = keep
	return arrived


static func deliver(state: Dictionary, c: Dictionary) -> void:
	var m: Market = PortService.market_of(state, c["to"])
	var good: String = c["good"]
	m.stock[good] = minf(m.stock[good] + float(c["units"]), m.target[good] * TradeData.CONVOY_ARRIVAL_STOCK_CAP)
	PortService.store_market(state, c["to"], m)


## The player sank or captured `n` of a convoy's merchant ships. Their cargo is gone with them (a capture hands
## it to the player instead); a convoy with no ships left never arrives. Returns the units that vanished.
static func lose_ships(state: Dictionary, convoy_id: int, n: int = 1) -> float:
	for c: Dictionary in state["convoys"]:
		if int(c["id"]) != convoy_id or int(c["status"]) != Status.SAILING:
			continue
		var take: int = mini(n, int(c["ships"]))
		var per_ship: float = float(c["units"]) / maxf(float(c["ships"]), 1.0)
		c["ships"] = int(c["ships"]) - take
		c["units"] = float(c["units"]) - per_ship * float(take)
		if int(c["ships"]) <= 0:
			c["status"] = Status.LOST
			state["convoys"].erase(c)
			state["convoys_lost"] = int(state.get("convoys_lost", 0)) + 1
		return per_ship * float(take)
	return 0.0


static func find(state: Dictionary, convoy_id: int) -> Dictionary:
	for c: Dictionary in state["convoys"]:
		if int(c["id"]) == convoy_id:
			return c
	return {}


## Sailing convoys within `range_m` of a point, for the world to put real ships on.
static func near(state: Dictionary, now_h: float, pos: Vector2, range_m: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in state["convoys"]:
		if int(c["status"]) == Status.SAILING and position_at(c, now_h).distance_to(pos) <= range_m:
			out.append(c)
	return out
