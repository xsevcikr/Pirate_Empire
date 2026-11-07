class_name SeaEvents
extends RefCounted
## Hourly random events at sea. chance() gives the odds for one hour in a context; roll() decides which events
## fire. Rolls use a running total per event (with a random start kept in the save), so over a long voyage each
## event fires as often as its table chance says, give or take one, and not in lumps. apply() carries out the
## events that need no ship; the spatial ones return a spawn order for the world.

const NAVY_REP_LOW: float = -60.0
const NAVY_REP_HIGH: float = 30.0
const BOUNTY_FULL: float = 150.0


## ctx: region, season, storm (bool), night (bool), navy_rep, bounty.
static func chance(id: String, ctx: Dictionary) -> float:
	var e: Dictionary = SeaEventData.EVENTS[id]
	var region: String = str(ctx.get("region", ""))
	if e.has("only_region") and region != str(e["only_region"]):
		return 0.0
	var need: String = str(e.get("needs", ""))
	if need != "" and not bool(ctx.get(need, false)):
		return 0.0
	var base: float = float(e["weekly"]) / 168.0 if e.has("weekly") else float(e["chance"])
	if id == "navy_patrol":
		var rep_term: float = clampf((SeaEvents.NAVY_REP_HIGH - float(ctx.get("navy_rep", -30.0))) / (SeaEvents.NAVY_REP_HIGH - SeaEvents.NAVY_REP_LOW), 0.0, 1.0)
		var bounty_term: float = clampf(float(ctx.get("bounty", 0.0)) / SeaEvents.BOUNTY_FULL, 0.0, 1.0)
		var pressure: float = clampf(0.5 * rep_term + 0.5 * bounty_term, 0.0, 1.0)
		base = lerpf(float(e["min"]), float(e["max"]), pressure)
		return base * SeaEventData.mult(e.get("region", {}), region) / _region_mean(e) * SeaEventData.mult(e.get("season", {}), str(ctx.get("season", "")))
	return base * SeaEventData.mult(e.get("region", {}), region) * SeaEventData.mult(e.get("season", {}), str(ctx.get("season", ""))) / SeaEventData.norm(id)


static func _region_mean(e: Dictionary) -> float:
	var s: float = 0.0
	for r in SeaEventData.REGIONS:
		s += SeaEventData.mult(e.get("region", {}), r)
	return s / float(SeaEventData.REGIONS.size())


static func context(state: Dictionary, region: String, storm: bool, hour: float) -> Dictionary:
	var bounty: float = 0.0
	for v in state["bounty"].values():
		bounty = maxf(bounty, float(v))
	return {"region": region, "season": SeaEventData.season(int(state["day"])), "storm": storm,
		"night": hour >= 20.0 or hour < 5.0, "navy_rep": float(state["rep"].get("navy", 0.0)), "bounty": bounty}


static func _store(state: Dictionary) -> Dictionary:
	if not state.has("sea_events"):
		state["sea_events"] = {}
	var s: Dictionary = state["sea_events"]
	for k in ["acc", "pending", "plague_days", "spies", "counts"]:
		if not s.has(k):
			s[k] = {} if k in ["acc", "counts"] else ([] if k == "pending" else 0)
	return s


