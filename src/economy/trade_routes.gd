class_name TradeRoutes
extends RefCounted
## Trade routes between cities: buy low, sell high. The captain's price book remembers what every port charged
## when the ship last docked there (state["price_book"]), and the routes ledger ranks the gaps between them. A
## ship of the fleet can be put on a route: it sails it on its own, round trip after round trip, buying at one
## port and selling at the other, so both markets move and the profit (less the odd cargo lost to pirates) is
## paid to the captain. The route is kept on the fleet entry itself (entry["route"]), so a ship that is sold or
## taken back into command simply stops trading.

const MIN_MARGIN: float = 2.0  ## gold a unit; smaller gaps are not worth the voyage
const LOAD_HOURS: float = 24.0  ## waiting for cargo, loading and unloading at both ends of a round trip
const FLEET_SPEED_KN: float = 7.0
const FLEET_HOLD_SHARE: float = 0.8  ## of a fleet ship's hold given to the trade goods (the rest is stores)
const FLEET_MAX_UNITS: float = 40.0  ## so one ship cannot empty a market in a single trip
const LEDGER_MAX_UNITS: float = 100.0  ## the "a hold" profit stops here: buying more runs the price away
const FLEET_HONESTY: int = 7  ## the prize crews the captain trusts; FleetOrders skims below 4
const LOSS_HULL: float = 0.1  ## a cargo lost to pirates also costs hull
const MAX_CATCH_UP: int = 4  ## trips settled at once after a long time away
const TOP: int = 6


static func legal_goods() -> Array[String]:
	var out: Array[String] = []
	for g: String in Goods.ids():
		if bool(Goods.DATA[g]["legal"]):
			out.append(g)
	return out


static func book(state: Dictionary) -> Dictionary:
	if not (state.get("price_book") is Dictionary):
		state["price_book"] = {}
	return state["price_book"]


## Writes down today's prices at `port_id`: what the player pays (buy) and receives (sell) for each legal good.
static func record(state: Dictionary, port_id: String) -> void:
	var m: Market = PortService.market_of(state, port_id)
	var buy: Dictionary = {}
	var sell: Dictionary = {}
	for g in legal_goods():
		buy[g] = snappedf(PortService.good_buy_price(state, m, g), 0.1)
		sell[g] = snappedf(PortService.good_sell_price(m, g), 0.1)
	book(state)[port_id] = {"day": int(state["day"]), "buy": buy, "sell": sell}


static func known(state: Dictionary, port_id: String) -> bool:
	return book(state).has(port_id)


static func known_ports(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in book(state):
		if PortData.PORTS.has(id):
			out.append(id)
	out.sort()
	return out


static func age_days(state: Dictionary, port_id: String) -> int:
	return maxi(int(state["day"]) - int(book(state)[port_id]["day"]), 0)


static func distance_nm(from_id: String, to_id: String) -> float:
	return TradeNetwork.dock_of(from_id).distance_to(TradeNetwork.dock_of(to_id)) / TradeData.M_PER_KN_H


## Hours one way at `speed_kn`, straight from dock to dock.
static func hours(from_id: String, to_id: String, speed_kn: float) -> float:
	return distance_nm(from_id, to_id) / maxf(speed_kn, 0.5)


## Every gap worth sailing between ports in the price book, best first. `from_only` keeps routes that start at
## that port. `hold_t` sizes the "a full hold" profit; `speed_kn` the voyage time. Each route is
## {"good", "from", "to", "buy", "sell", "margin", "units", "profit", "hours", "per_hour", "age"}.
static func best(state: Dictionary, hold_t: float, speed_kn: float, from_only: String = "", limit: int = TOP) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ports: Array[String] = known_ports(state)
	for a in ports:
		if from_only != "" and a != from_only:
			continue
		for b in ports:
			if a == b:
				continue
			var pa: Dictionary = book(state)[a]
			var pb: Dictionary = book(state)[b]
			for g in legal_goods():
				var margin: float = float(pb["sell"].get(g, 0.0)) - float(pa["buy"].get(g, INF))
				if margin < MIN_MARGIN:
					continue
				var units: float = minf(floorf(hold_t / float(Goods.DATA[g]["weight"])), LEDGER_MAX_UNITS)
				var h: float = hours(a, b, speed_kn)
				out.append({"good": g, "from": a, "to": b, "buy": float(pa["buy"][g]), "sell": float(pb["sell"][g]), "margin": margin,
					"units": units, "profit": margin * units, "hours": h, "per_hour": margin * units / maxf(h, 1.0),
					"age": maxi(age_days(state, a), age_days(state, b))})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["profit"]) > float(y["profit"]))
	if out.size() > limit:
		out.resize(limit)
	return out


# ---- fleet ships on a route ---------------------------------------------------------------------------------

static func fleet(state: Dictionary) -> Array:
	return state.get("fleet", [])


static func on_route(entry: Dictionary) -> bool:
	return entry.get("route") is Dictionary and not (entry["route"] as Dictionary).is_empty()


static func idle_ship(state: Dictionary) -> int:
	var f: Array = fleet(state)
	for i in f.size():
		if not on_route(f[i]):
			return i
	return -1


