class_name TourState
extends RefCounted
## Where the player stands in each treasure tour, kept in Session.state["tours"]. Every step has a three-level
## hint path, every step can be restarted after a death, and a step left open too long gives its hints for free,
## so no tour can be locked.


static func root(state: Dictionary) -> Dictionary:
	if not state.has("tours"):
		state["tours"] = {}
	var t: Dictionary = state["tours"]
	for k in ["perks", "pearls", "deaths"]:
		if not t.has(k):
			t[k] = [] if k == "perks" else 0
	return t


static func progress(state: Dictionary, tour_id: String) -> Dictionary:
	var t: Dictionary = root(state)
	if not t.has(tour_id):
		t[tour_id] = {"step": 0, "checkpoint": -1, "done": false, "step_time": 0.0, "hints": {}, "paid": 0, "puzzle_turns": []}
	return t[tour_id]


static func is_done(state: Dictionary, tour_id: String) -> bool:
	return bool(progress(state, tour_id)["done"])


static func current_step(state: Dictionary, tour_id: String) -> Dictionary:
	var p: Dictionary = progress(state, tour_id)
	var s: Array = TourData.steps(tour_id)
	return s[mini(int(p["step"]), s.size() - 1)]


static func tick(state: Dictionary, delta: float) -> void:
	for id: String in TourData.all_ids():
		var p: Dictionary = progress(state, id)
		if not p["done"] and MapFragments.owned(state, id) > 0:
			p["step_time"] = float(p["step_time"]) + delta


## Tours the player has at least one fragment for and has not finished.
static func active(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in TourData.all_ids():
		if MapFragments.owned(state, id) > 0 and not is_done(state, id):
			out.append(id)
	return out


## The map is read once the third fragment is in and the rotate puzzle is joined. Moves on to the first voyage.
static func read_map(state: Dictionary, tour_id: String, turns: Array[int], hour: float = 12.0) -> bool:
	var p: Dictionary = progress(state, tour_id)
	if bool(current_step(state, tour_id).get("night", false)) and not TourHazards.moonlit(hour):
		return false  # the ink only shows under the moon
	if int(p["step"]) != 0 or MapFragments.owned(state, tour_id) < TourData.FRAGMENTS_PER_TOUR:
		return false
	if not MapFragments.is_joined(turns):
		return false
	complete_step(state, tour_id)
	return true


## Whether the player's position and the clock satisfy a sail, landing or escape step.
static func arrived(step: Dictionary, pos: Vector2, hour: float, tide: float) -> bool:
	if pos.distance_to(TourData.step_pos(step)) > TourData.ARRIVE_M:
		return false
	if step.has("tide_below") and tide > float(step["tide_below"]):
		return false
	if bool(step.get("dusk", false)) and (hour < TourData.DUSK_FROM_H or hour > TourData.DUSK_TO_H):
		return false
	if bool(step.get("night", false)) and not TourHazards.moonlit(hour):
		return false
	return true


static func check_paces(step: Dictionary, counted: int) -> bool:
	return absi(counted - int(step["paces"])) <= TourData.PACE_TOLERANCE


## Finish the current step. The step just done becomes the checkpoint. Returns true when the tour is complete.
static func complete_step(state: Dictionary, tour_id: String) -> bool:
	var p: Dictionary = progress(state, tour_id)
	p["checkpoint"] = int(p["step"])
	p["step"] = int(p["step"]) + 1
	p["step_time"] = 0.0
	if int(p["step"]) >= TourData.steps(tour_id).size():
		finish(state, tour_id)
		return true
	return false


static func finish(state: Dictionary, tour_id: String) -> void:
	var p: Dictionary = progress(state, tour_id)
	if bool(p["done"]):
		return
	p["done"] = true
	var r: Dictionary = TourData.tour(tour_id)["reward"]
	state["gold"] = int(state["gold"]) + int(r["gold"])
	var t: Dictionary = root(state)
	for perk: String in r["perks"]:
		TourRewards.grant_perk(state, perk)
	t["pearls"] = int(t["pearls"]) + int(r["pearls"])
	state["fame"] = int(state["fame"]) + 50
	CrewLife.award_xp(state, "tour")


## A tour with prerequisites is open once they are all done.
static func available(state: Dictionary, tour_id: String) -> bool:
	if not TourData.tour(tour_id).has("requires"):
		return true
	for req: String in TourData.tour(tour_id)["requires"]:
		if not is_done(state, req):
			return false
	return true


## Ask for a hint at a level. Level 1 is the navigator and always free. Levels 2 and 3 cost gold at a tavern, but
## are free once the step has been open for ten minutes or when the player cannot pay.
static func hint(state: Dictionary, tour_id: String, level: int) -> Dictionary:
	level = clampi(level, 1, 3)
	var p: Dictionary = progress(state, tour_id)
	var step: Dictionary = current_step(state, tour_id)
	var key: String = "%s.hint%d" % [step["text"], level]
	var cost: int = TourData.HINT_COST[level]
	var already: bool = int(p["hints"].get(step["id"], 0)) >= level
	var free: bool = already or cost == 0 or float(p["step_time"]) >= TourData.STUCK_FREE_S or int(state["gold"]) < cost
	if not free:
		state["gold"] = int(state["gold"]) - cost
		p["paid"] = int(p["paid"]) + cost
	p["hints"][step["id"]] = maxi(int(p["hints"].get(step["id"], 0)), level)
	return {"ok": true, "key": key, "cost": 0 if free else cost, "level": level, "pos": TourData.step_pos(step) if level == 3 else Vector2.ZERO}


## The player died on a tour step. They lose a fifth of their gold, the step restarts and they wake at the
## last checkpoint (or Haven Rock before the first one). Returns {respawn: Vector2, lost: int}.
static func on_death(state: Dictionary, tour_id: String) -> Dictionary:
	var p: Dictionary = progress(state, tour_id)
	var lost: int = int(float(state["gold"]) * TourData.DEATH_GOLD_LOSS)
	state["gold"] = int(state["gold"]) - lost
	root(state)["deaths"] = int(root(state)["deaths"]) + 1
	p["step_time"] = 0.0
	var at: Vector2
	if int(p["checkpoint"]) >= 0:
		at = TourData.step_pos(TourData.steps(tour_id)[int(p["checkpoint"])])
	else:
		at = TourData.step_pos(TourData.steps(tour_id)[0])
	return {"respawn": at, "lost": lost}


## Every step of every tour has all three hint texts.
static func hint_paths_complete() -> bool:
	for id: String in TourData.tour_ids():
		for s: Dictionary in TourData.steps(id):
			for lv in range(1, 4):
				if Loc.t("%s.hint%d" % [s["text"], lv]) == "%s.hint%d" % [s["text"], lv]:
					return false
	return true