## One game hour. Returns the events that fire, in table order.
static func roll(state: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var store: Dictionary = _store(state)
	var acc: Dictionary = store["acc"]
	var out: Array[String] = []
	for id: String in SeaEventData.EVENTS.keys():
		if not acc.has(id):
			acc[id] = rng.randf()
		var p: float = chance(id, ctx)
		if p <= 0.0:
			continue
		acc[id] = float(acc[id]) + p
		if float(acc[id]) >= 1.0:
			acc[id] = float(acc[id]) - 1.0
			out.append(id)
			store["counts"][id] = int(store["counts"].get(id, 0)) + 1
	return out


## Carries out an event. Returns {"toast": key, "args": Array, "spawn": kind (spatial events only)}.
static func apply(id: String, state: Dictionary, rng: RandomNumberGenerator, ctx: Dictionary = {}) -> Dictionary:
	var e: Dictionary = SeaEventData.EVENTS[id]
	var store: Dictionary = _store(state)
	match id:
		"wreckage":
			var g: int = rng.randi_range(int(e["gold"][0]), int(e["gold"][1]))
			state["gold"] = int(state["gold"]) + g
			var frag: String = ""
			if rng.randf() < float(e["fragment"]):
				frag = MapFragments.next_missing(state)
				MapFragments.add(state, frag)
			return {"toast": "event.wreckage", "args": [g], "fragment": frag}
		"merchant_convoy", "navy_patrol", "ghost_ship":
			return {"toast": "event." + id, "args": [], "spawn": id}
		"monster":
			var kind: String = (e["kinds"] as Array)[rng.randi_range(0, (e["kinds"] as Array).size() - 1)]
			return {"toast": "event.monster", "args": [], "spawn": "monster", "kind": kind}
		"bottle":
			return _bottle(state, rng)
		"castaway":
			state["crew"] = int(state["crew"]) + 1
			var spy: bool = rng.randf() < float(e["spy"])
			if spy:
				store["spies"] = int(store["spies"]) + 1
			return {"toast": "event.castaway", "args": [], "spy": spy}
		"whale_pod":
			state["gold"] = int(state["gold"]) + int(e["gold"])
			for f: String in e["rep"]:
				state["rep"][f] = float(state["rep"].get(f, 0.0)) + float(e["rep"][f])
			return {"toast": "event.whale", "args": [int(e["gold"])]}
		"noble":
			var ransom: bool = float(state["rep"].get("pirate", 0.0)) > float(state["rep"].get("navy", 0.0))
			return noble(state, rng, ransom)
		"waterspout":
			return {"toast": "event.waterspout", "args": [], "sail_damage": float(e["sail_damage"])}
		"plague":
			if int(store["plague_days"]) <= 0:
				store["plague_days"] = int(e["days"])
			return {"toast": "event.plague", "args": []}
		"stowaway":
			if rng.randf() < float(e["thief_share"]):
				var stolen: int = floori(float(state["gold"]) * float(e["steal"]))
				state["gold"] = int(state["gold"]) - stolen
				return {"toast": "event.stowaway_thief", "args": [stolen], "thief": true}
			state["crew"] = int(state["crew"]) + 1
			state["morale"] = minf(100.0, float(state["morale"]) + 2.0)
			return {"toast": "event.stowaway_boy", "args": [], "thief": false}
	return {"toast": "", "args": []}


static func noble(state: Dictionary, rng: RandomNumberGenerator, ransom: bool) -> Dictionary:
	var e: Dictionary = SeaEventData.EVENTS["noble"]
	if ransom:
		var g: int = rng.randi_range(int(e["ransom"][0]), int(e["ransom"][1]))
		state["gold"] = int(state["gold"]) + g
		state["rep"]["navy"] = float(state["rep"].get("navy", 0.0)) - 10.0
		return {"toast": "event.noble_ransom", "args": [g]}
	state["rep"]["navy"] = float(state["rep"].get("navy", 0.0)) + float(e["rep_return"])
	return {"toast": "event.noble_return", "args": [int(e["rep_return"])]}


static func _bottle(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for w in SeaEventData.BOTTLE.values():
		total += int(w)
	var r: int = rng.randi_range(0, total - 1)
	var kind: String = "rumor"
	for k: String in SeaEventData.BOTTLE.keys():
		r -= int(SeaEventData.BOTTLE[k])
		if r < 0:
			kind = k
			break
	if kind == "clue":
		var frag: String = MapFragments.next_missing(state)
		if frag != "":
			MapFragments.add(state, frag)
		else:
			state["gold"] = int(state["gold"]) + SeaEventData.BOTTLE_GOLD_CLUE
	return {"toast": "event.bottle_" + kind, "args": [], "bottle": kind}


## Daily: the plague kills a few of the crew and sours morale unless a surgeon and a dose of medicine stop it.
static func plague_day(state: Dictionary) -> Dictionary:
	var store: Dictionary = _store(state)
	if int(store["plague_days"]) <= 0:
		return {"active": false}
	var e: Dictionary = SeaEventData.EVENTS["plague"]
	var surgeon: bool = (state["officers"] as Array).has("surgeon") or (state["roster"] as Array).has("surgeon")
	if surgeon and float(state["supplies"].get("medicine", 0.0)) >= 1.0:
		state["supplies"]["medicine"] = float(state["supplies"]["medicine"]) - 1.0
		store["plague_days"] = 0
		return {"active": false, "cured": true}
	var lost: int = CrewLife.remove_crew(state, maxi(1, ceili(float(state["crew"]) * float(e["crew_loss"]))))
	state["morale"] = maxf(0.0, float(state["morale"]) + float(e["morale"]))
	store["plague_days"] = int(store["plague_days"]) - 1
	return {"active": true, "lost": lost}


