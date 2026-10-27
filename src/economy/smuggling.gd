class_name Smuggling
extends RefCounted
## Illegal cargo at lawful ports: inspection odds, the three ways out of a catch, fences and black markets.

enum Choice { PAY_FINE, BRIBE, FIGHT }


static func illegal_goods(cargo: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for g: String in cargo:
		if float(cargo[g]) > 0.0 and not bool(Goods.DATA[g]["legal"]):
			out.append(g)
	return out


## Chance a ship carrying illegal cargo is searched on entering a lawful port.
static func inspection_chance(stars: int, night: bool, smuggler_hold: bool) -> float:
	var p: float = TradeData.INSPECT_BASE + TradeData.INSPECT_PER_STAR * float(stars)
	if night:
		p *= TradeData.INSPECT_NIGHT_MULT
	if smuggler_hold:
		p *= TradeData.INSPECT_SMUGGLER_MULT
	return clampf(p, 0.0, 1.0)


static func is_night(hour: float) -> bool:
	return hour >= TradeData.NIGHT_START_H or hour < TradeData.NIGHT_END_H


static func bounty_stars(state: Dictionary, faction: String) -> int:
	var b: float = float(state["bounty"].get(faction, 0.0))
	return int(Reputation.hunter_response(b)["stars"])


## Rolls an inspection for entering `port_id`. False for pirate ports, clean holds, or a lucky roll.
static func rolled(state: Dictionary, port_id: String, rng: RandomNumberGenerator) -> bool:
	var port: Dictionary = PortData.PORTS[port_id]
	if not bool(port["lawful"]) or illegal_goods(state["cargo"]).is_empty():
		return false
	var p: float = inspection_chance(bounty_stars(state, port["faction"]), is_night(float(state["hour"])), state["upgrades"].has("smugglers_hold"))
	return rng.randf() < p


## Value of the illegal cargo at the port's own prices.
static func illegal_value(state: Dictionary, port_id: String) -> float:
	var m: Market = PortService.market_of(state, port_id)
	var v: float = 0.0
	for g in illegal_goods(state["cargo"]):
		v += m.mid_price(g) * float(state["cargo"][g])
	return v


static func bribe_chance(leadership_rank: int) -> float:
	return TradeData.BRIBE_SUCCESS + (TradeData.BRIBE_LEADERSHIP_BONUS if leadership_rank >= TradeData.BRIBE_LEADERSHIP_RANK else 0.0)


## Settles a catch. Returns {ok, kept_cargo, gold, hostile}. A failed bribe costs the bribe and then the fine.
static func resolve(state: Dictionary, port_id: String, choice: Choice, rng: RandomNumberGenerator, leadership_rank: int = 0) -> Dictionary:
	var faction: String = PortData.PORTS[port_id]["faction"]
	var value: float = illegal_value(state, port_id)
	var out: Dictionary = {"ok": true, "kept_cargo": false, "gold": 0, "hostile": false}
	match choice:
		Choice.PAY_FINE:
			var fine: int = ceili(value * TradeData.FINE_MULT)
			out["gold"] = -mini(fine, int(state["gold"]))
			state["gold"] = int(state["gold"]) + int(out["gold"])
			_confiscate(state)
			state["rep"][faction] = clampf(float(state["rep"][faction]) + TradeData.FINE_REP, -100.0, 100.0)
		Choice.BRIBE:
			var cost: int = ceili(value * TradeData.BRIBE_FRACTION)
			if cost > int(state["gold"]):
				out["ok"] = false
				return out
			state["gold"] = int(state["gold"]) - cost
			out["gold"] = -cost
			if rng.randf() < bribe_chance(leadership_rank):
				out["kept_cargo"] = true
			else:
				var fine2: int = mini(ceili(value * TradeData.FINE_MULT), int(state["gold"]))
				state["gold"] = int(state["gold"]) - fine2
				out["gold"] = int(out["gold"]) - fine2
				_confiscate(state)
				state["rep"][faction] = clampf(float(state["rep"][faction]) + TradeData.FINE_REP, -100.0, 100.0)
		Choice.FIGHT:
			out["kept_cargo"] = true
			out["hostile"] = true
			state["rep"][faction] = minf(float(state["rep"][faction]), TradeData.FIGHT_REP_CAP)
			state["bounty"][faction] = float(state["bounty"].get(faction, 0.0)) + TradeData.FIGHT_BOUNTY
	return out


static func _confiscate(state: Dictionary) -> void:
	for g in illegal_goods(state["cargo"]):
		state["cargo"].erase(g)


## Price multiplier of base for illegal goods at this port, or 0 when it will not buy them.
static func illegal_buy_mult(port_id: String) -> float:
	var port: Dictionary = PortData.PORTS[port_id]
	if bool(port.get("black_market", false)):
		return TradeData.BLACK_MARKET_MULT
	if bool(port.get("fence", false)):
		return TradeData.FENCE_MULT
	return 0.0


## Sells illegal goods to a fence or black market at the flat multiple of base price. Returns gold.
static func sell_illegal(state: Dictionary, port_id: String, good: String, units: int) -> int:
	var mult: float = illegal_buy_mult(port_id)
	var have: int = int(state["cargo"].get(good, 0.0))
	var n: int = mini(units, have)
	if mult <= 0.0 or n <= 0 or bool(Goods.DATA[good]["legal"]):
		return 0
	var gain: int = floori(Goods.base_price(good) * mult * float(n))
	state["cargo"][good] = float(have - n)
	if have - n <= 0:
		state["cargo"].erase(good)
	state["gold"] = int(state["gold"]) + gain
	return gain
