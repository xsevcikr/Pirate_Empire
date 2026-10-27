class_name Base
extends RefCounted
## A player base: build grid, build queue (days), daily income and upkeep, defence rating.

var base_name: String = ""
var tier: String = "outpost"
var buildings: Array[Dictionary] = []  ## {type, level, damaged}
var queue: Array[Dictionary] = []  ## {type, level, days_left}
var gold_stored: float = 0.0  ## uncollected income
var accrued_days: float = 0.0
var stored_goods: float = 0.0
var garrison: int = 0
var station_ships: Array[Dictionary] = []  ## {broadside_power}
var fallen: bool = false


func _init(n: String = "") -> void:
	base_name = n


func plots_used() -> int:
	var seen: Dictionary = {}  # upgrading a building reuses its plots
	for b in buildings:
		seen[b["type"]] = true
	for q in queue:
		seen[q["type"]] = true
	var n: int = 0
	for t in seen.keys():
		n += BuildingData.plots(t)
	return n


func plots_total() -> int:
	return BuildingData.BASE_TIERS[tier]["plots"]


func level_of(type: String) -> int:
	var lv: int = 0
	for b in buildings:
		if b["type"] == type:
			lv = maxi(lv, b["level"])
	return lv


## Start construction. Returns gold left or -1 when refused (no plots, no funds, wrong level order).
func build(type: String, gold: int) -> int:
	var level: int = level_of(type) + 1
	for q in queue:
		if q["type"] == type:
			level = maxi(level, q["level"] + 1)
	if level > BuildingData.levels(type):
		return -1
	if level == 1 and plots_used() + BuildingData.plots(type) > plots_total():
		return -1
	var c: int = BuildingData.cost(type, level)
	if c > gold:
		return -1
	queue.append({"type": type, "level": level, "days_left": float(BuildingData.days(type, level))})
	return gold - c


## Advance build days and income. Income accrues only for active buildings, capped at 7 days of production.
func advance_days(days: float) -> void:
	var left: float = days
	while left > 0.0:
		var step: float = minf(left, 0.25)
		left -= step
		for q in queue:
			q["days_left"] -= step
		var done: Array[Dictionary] = []
		for q in queue:
			if q["days_left"] <= 0.0:
				done.append(q)
		for q in done:
			queue.erase(q)
			_complete(q)
		if not fallen:
			accrued_days = minf(accrued_days + step, BuildingData.ACCRUAL_CAP_DAYS)
			gold_stored = minf(gold_stored + net_daily() * step, maxf(net_daily(), 0.0) * BuildingData.ACCRUAL_CAP_DAYS)


func _complete(q: Dictionary) -> void:
	for b in buildings:
		if b["type"] == q["type"]:
			b["level"] = q["level"]
			return
	buildings.append({"type": q["type"], "level": q["level"], "damaged": false})


func rush_cost(type: String) -> float:
	for q in queue:
		if q["type"] == type:
			return ceil(q["days_left"] * 24.0) * BuildingData.RUSH_GOLD_PER_HOUR
	return 0.0


func gross_daily() -> float:
	var t: float = 0.0
	for b in buildings:
		if not b["damaged"]:
			t += BuildingData.income(b["type"], b["level"])
	return t


func upkeep_daily() -> float:
	var t: float = 0.0
	for b in buildings:
		t += BuildingData.upkeep(b["type"], b["level"])
	return t


func net_daily() -> float:
	return gross_daily() - upkeep_daily()


## Dock and collect accrued income.
func collect() -> int:
	var g: int = int(gold_stored)
	gold_stored = 0.0
	accrued_days = 0.0
	return g


## Defence rating: tower firepower, garrison and walls, plus station ships' broadsides.
func defence_rating() -> float:
	var r: float = 0.0
	for b in buildings:
		match b["type"]:
			"cannon_tower":
				r += 120.0 * (1.5 if b["level"] > 1 else 1.0)
			"fort_walls":
				r += BuildingData.DATA["fort_walls"]["wall_hp"][b["level"] - 1] / 40.0
	r += garrison * 2.0
	for s in station_ships:
		r += s["broadside_power"]
	return r


func damage_random_building(rng: RandomNumberGenerator) -> void:
	if buildings.is_empty():
		return
	buildings[rng.randi() % buildings.size()]["damaged"] = true


func upgrade_tier(gold: int) -> int:
	var cost: int = BuildingData.BASE_TIERS[tier]["upgrade_cost"]
	if cost <= 0 or cost > gold:
		return -1
	tier = "stronghold" if tier == "outpost" else "fortress_capital"
	return gold - cost
