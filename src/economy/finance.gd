class_name Finance
extends RefCounted
## Bank, insurance and what defeat costs.


static func has_bank(port_id: String) -> bool:
	return bool(PortData.PORTS[port_id].get("bank", false)) or PortData.PORTS[port_id]["tier"] == "capital"


static func deposit(state: Dictionary, gold: int) -> bool:
	if gold <= 0 or gold > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - gold
	state["bank"] = int(state["bank"]) + gold
	return true


static func withdraw(state: Dictionary, gold: int) -> bool:
	if gold <= 0 or gold > int(state["bank"]):
		return false
	state["bank"] = int(state["bank"]) - gold
	state["gold"] = int(state["gold"]) + gold
	return true


## Interest paid daily at 1% a week on the balance.
static func accrue(state: Dictionary, days: float) -> int:
	var interest: int = floori(float(state["bank"]) * TradeData.BANK_INTEREST_PER_WEEK * days / 7.0)
	state["bank"] = int(state["bank"]) + interest
	return interest


static func insurance_premium(state: Dictionary) -> int:
	return ceili(float(PortService.ship_stats(state["ship_class"]).price) * TradeData.INSURANCE_PREMIUM * Progression.stat(state, "insurance_cost_mult"))


static func buy_insurance(state: Dictionary) -> bool:
	if bool(state["insured"]):
		return false
	var cost: int = insurance_premium(state)
	if cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	state["insured"] = true
	return true


## The nearest port that will have you (not hated by its faction), by distance from `pos`.
static func nearest_friendly_port(state: Dictionary, pos: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: String in PortData.PORTS:
		var f: String = PortData.PORTS[id]["faction"]
		if not Reputation.port_access(float(state["rep"].get(f, 0.0))):
			continue
		var d: float = PortData.PORTS[id]["dock"].distance_to(pos)
		if d < best_d:
			best_d = d
			best = id
	return best if best != "" else PortData.START_PORT


## Sunk: wash up at the nearest friendly port, lose half the gold carried, the ship (unless insured) and 30% of the
## crew. The bank is safe. Returns what happened.
static func defeat(state: Dictionary, pos: Vector2) -> Dictionary:
	var port: String = nearest_friendly_port(state, pos)
	var lost_gold: int = floori(float(state["gold"]) * TradeData.DEFEAT_GOLD_LOSS)
	state["gold"] = int(state["gold"]) - lost_gold
	var crew_lost: int = floori(float(state["crew"]) * TradeData.DEFEAT_CREW_LOSS)
	CrewLife.remove_crew(state, crew_lost)
	var kept_ship: bool = bool(state["insured"])
	if kept_ship:
		state["ship_hull"] = TradeData.INSURED_HULL
		state["insured"] = false
	else:
		state["ship_class"] = TradeData.DEFEAT_START_CLASS
		state["ship_hull"] = 0.7
		state["upgrades"] = {}
		state["crew"] = mini(int(state["crew"]), PortService.ship_stats(TradeData.DEFEAT_START_CLASS).crew_max)
		while state["roster"].size() > int(state["crew"]):
			state["roster"].pop_back()
	state["cargo"] = {}
	state["docked_at"] = port
	var dock: Vector2 = PortData.PORTS[port]["dock"]
	state["pos"] = [dock.x, dock.y]
	return {"port": port, "gold_lost": lost_gold, "crew_lost": crew_lost, "ship_kept": kept_ship}


## Standing with a port's faction: tier name and the price modifier it brings.
static func standing(state: Dictionary, port_id: String) -> Dictionary:
	var f: String = PortData.PORTS[port_id]["faction"]
	var v: float = float(state["rep"].get(f, 0.0))
	var t: String = Reputation.tier(v)
	return {"faction": f, "value": v, "tier": t, "price_mod": float(TradeData.REP_MOD[t]), "access": Reputation.port_access(v)}