static func round_trip_hours(from_id: String, to_id: String) -> float:
	return hours(from_id, to_id, FLEET_SPEED_KN) * 2.0 + LOAD_HOURS


static func units_for(entry: Dictionary, good: String) -> float:
	var stats: ShipStats = PortService.ship_stats(Lagoon.class_of(entry)) if ResourceLoader.exists("res://data/ships/%s.tres" % Lagoon.class_of(entry)) else PortService.ship_stats("sloop")
	return minf(floorf(stats.cargo_t * FLEET_HOLD_SHARE / float(Goods.DATA[good]["weight"])), FLEET_MAX_UNITS)


## Puts fleet ship `index` on the route. Both ports must be in the price book and the good legal.
static func assign(state: Dictionary, index: int, from_id: String, to_id: String, good: String, now_h: float) -> bool:
	var f: Array = fleet(state)
	if index < 0 or index >= f.size() or from_id == to_id or not legal_goods().has(good):
		return false
	if not (known(state, from_id) and known(state, to_id)):
		return false
	f[index]["route"] = {"from": from_id, "to": to_id, "good": good, "next_h": now_h + round_trip_hours(from_id, to_id),
		"trips": 0, "earned": 0, "lost": 0, "last": 0}
	return true


static func recall(state: Dictionary, index: int) -> bool:
	var f: Array = fleet(state)
	if index < 0 or index >= f.size() or not on_route(f[index]):
		return false
	(f[index] as Dictionary).erase("route")
	return true


## The gold a round trip should bring at today's markets, after the expected losses.
static func predicted(state: Dictionary, entry: Dictionary) -> float:
	var r: Dictionary = entry["route"]
	var spread: float = live_spread(state, r["from"], r["to"], r["good"])
	return FleetOrders.predicted_trip(units_for(entry, r["good"]), maxf(spread, 0.0), FLEET_HONESTY)


static func live_spread(state: Dictionary, from_id: String, to_id: String, good: String) -> float:
	var ma: Market = PortService.market_of(state, from_id)
	var mb: Market = PortService.market_of(state, to_id)
	return PortService.good_sell_price(mb, good) - PortService.good_buy_price(state, ma, good)


## Settles every round trip that has come home by `now_h`. Returns one report per trip:
## {"ship", "good", "from", "to", "gold", "result": "profit" | "lost" | "no_profit"}.
static func advance(state: Dictionary, now_h: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for entry: Dictionary in fleet(state):
		if not on_route(entry):
			continue
		var r: Dictionary = entry["route"]
		if not (PortData.PORTS.has(r["from"]) and PortData.PORTS.has(r["to"])):
			entry.erase("route")
			continue
		var trip_h: float = round_trip_hours(r["from"], r["to"])
		var settled: int = 0
		while float(r["next_h"]) <= now_h:
			if settled >= MAX_CATCH_UP:
				r["next_h"] = now_h + trip_h  # a long absence: the ship idled in port for the rest of it
				break
			r["next_h"] = float(r["next_h"]) + trip_h
			settled += 1
			reports.append(_trip(state, entry, rng))
	return reports


static func _trip(state: Dictionary, entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var r: Dictionary = entry["route"]
	var good: String = r["good"]
	var rep: Dictionary = {"ship": str(entry.get("name", "")), "good": good, "from": r["from"], "to": r["to"], "gold": 0, "result": "no_profit"}
	r["trips"] = int(r["trips"]) + 1
	var spread: float = live_spread(state, r["from"], r["to"], good)
	if spread <= 0.0:
		r["last"] = 0
		return rep  # the gap has closed: the master sails home with his hold empty
	var units: float = units_for(entry, good)
	var gold: int = int(FleetOrders.simulate_trip(units, spread, FLEET_HONESTY, rng))
	if gold <= 0:
		r["lost"] = int(r["lost"]) + 1
		r["last"] = 0
		entry["hull"] = maxf(float(entry.get("hull", 1.0)) - LOSS_HULL, 0.3)
		rep["result"] = "lost"
		return rep
	var ma: Market = PortService.market_of(state, r["from"])
	ma.stock[good] = maxf(float(ma.stock[good]) - units, float(ma.target[good]) * Market.STOCK_MIN)
	PortService.store_market(state, r["from"], ma)
	var mb: Market = PortService.market_of(state, r["to"])
	mb.stock[good] = minf(float(mb.stock[good]) + units, float(mb.target[good]) * Market.STOCK_MAX)
	PortService.store_market(state, r["to"], mb)
	state["gold"] = int(state["gold"]) + gold
	r["earned"] = int(r["earned"]) + gold
	r["last"] = gold
	rep["gold"] = gold
	rep["result"] = "profit"
	return rep


static func report_text(rep: Dictionary) -> String:
	var a: String = PortData.PORTS[rep["from"]]["name"]
	var b: String = PortData.PORTS[rep["to"]]["name"]
	match str(rep["result"]):
		"profit":
			return Loc.t("troute.trip_profit") % [rep["ship"], Loc.t("good." + str(rep["good"])), a, b, int(rep["gold"])]
		"lost":
			return Loc.t("troute.trip_lost") % [rep["ship"], a, b]
	return Loc.t("troute.trip_empty") % [rep["ship"], a, b]
