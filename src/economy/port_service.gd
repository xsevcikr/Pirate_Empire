class_name PortService
extends RefCounted
## Everything a player does in port, as plain functions on the save-state dictionary so it can be tested without UI.

const NAMES: PackedStringArray = [
	"Tom Gull", "Ned Brine", "Sal Marrow", "Jack Tarry", "Dob Keel", "Mick Salt", "Pip Rigger", "Wat Hook", "Hob Mizzen",
	"Cass Reef", "Bess Plank", "Nan Barnacle", "Kit Anchor", "Jem Pitch", "Rafe Cutter", "Lowrie Tide", "Sim Sprat", "Abel Wake",
]
const TIER_LEVEL: Dictionary = {"green": 1, "seasoned": 2}


static func ship_stats(class_id: String) -> ShipStats:
	return load("res://data/ships/%s.tres" % class_id)


static func price_mult(state: Dictionary) -> float:
	return PortData.PRICE_MULT_BY_DIFFICULTY[clampi(int(state["difficulty"]), 0, 3)]


static func market_of(state: Dictionary, port_id: String) -> Market:
	var m: Market = PortData.build_market(port_id)
	var saved: Dictionary = state["markets"].get(port_id, {})
	if not saved.is_empty():
		m.load_dict(saved)
	m.rep_mod = float(TradeData.REP_MOD[Reputation.tier(float(state["rep"].get(PortData.PORTS[port_id]["faction"], 0.0)))])
	return m


static func store_market(state: Dictionary, port_id: String, m: Market) -> void:
	state["markets"][port_id] = m.to_dict()


static func advance_markets(state: Dictionary, hours: float) -> void:
	for port_id: String in PortData.PORTS.keys():
		var m: Market = market_of(state, port_id)
		m.advance(hours)
		store_market(state, port_id, m)


# ---- cargo -------------------------------------------------------------------------------------

static func cargo_used(state: Dictionary) -> float:
	var t: float = 0.0
	for g: String in state["cargo"]:
		t += float(state["cargo"][g]) * Goods.DATA[g]["weight"]
	for s: String in state["supplies"]:
		t += float(state["supplies"][s]) * PortData.SUPPLIES[s]["weight"]
	return t


static func cargo_capacity(state: Dictionary) -> float:
	return ship_stats(state["ship_class"]).cargo_t


static func cargo_free(state: Dictionary) -> float:
	return cargo_capacity(state) - cargo_used(state)


static func food_days(state: Dictionary) -> float:
	return CrewLife.days_left(state, "food")


# ---- goods and supplies ------------------------------------------------------------------------

static func supply_price(state: Dictionary, market: Market, id: String) -> float:
	var s: Dictionary = PortData.SUPPLIES[id]
	var p: float = market.buy_price(s["good"]) if s.has("good") else float(s["price"])
	return p * price_mult(state)


static func good_buy_price(state: Dictionary, market: Market, good: String) -> float:
	return market.buy_price(good) * price_mult(state)


static func good_sell_price(market: Market, good: String) -> float:
	return market.sell_price(good)


static func buy_good(state: Dictionary, market: Market, good: String, units: int) -> bool:
	if units <= 0 or units * Goods.DATA[good]["weight"] > cargo_free(state):
		return false
	var cost: float = market.player_buy(good, units, 1.0e9) * price_mult(state)
	if cost < 0.0 or ceili(cost) > int(state["gold"]):
		if cost >= 0.0:
			market.stock[good] += units  # undo
		return false
	state["gold"] = int(state["gold"]) - ceili(cost)
	state["cargo"][good] = float(state["cargo"].get(good, 0.0)) + units
	return true


## Sells up to `units` of a good; returns the gold received.
static func sell_good(state: Dictionary, market: Market, good: String, units: int) -> int:
	var have: int = int(state["cargo"].get(good, 0.0))
	var n: int = mini(units, have)
	if n <= 0:
		return 0
	var gain: int = floori(market.player_sell(good, n) * Progression.stat(state, "sell_price_mult"))
	state["cargo"][good] = float(have - n)
	if have - n <= 0:
		state["cargo"].erase(good)
	state["gold"] = int(state["gold"]) + gain
	return gain


static func buy_supply(state: Dictionary, market: Market, id: String, units: int) -> bool:
	var spec: Dictionary = PortData.SUPPLIES[id]
	if units <= 0 or units * spec["weight"] > cargo_free(state):
		return false
	var cost: float
	if spec.has("good"):
		cost = market.player_buy(spec["good"], units, 1.0e9) * price_mult(state)
	else:
		cost = float(spec["price"]) * units * price_mult(state)
	if cost < 0.0 or ceili(cost) > int(state["gold"]):
		if cost >= 0.0 and spec.has("good"):
			market.stock[spec["good"]] += units
		return false
	state["gold"] = int(state["gold"]) - ceili(cost)
	state["supplies"][id] = float(state["supplies"][id]) + units
	return true


# ---- crew --------------------------------------------------------------------------------------

static func crew_room(state: Dictionary) -> int:
	return ship_stats(state["ship_class"]).crew_max - int(state["crew"])


## Specialists on offer today: one per tavern level, redrawn every two days, minus those already hired.
static func tavern_offers(state: Dictionary, port_id: String) -> Array[String]:
	var window: int = floori(float(state["day"]) / float(PortData.HIRE_REFRESH_DAYS))
	if int(state["offers_window"]) != window:
		state["offers_window"] = window
		state["offers_taken"] = []
	var out: Array[String] = []
	for t in CrewTypes.offers(int(state["seed"]), int(state["day"]), PortData.PORTS[port_id]["tavern_level"]):
		if not state["offers_taken"].has(t):
			out.append(t)
	return out


