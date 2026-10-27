class_name RivalState
extends RefCounted
## What each rival remembers, kept in Session.state["rivals"]: the rivalry meter (0-100), their level, how often
## you have met, who won, the trophy they took and whether they are beaten.

static func root(state: Dictionary) -> Dictionary:
	if not state.has("rivals"):
		state["rivals"] = {}
	var r: Dictionary = state["rivals"]
	if not r.has("taunts"):
		r["taunts"] = []
	if not r.has("rewards"):
		r["rewards"] = []
	if not r.has("nemesis"):
		r["nemesis"] = ""
	return r


static func get_rival(state: Dictionary, id: String) -> Dictionary:
	var r: Dictionary = root(state)
	if not r.has(id):
		r[id] = {"meter": 0.0, "level": 1, "met": 0, "wins": 0, "losses": 0, "beaten_me": false, "trophy": "", "defeated": false, "spared": false, "choice": "", "stage": 0}
	return r[id]


static func is_defeated(state: Dictionary, id: String) -> bool:
	return bool(get_rival(state, id)["defeated"])


## Whether the arc may begin: the rival's own condition (a fragment, a finished tour, prizes taken, a bounty).
static func available(state: Dictionary, id: String) -> bool:
	if RivalData.CAMPAIGN.has(id) or is_defeated(state, id):
		return false
	var need: Dictionary = RivalData.def(id)["start"]
	if need.has("fragments") and (state["map_fragments"] as Array).size() < int(need["fragments"]):
		return false
	if need.has("tours_done"):
		var done: int = 0
		for t: String in TourData.tour_ids():
			if TourState.is_done(state, t):
				done += 1
		if done < int(need["tours_done"]):
			return false
	if need.has("prizes") and int(state.get("prizes_taken", 0)) < int(need["prizes"]):
		return false
	if need.has("bounty"):
		var top: float = 0.0
		for v in state["bounty"].values():
			top = maxf(top, float(v))
		if top < float(need["bounty"]):
			return false
	return true


## Chance per hour that this rival comes looking for you in `region`.
static func challenge_chance(state: Dictionary, id: String, region: String) -> float:
	if not available(state, id):
		return 0.0
	var d: Dictionary = RivalData.def(id)
	var nemesis: bool = root(state)["nemesis"] == id
	if not nemesis and not (d["home"] as Array).has(region):
		return 0.0
	var p: float = RivalData.CHALLENGE_PER_HOUR_MAX * float(get_rival(state, id)["meter"]) / RivalData.METER_MAX
	return p * (RivalData.NEMESIS_FACTOR if nemesis else 1.0)


## The rival who beat you most recently and keeps coming back.
static func nemesis(state: Dictionary) -> String:
	return str(root(state)["nemesis"])


## First meeting before any fight: the meter starts rising.
static func meet(state: Dictionary, id: String) -> void:
	var r: Dictionary = get_rival(state, id)
	r["met"] = int(r["met"]) + 1
	r["meter"] = minf(RivalData.METER_MAX, float(r["meter"]) + RivalData.MEET_GAIN)


## A fight is over. Returns {"won", "level", "trophy", "taunt", "reward", "arc_step"}. A loss levels the rival up,
## takes a trophy and sends a taunt by bottle; a win at the third encounter ends the arc and pays the reward.
static func record(state: Dictionary, id: String, player_won: bool, spare: bool = false) -> Dictionary:
	var r: Dictionary = get_rival(state, id)
	var root_d: Dictionary = root(state)
	var out: Dictionary = {"won": player_won, "level": int(r["level"]), "trophy": "", "taunt": "", "reward": {}, "arc_step": ""}
	meet(state, id)
	var arc: Array = RivalData.ARC[id]
	out["arc_step"] = arc[mini(int(r["stage"]), arc.size() - 1)]
	if not player_won:
		r["losses"] = int(r["losses"]) + 1
		r["level"] = mini(RivalData.LEVEL_MAX, int(r["level"]) + 1)
		r["meter"] = minf(RivalData.METER_MAX, float(r["meter"]) + RivalData.LOSS_GAIN)
		r["beaten_me"] = true
		r["trophy"] = RivalData.TROPHIES[int(r["losses"]) % RivalData.TROPHIES.size()] if r["trophy"] == "" else r["trophy"]
		root_d["nemesis"] = id
		out["level"] = int(r["level"])
		out["trophy"] = r["trophy"]
		out["taunt"] = "rival.taunt." + id
		(root_d["taunts"] as Array).append({"rival": id, "day": int(state["day"])})
		return out
	r["wins"] = int(r["wins"]) + 1
	r["meter"] = minf(RivalData.METER_MAX, float(r["meter"]) + RivalData.WIN_GAIN)
	r["stage"] = int(r["stage"]) + 1
	if int(r["stage"]) >= RivalData.ARC_LENGTH or RivalData.CAMPAIGN.has(id):
		out["reward"] = claim(state, id, spare)
	if root_d["nemesis"] == id and bool(r["beaten_me"]) and int(r["stage"]) >= RivalData.ARC_LENGTH:
		root_d["nemesis"] = ""
	return out


## Pay out the defeat reward once. Beating a rival who beat you pays double gold. Sparing Molly (or pardoning Vale)
## trades the ship for an officer.
static func claim(state: Dictionary, id: String, spare: bool) -> Dictionary:
	var r: Dictionary = get_rival(state, id)
	if bool(r["defeated"]):
		return {}
	r["defeated"] = true
	var d: Dictionary = RivalData.def(id)
	var gold: int = int(d["gold"]) * (int(RivalData.DOUBLE_REWARD) if bool(r["beaten_me"]) else 1)
	state["gold"] = int(state["gold"]) + gold
	var got: Dictionary = {"gold": gold, "doubled": bool(r["beaten_me"])}
	var reward: Dictionary = d["reward"]
	var spared: bool = spare and bool(d["spare"])
	r["spared"] = spared
	if reward.has("perk"):
		got["perks"] = TourRewards.boss_defeated(state, str(reward["perk"]))
	if reward.has("officer") and (spared or not reward.has("ship")):
		(state["officers"] as Array).append(reward["officer"])
		got["officer"] = reward["officer"]
	if reward.has("ship") and not spared:
		(state["fleet"] as Array).append({"class": reward["ship"], "name": str(d["name"]) + "'s " + str(reward["ship"]), "crew": 0, "hull": 1.0})
		got["ship"] = reward["ship"]
	if reward.has("hold"):
		(root(state)["rewards"] as Array).append(reward["hold"])
		got["hold"] = reward["hold"]
	if reward.has("coves"):
		(root(state)["rewards"] as Array).append("cove_network")
		got["coves"] = true
	r["choice"] = "spare" if spared else "defeat"
	return got


## Stats for a rival's ship in the world: their level scales hull and guns.
static func ship_strength(state: Dictionary, id: String) -> Dictionary:
	var d: Dictionary = RivalData.def(id)
	var lvl: int = int(get_rival(state, id)["level"])
	var s: float = RivalData.strength(id, lvl)
	return {"hp": float(d["hp"]) * s, "guns": float(d["guns"]) * s, "level": lvl,
		"class": str(d.get("ship_late", d["ship"])) if lvl >= 3 and d.has("ship_late") else str(d["ship"])}


## A campaign boss fight result feeds the same record.
static func boss_result(state: Dictionary, id: String, won: bool) -> Dictionary:
	return record(state, id, won)
