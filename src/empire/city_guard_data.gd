class_name CityGuardData
extends RefCounted
## The city watch: when the player fires on a harbour, its guard boats put out to defend it. Sink or take every one
## of them and the city's war chest is the player's: gold, cannon shot, pistol shot and rum, more for a bigger city.

## Guard boats each city size sends out, in launch order.
const WAVES: Dictionary = {
	"village": ["cutter", "cutter"],
	"town": ["cutter", "sloop", "sloop"],
	"city": ["sloop", "sloop", "brigantine"],
	"capital": ["sloop", "brigantine", "brigantine", "corvette"],
}
## What beating the whole watch pays, by city size.
const REWARDS: Dictionary = {
	"village": {"gold": 300, "round": 20, "pistol_shots": 4, "rum": 4.0},
	"town": {"gold": 700, "round": 30, "pistol_shots": 6, "rum": 6.0},
	"city": {"gold": 1500, "round": 50, "pistol_shots": 8, "rum": 10.0},
	"capital": {"gold": 3000, "round": 80, "pistol_shots": 12, "rum": 15.0},
}
## Each guard boat also carries a little of its own, paid when it sinks or is taken like any other prize.
const BOAT_LOOT: Dictionary = {"gold": [40, 110], "supplies": {"rum": 1.0}}
## Guards sail under the navy's colours, so they fight the player (and pirates) whoever owns the town.
const GUARD_FACTION: String = "navy"
## A city whose watch was beaten cannot raise a new one until this many days have passed.
const COOLDOWN_DAYS: int = 2
## The watch gives up and rows home when the player sails this far from the harbour.
const GIVE_UP_M: float = 2200.0
## Boats launch this far out from the pier head, spaced this far apart along the shore.
const LAUNCH_OUT_M: float = 120.0
const LAUNCH_SPACING_M: float = 70.0
const DETECT_M: float = 2000.0
const CLEAR_OF_PLAYER_M: float = 90.0


static func wave_for(tier: String) -> Array:
	return (WAVES.get(tier, WAVES["village"]) as Array).duplicate()


static func reward_for(tier: String) -> Dictionary:
	return (REWARDS.get(tier, REWARDS["village"]) as Dictionary).duplicate()


## Whether a city can send out its watch now: not if one is already out, nor shortly after the last was beaten.
static func can_launch(port_id: String, day: int, active: Dictionary, beaten_day: Dictionary) -> bool:
	if active.has(port_id):
		return false
	if beaten_day.has(port_id) and day - int(beaten_day[port_id]) < COOLDOWN_DAYS:
		return false
	return true


## Where each boat of a wave starts: in a line across the harbour mouth, out to sea from the dock. A boat that would
## start on top of the player's ship (`avoid`) is slid along the line so the two do not collide on launch.
static func launch_points(dock: Vector2, island_pos: Vector2, count: int, avoid: Variant = null) -> Array[Vector2]:
	var out_dir: Vector2 = (dock - island_pos).normalized()
	if out_dir == Vector2.ZERO:
		out_dir = Vector2(0, 1)
	var across: Vector2 = out_dir.orthogonal()
	var pts: Array[Vector2] = []
	for i in count:
		var off: float = (float(i) - float(count - 1) * 0.5) * LAUNCH_SPACING_M
		var p: Vector2 = dock + out_dir * LAUNCH_OUT_M + across * off
		if avoid is Vector2:
			var tries: int = 0
			while p.distance_to(avoid) < CLEAR_OF_PLAYER_M and tries < 8:
				p += across * (LAUNCH_SPACING_M if off >= 0.0 else -LAUNCH_SPACING_M)
				tries += 1
		pts.append(p)
	return pts


## Pay the war chest into the save: gold, round shot, pistol shot and rum. Returns what was paid.
static func pay(state: Dictionary, tier: String) -> Dictionary:
	var r: Dictionary = reward_for(tier)
	state["gold"] = int(state["gold"]) + int(r["gold"])
	var ammo: Dictionary = state["ammo"]
	ammo["round"] = int(ammo.get("round", 0)) + int(r["round"])
	state["pistol_shots"] = int(state.get("pistol_shots", 0)) + int(r["pistol_shots"])
	var sup: Dictionary = state["supplies"]
	sup["rum"] = float(sup.get("rum", 0.0)) + float(r["rum"])
	return r