static func hire(state: Dictionary, tier: String, port_id: String) -> bool:
	if not TIER_LEVEL.has(tier):
		return _hire_specialist(state, tier, port_id)
	var cm := CrewManager.new()
	cm.gold = int(state["gold"])
	var level: int = PortData.PORTS[port_id]["tavern_level"]
	if not cm.hire(1, tier, level, int(state["crew"]), ship_stats(state["ship_class"]).crew_max, Progression.stat(state, "hire_cost_mult") * Bounty.hire_mult(state, port_id)):
		return false
	state["gold"] = cm.gold
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 131 + state["roster"].size() * 17 + int(state["crew"])
	state["roster"].append({"name": NAMES[rng.randi() % NAMES.size()], "type": tier, "level": 1, "xp": 0})
	state["crew"] = int(state["crew"]) + 1
	return true


static func _hire_specialist(state: Dictionary, type: String, port_id: String) -> bool:
	if not tavern_offers(state, port_id).has(type) or crew_room(state) <= 0:
		return false
	var cost: int = int(CrewTypes.TYPES[type]["hire"])
	if cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	state["offers_taken"].append(type)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 131 + state["roster"].size() * 17 + int(state["crew"]) + 5
	state["roster"].append({"name": NAMES[rng.randi() % NAMES.size()], "type": type, "level": 1, "xp": 0})
	state["crew"] = int(state["crew"]) + 1
	return true


# ---- outfitter ---------------------------------------------------------------------------------

static func ammo_price_per_10(state: Dictionary, ammo_id: String) -> int:
	return ceili(GunData.AMMO[ammo_id]["cost"] * PortData.AMMO_MULT_BY_DIFFICULTY[clampi(int(state["difficulty"]), 0, 3)])


static func buy_ammo(state: Dictionary, ammo_id: String, tens: int) -> bool:
	var cost: int = ammo_price_per_10(state, ammo_id) * tens
	if tens <= 0 or cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	state["ammo"][ammo_id] = int(state["ammo"].get(ammo_id, 0)) + tens * 10
	return true


static func buy_weapon(state: Dictionary, id: String) -> bool:
	var w: Dictionary = WeaponData.WEAPONS[id]
	if state["owned_weapons"].has(id) or int(w["price"]) > int(state["gold"]) or int(w["price"]) <= 0:
		return false
	state["gold"] = int(state["gold"]) - int(w["price"])
	state["owned_weapons"].append(id)
	match w["kind"]:
		"melee":
			state["melee"] = id
		"pistol":
			state["pistol"] = id
	return true


## Pistol/musket shots come from small-arms shot: 1 unit = 20 shots.
static func load_small_arms(state: Dictionary) -> void:
	var units: float = float(state["supplies"]["small_arms"])
	state["pistol_shots"] = int(state["pistol_shots"]) + int(units) * WeaponData.SHOTS_PER_SMALL_ARMS_UNIT
	state["supplies"]["small_arms"] = units - floorf(units)


# ---- shipyard ----------------------------------------------------------------------------------

static func upgrade_refund(state: Dictionary) -> int:
	var total: int = 0
	for line: String in state["upgrades"]:
		for tier in range(1, int(state["upgrades"][line]) + 1):
			total += Upgrades.refund(line, tier, state["ship_class"])
	return total


static func trade_in_value(state: Dictionary, new_class: String) -> int:
	var price: int = ship_stats(state["ship_class"]).price
	var v: int = floori(price * PortData.TRADE_IN_FRACTION * float(state["ship_hull"])) + upgrade_refund(state)
	if state.get("starter_exchange", false) and state["ship_class"] == PortData.STARTER_EXCHANGE["from"] and new_class == PortData.STARTER_EXCHANGE["to"]:
		v = maxi(v, int(PortData.STARTER_EXCHANGE["credit"]))
	return v


static func ship_cost(state: Dictionary, new_class: String) -> int:
	return maxi(ship_stats(new_class).price - trade_in_value(state, new_class), 0)


static func buy_ship(state: Dictionary, new_class: String, port_id: String) -> bool:
	var port: Dictionary = PortData.PORTS[port_id]
	if new_class == state["ship_class"] or not PortData.can_sell_class(port_id, new_class):
		return false
	var stats: ShipStats = ship_stats(new_class)
	if stats.infamy_required > int(state["fame"]):
		return false
	var cost: int = ship_cost(state, new_class)
	if cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	if new_class == PortData.STARTER_EXCHANGE["to"]:
		state["starter_exchange"] = false
	state["ship_class"] = new_class
	state["ship_hull"] = 1.0
	state["ship_damage"] = {"repaired": true}
	state["upgrades"] = {}
	state["crew"] = mini(int(state["crew"]), stats.crew_max)
	return true


static func repair_cost(state: Dictionary) -> int:
	var stats: ShipStats = ship_stats(state["ship_class"])
	var missing_hp: float = stats.hull_hp * (1.0 - float(state["ship_hull"]))
	return roundi(missing_hp * PortData.REPAIR_GOLD_PER_HP * Upgrades.CLASS_MULT[state["ship_class"]])


static func repair(state: Dictionary) -> bool:
	var cost: int = repair_cost(state)
	if cost <= 0 or cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	state["ship_hull"] = 1.0
	state["ship_damage"] = {"repaired": true}  # the shipyard plugs every hole and steps new masts too
	return true
