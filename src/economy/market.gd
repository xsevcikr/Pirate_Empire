class_name Market
extends RefCounted
## A port's market. Stock relative to a target stock drives the price; producers regenerate stock,
## consumers use it up, and the player's trades move it.

const PRICE_EXPONENT: float = 0.6  ## selling 10% of target stock drops the price roughly 6%
const STOCK_MIN: float = 0.1
const STOCK_MAX: float = 3.0
const PRODUCER_REGEN_PER_H: float = 0.04
const CONSUMER_USE_PER_H: float = 0.03
const RECOVER_PER_H: float = 0.04  ## stock drifts back toward target (about 24 h to recover a trade)
const PRICE_TICK_H: float = 6.0

var margin: float = 0.10  ## buy/sell spread, 8% to 14%
var target: Dictionary = {}  ## good -> target stock units
var stock: Dictionary = {}  ## good -> current stock units
var role: Dictionary = {}  ## good -> "producer" | "consumer" | "neutral"
var events: Dictionary = {}  ## event name -> hours remaining
var rep_mod: float = 0.0  ## -0.15 hated .. +0.10 allied (negative = prices worse for the player)
var _clock_h: float = 0.0


func _init(target_units: float = 100.0) -> void:
	for g in Goods.ids():
		target[g] = target_units
		stock[g] = target_units
		role[g] = "neutral"


func ratio(good: String) -> float:
	return clampf(stock[good] / maxf(target[good], 0.001), STOCK_MIN, STOCK_MAX)


func event_mult(good: String) -> float:
	var m: float = 1.0
	for e in events.keys():
		var list: Array = Goods.EVENT_GOODS[e]
		if list.is_empty() or good in list:
			m *= Goods.EVENT_MULT[e]
	return m


## Mid price: base x ratio^-0.6 x event multiplier. At ratio 1 and no events this equals the base price.
func mid_price(good: String) -> float:
	return Goods.base_price(good) * pow(ratio(good), -PRICE_EXPONENT) * event_mult(good)


## Price the player pays per unit (port sells). Hated factions pay more, allies get a discount.
func buy_price(good: String) -> float:
	return mid_price(good) * (1.0 + margin * 0.5) * (1.0 - rep_mod)


## Price the player receives per unit (port buys).
func sell_price(good: String) -> float:
	return mid_price(good) * (1.0 - margin * 0.5)


## Returns gold spent, or -1.0 if the purchase is impossible.
func player_buy(good: String, units: float, gold: float) -> float:
	if units <= 0.0 or stock[good] < units:
		return -1.0
	var cost: float = 0.0
	var per: float = units / 4.0
	for i in 4:  # price moves while buying
		cost += buy_price(good) * per
		stock[good] -= per
	if cost > gold:
		stock[good] += units
		return -1.0
	return cost


func player_sell(good: String, units: float) -> float:
	if units <= 0.0:
		return 0.0
	var gain: float = 0.0
	var per: float = units / 4.0
	for i in 4:
		gain += sell_price(good) * per
		stock[good] = minf(stock[good] + per, target[good] * STOCK_MAX)
	return gain


func advance(hours: float) -> void:
	var left: float = hours
	while left > 0.0:
		var h: float = minf(left, 1.0)
		left -= h
		_clock_h += h
		for g in Goods.ids():
			var t: float = target[g]
			var s: float = stock[g]
			match role[g]:
				"producer":
					s += t * PRODUCER_REGEN_PER_H * h
				"consumer":
					s -= t * CONSUMER_USE_PER_H * h
			s += (t - s) * RECOVER_PER_H * h  # mean reversion so prices stay bounded
			stock[g] = clampf(s, t * STOCK_MIN, t * STOCK_MAX)
		for e in events.keys():
			events[e] -= h
			if events[e] <= 0.0:
				events.erase(e)


func to_dict() -> Dictionary:
	return {"stock": stock.duplicate(), "events": events.duplicate(), "clock_h": _clock_h, "rep_mod": rep_mod}


func load_dict(d: Dictionary) -> void:
	for g in Goods.ids():
		if d.get("stock", {}).has(g):
			stock[g] = float(d["stock"][g])
	events = d.get("events", {}).duplicate()
	_clock_h = float(d.get("clock_h", 0.0))
	rep_mod = float(d.get("rep_mod", 0.0))


## +1 when the price sits more than 3% above the good's base price, -1 when more than 3% below, else 0.
func trend(good: String) -> int:
	var r: float = mid_price(good) / Goods.base_price(good)
	if r > 1.03:
		return 1
	if r < 0.97:
		return -1
	return 0
