class_name PirateCrews
extends RefCounted
## What the rival pirate crews own and do, kept in state["crews"]: ships, gold, renown, how much of each region they
## hold, their grudge against the player, the islands they have claimed and the news of what they did. The daily
## tick runs their raids, claims, expansion and clashes; the live world (CrewDirector) puts their ships on the sea.

const ACTIONS: Array[String] = ["raid_trade", "raid_port", "claim_island", "expand", "hunt"]


static func root(state: Dictionary) -> Dictionary:
	if not state.has("crews") or typeof(state["crews"]) != TYPE_DICTIONARY:
		state["crews"] = {}
	var r: Dictionary = state["crews"]
	for k: String in ["claims", "news", "threats", "maps"]:
		if not r.has(k):
			r[k] = {} if k in ["claims", "maps"] else []
	if not r.has("player_renown"):
		r["player_renown"] = 0
	if not r.has("king"):
		r["king"] = false
	for id: String in CrewData.ORDER:
		if not r.has(id):
			r[id] = _fresh(id)
	return r


static func _fresh(id: String) -> Dictionary:
	var d: Dictionary = CrewData.def(id)
	var home: String = d["home"]
	var inf: Dictionary = {home: CrewData.START_INFLUENCE_HOME}
	for n: String in CrewData.NEIGHBOURS[home]:
		inf[n] = CrewData.START_INFLUENCE_NEAR
	return {"fleet": int(d["fleet"]), "gold": int(d["gold"]), "renown": int(d["renown"]), "influence": inf, "grudge": 10.0,
		"eliminated": false, "lagoon_known": false, "beaten": 0, "wins": 0, "raids": 0}


static func get_crew(state: Dictionary, id: String) -> Dictionary:
	return root(state)[id]


static func is_alive(state: Dictionary, id: String) -> bool:
	return not bool(get_crew(state, id)["eliminated"])


static func alive_ids(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in CrewData.ORDER:
		if is_alive(state, id):
			out.append(id)
	return out


static func influence(state: Dictionary, id: String, region: String) -> float:
	return float((get_crew(state, id)["influence"] as Dictionary).get(region, 0.0))


## The crew that holds most of a region, or "" when nobody holds more than a fifth of it.
static func owner_of(state: Dictionary, region: String) -> String:
	var best: String = ""
	var best_v: float = 20.0
	for id in alive_ids(state):
		var v: float = influence(state, id, region)
		if v > best_v:
			best_v = v
			best = id
	return best


## The pirate league: every crew and the player, best renown first. [{id, score}]; the player's id is "player".
static func league(state: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"id": "player", "score": int(root(state)["player_renown"])}]
	for id in alive_ids(state):
		rows.append({"id": id, "score": int(get_crew(state, id)["renown"])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return rows


static func player_rank(state: Dictionary) -> int:
	var rows: Array[Dictionary] = league(state)
	for i in rows.size():
		if rows[i]["id"] == "player":
			return i + 1
	return rows.size()


## Ship class a crew sends out: better ships as its renown grows.
static func ship_class(state: Dictionary, id: String, index: int = 0) -> String:
	var ships: Array = CrewData.def(id)["ships"]
	var tier: int = clampi(int(get_crew(state, id)["renown"]) / 60, 0, ships.size() - 1)
	return str(ships[clampi(tier - (index % 2), 0, ships.size() - 1)])


static func _news(state: Dictionary, key: String, args: Array) -> Dictionary:
	var n: Dictionary = {"day": int(state.get("day", 0)), "key": key, "args": args}
	var list: Array = root(state)["news"]
	list.append(n)
	while list.size() > CrewData.NEWS_KEEP:
		list.pop_front()
	return n


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for k in weights:
		total += int(weights[k])
	var roll: int = rng.randi_range(1, maxi(total, 1))
	for k: String in weights:
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return str(weights.keys()[0])


static func _strongest_region(state: Dictionary, id: String) -> String:
	var best: String = CrewData.def(id)["home"]
	var best_v: float = -1.0
	for reg: String in get_crew(state, id)["influence"]:
		var v: float = influence(state, id, reg)
		if v > best_v:
			best_v = v
			best = reg
	return best


# ---- the daily tick ---------------------------------------------------------------------------------

## One day for every crew: income, new ships, one action each, then clashes where two crews share a region.
## Returns the news made today ([{day, key, args}]).
static func day_tick(state: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for id in alive_ids(state):
		var c: Dictionary = get_crew(state, id)
		c["grudge"] = maxf(0.0, float(c["grudge"]) - CrewData.GRUDGE_DECAY_PER_DAY)
		c["gold"] = int(c["gold"]) + int(c["fleet"]) * CrewData.INCOME_PER_SHIP
		if int(c["fleet"]) < CrewData.FLEET_MAX and int(c["gold"]) >= CrewData.SHIP_COST + 500:
			c["gold"] = int(c["gold"]) - CrewData.SHIP_COST
			c["fleet"] = int(c["fleet"]) + 1
		var action: String = _pick(CrewData.STYLE_ACTIONS[CrewData.def(id)["style"]], rng)
		var n: Dictionary = act(state, id, action, rng)
		if not n.is_empty():
			made.append(n)
	var clash: Dictionary = _clash(state, rng)
	if not clash.is_empty():
		made.append(clash)
	_check_king(state, made)
	return made


## One crew action. Public so tests can pick it. Returns the news it made (may be empty).
static func act(state: Dictionary, id: String, action: String, rng: RandomNumberGenerator) -> Dictionary:
	var c: Dictionary = get_crew(state, id)
	var name: String = CrewData.def(id)["name"]
	match action:
		"raid_trade":
			var region: String = _strongest_region(state, id)
			var gold: int = rng.randi_range(CrewData.RAID_TRADE_GOLD[0], CrewData.RAID_TRADE_GOLD[1])
			for cv: Dictionary in state.get("convoys", []):
				if int(cv.get("status", 0)) == TradeNetwork.Status.SAILING:
					TradeNetwork.lose_ships(state, int(cv["id"]), 1)
					break
			c["gold"] = int(c["gold"]) + gold
			c["renown"] = int(c["renown"]) + CrewData.RAID_RENOWN
			c["raids"] = int(c["raids"]) + 1
			return _news(state, "pcrew.news.raid_trade", [name, region])
		"raid_port":
			var holding: Dictionary = _target_holding(state, id)
			if not holding.is_empty():
				return threaten_holding(state, id, holding)
			var port: String = _target_port(state, id, rng)
			if port == "":
				return {}
			if state.has("port_damage"):
				Blockade.building_destroyed(state, port)
			c["gold"] = int(c["gold"]) + rng.randi_range(CrewData.RAID_PORT_GOLD[0], CrewData.RAID_PORT_GOLD[1])
			c["renown"] = int(c["renown"]) + CrewData.RAID_RENOWN
			c["raids"] = int(c["raids"]) + 1
			return _news(state, "pcrew.news.raid_port", [name, port])
		"claim_island":
			var isl: String = _free_island(state, id, rng)
			if isl == "":
				return act(state, id, "expand", rng)
			var stash: int = rng.randi_range(CrewData.CLAIM_STASH[0], CrewData.CLAIM_STASH[1])
			root(state)["claims"][isl] = {"crew": id, "stash": stash}
			c["gold"] = maxi(0, int(c["gold"]) - stash / 2)
			c["renown"] = int(c["renown"]) + 2
			return _news(state, "pcrew.news.claim", [name, isl])
		"expand":
			var from: Array = (c["influence"] as Dictionary).keys()
			var reg: String = from[rng.randi() % from.size()]
			var options: Array = CrewData.NEIGHBOURS[reg].duplicate()
			options.append(reg)
			var to: String = options[rng.randi() % options.size()]
			c["influence"][to] = minf(CrewData.INFLUENCE_MAX, influence(state, id, to) + CrewData.EXPAND_GAIN)
			return _news(state, "pcrew.news.expand", [name, to])
		"hunt":
			c["grudge"] = minf(CrewData.GRUDGE_MAX, float(c["grudge"]) + CrewData.GRUDGE_HUNT)
			return _news(state, "pcrew.news.hunt", [name])
	return {}


## A crew with a grudge goes for the player's own lagoon or base when the player has one.
static func _target_holding(state: Dictionary, id: String) -> Dictionary:
	if float(get_crew(state, id)["grudge"]) < 30.0:
		return {}
	for t: Dictionary in root(state)["threats"]:
		if t["crew"] == id:
			return {}
	var hs: Array[Dictionary] = holdings(state)
	return hs[0] if not hs.is_empty() else {}


## The player's own places a crew can raid: the pirate lagoon (state["lagoon"]) and any base with a position.
## Each is {id, name, pos: Vector2}. Other systems own the data; this only reads it.
static func holdings(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lag: Variant = state.get("lagoon", null)
	if lag is Dictionary and (lag as Dictionary).has("pos"):
		out.append({"id": "lagoon", "name": str(lag.get("name", "Lagoon")), "pos": _vec(lag["pos"])})
	for i in (state.get("bases", []) as Array).size():
		var b: Variant = state["bases"][i]
		if b is Dictionary and (b as Dictionary).has("pos"):
			out.append({"id": "base_%d" % i, "name": str(b.get("name", "Base")), "pos": _vec(b["pos"])})
	return out


static func _vec(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Raiders set sail for the player's holding: they arrive in HOLDING_RAID_HOURS unless the player gets there first
## and sinks or takes them.
static func threaten_holding(state: Dictionary, id: String, holding: Dictionary) -> Dictionary:
	var now_h: float = float(state.get("day", 0)) * 24.0 + float(state.get("hour", 0.0))
	var p: Vector2 = holding["pos"]
	(root(state)["threats"] as Array).append({"crew": id, "holding": holding["id"], "name": holding["name"], "pos": [p.x, p.y], "due_h": now_h + CrewData.HOLDING_RAID_HOURS})
	return _news(state, "pcrew.news.threat", [CrewData.def(id)["name"], holding["name"]])


## Raids whose time has come take their share of what the holding stores. Returns the news.
static func resolve_threats(state: Dictionary, now_h: float) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	var keep: Array = []
	for t: Dictionary in root(state)["threats"]:
		if float(t["due_h"]) > now_h:
			keep.append(t)
			continue
		if not is_alive(state, str(t["crew"])):
			continue
		var taken: int = _raid_holding(state, str(t["holding"]))
		var c: Dictionary = get_crew(state, str(t["crew"]))
		c["gold"] = int(c["gold"]) + taken
		c["renown"] = int(c["renown"]) + CrewData.RAID_RENOWN * 2
		made.append(_news(state, "pcrew.news.raided_you", [CrewData.def(str(t["crew"]))["name"], t["name"], taken]))
	root(state)["threats"] = keep
	return made


## Takes HOLDING_RAID_FRACTION of the gold a holding stores, or of the player's purse when it stores none.
static func _raid_holding(state: Dictionary, holding_id: String) -> int:
	var store: Dictionary = {}
	if holding_id == "lagoon" and state.get("lagoon", null) is Dictionary:
		store = state["lagoon"]
	elif holding_id.begins_with("base_"):
		var i: int = int(holding_id.substr(5))
		if i < (state.get("bases", []) as Array).size() and state["bases"][i] is Dictionary:
			store = state["bases"][i]
	for key: String in ["gold", "gold_stored", "stash"]:
		if store.has(key):
			var t: int = int(float(store[key]) * CrewData.HOLDING_RAID_FRACTION)
			store[key] = float(store[key]) - t if store[key] is float else int(store[key]) - t
			return t
	var take: int = mini(int(float(state["gold"]) * CrewData.HOLDING_RAID_FRACTION), CrewData.PLUNDER_GOLD_CAP)
	state["gold"] = int(state["gold"]) - take
	return take


## The player beat the raiders sailing for a holding: that raid is off.
static func cancel_threats(state: Dictionary, id: String) -> void:
	var keep: Array = []
	for t: Dictionary in root(state)["threats"]:
		if t["crew"] != id:
			keep.append(t)
	root(state)["threats"] = keep


static func _target_port(state: Dictionary, id: String, rng: RandomNumberGenerator) -> String:
	var options: Array[String] = []
	for pid: String in PortData.PORTS:
		if pid == PortData.START_PORT:
			continue
		var reg: String = WorldMap.region_at(PortData.PORTS[pid]["dock"])
		if influence(state, id, reg) >= 30.0:
			options.append(pid)
	options.sort()
	return options[rng.randi() % options.size()] if not options.is_empty() else ""


## An island with no town, in a region the crew holds, not claimed yet. The crew holds at most CLAIMS_PER_CREW.
static func _free_island(state: Dictionary, id: String, rng: RandomNumberGenerator) -> String:
	var claims: Dictionary = root(state)["claims"]
	var mine: int = 0
	for k in claims:
		if claims[k]["crew"] == id:
			mine += 1
	if mine >= CrewData.CLAIMS_PER_CREW:
		return ""
	var options: Array[String] = []
	for isl: Dictionary in PortData.gen().islands:
		if str(isl["city"]) != "" or claims.has(isl["name"]):
			continue
		if influence(state, id, str(isl["region"])) >= 20.0:
			options.append(str(isl["name"]))
	options.sort()
	return options[rng.randi() % options.size()] if not options.is_empty() else ""


## Two crews strong in the same region fight over it: the weaker may lose a ship and some of its hold there.
static func _clash(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array[String] = alive_ids(state)
	for reg: String in WorldMap.REGIONS:
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				if influence(state, a, reg) < 40.0 or influence(state, b, reg) < 40.0:
					continue
				if rng.randf() >= CrewData.CLASH_LOSS_CHANCE:
					continue
				var pa: float = float(get_crew(state, a)["fleet"]) * (1.0 + float(CrewData.def(a)["grit"]))
				var pb: float = float(get_crew(state, b)["fleet"]) * (1.0 + float(CrewData.def(b)["grit"]))
				var winner: String = a if pa + rng.randf_range(-2.0, 2.0) >= pb else b
				var loser: String = b if winner == a else a
				var lc: Dictionary = get_crew(state, loser)
				lc["fleet"] = maxi(1, int(lc["fleet"]) - 1)
				lc["influence"][reg] = maxf(0.0, influence(state, loser, reg) - CrewData.EXPAND_GAIN)
				get_crew(state, winner)["renown"] = int(get_crew(state, winner)["renown"]) + CrewData.RAID_RENOWN
				return _news(state, "pcrew.news.clash", [CrewData.def(winner)["name"], CrewData.def(loser)["name"], reg])
	return {}


static func _check_king(state: Dictionary, made: Array[Dictionary]) -> void:
	var r: Dictionary = root(state)
	if not bool(r["king"]) and player_rank(state) == 1 and int(r["player_renown"]) > 0:
		r["king"] = true
		made.append(_news(state, "pcrew.news.king", []))


# ---- the crews and the player ----------------------------------------------------------------------

## Chance per game hour that a crew sends a warband after the player in `region`.
static func warband_chance(state: Dictionary, id: String, region: String) -> float:
	if not is_alive(state, id) or int(get_crew(state, id)["fleet"]) <= 0:
		return 0.0
	var c: Dictionary = get_crew(state, id)
	var p: float = CrewData.WARBAND_CHANCE_PER_HOUR * influence(state, id, region) / CrewData.INFLUENCE_MAX
	p *= 1.0 + float(c["grudge"]) / CrewData.GRUDGE_MAX
	if CrewData.def(id)["style"] == "hunter":
		p *= CrewData.HUNTER_FACTOR
	return p


## How many ships a warband has: more with a bigger fleet and a bigger grudge, never more than the fleet.
static func warband_size(state: Dictionary, id: String) -> int:
	var c: Dictionary = get_crew(state, id)
	var n: int = 1
	if int(c["fleet"]) >= 6:
		n += 1
	if float(c["grudge"]) >= 60.0:
		n += 1
	return clampi(n, 1, mini(CrewData.WARBAND_MAX, int(c["fleet"])))


## The player sank or took one of a crew's ships in `region`. `flagship` at the lagoon ends the crew.
## Returns {eliminated, gold} (gold is the elimination reward, already paid).
static func ship_beaten(state: Dictionary, id: String, region: String, flagship: bool = false) -> Dictionary:
	var c: Dictionary = get_crew(state, id)
	var r: Dictionary = root(state)
	c["fleet"] = maxi(0, int(c["fleet"]) - 1)
	c["beaten"] = int(c["beaten"]) + 1
	c["grudge"] = minf(CrewData.GRUDGE_MAX, float(c["grudge"]) + CrewData.GRUDGE_PER_SHIP)
	c["renown"] = maxi(0, int(c["renown"]) - 3)
	c["lagoon_known"] = true  # a prisoner always talks
	if region != "":
		c["influence"][region] = maxf(0.0, influence(state, id, region) - CrewData.LOSS_INFLUENCE)
	r["player_renown"] = int(r["player_renown"]) + CrewData.WIN_RENOWN
	cancel_threats(state, id)
	if flagship:
		return eliminate(state, id)
	return {"eliminated": false, "gold": 0}


## The crew is finished: its chest and its maps go to the player, its claims and its hold on the sea are gone.
static func eliminate(state: Dictionary, id: String) -> Dictionary:
	var c: Dictionary = get_crew(state, id)
	if bool(c["eliminated"]):
		return {"eliminated": true, "gold": 0}
	var r: Dictionary = root(state)
	c["eliminated"] = true
	c["fleet"] = 0
	c["influence"] = {}
	var gold: int = int(c["gold"]) + CrewData.ELIMINATE_GOLD
	c["gold"] = 0
	state["gold"] = int(state["gold"]) + gold
	r["player_renown"] = int(r["player_renown"]) + CrewData.ELIMINATE_RENOWN
	for isl: String in (r["claims"] as Dictionary).keys():
		if r["claims"][isl]["crew"] == id:
			r["claims"].erase(isl)
	var maps: Array = (r["maps"] as Dictionary).get(id, [])
	for m: String in maps:
		if not (state["map_fragments"] as Array).has(m):
			state["map_fragments"].append(m)
	(r["maps"] as Dictionary).erase(id)
	cancel_threats(state, id)
	_news(state, "pcrew.news.eliminated", [CrewData.def(id)["name"]])
	return {"eliminated": true, "gold": gold, "maps": maps.size()}


## A crew beat the player (on deck or by sinking the ship): it takes a share of the purse and, if it hunts treasure,
## a map fragment. Returns {gold, fragment}.
static func beat_player(state: Dictionary, id: String) -> Dictionary:
	var c: Dictionary = get_crew(state, id)
	var take: int = mini(int(float(state["gold"]) * CrewData.PLUNDER_GOLD_FRACTION), CrewData.PLUNDER_GOLD_CAP)
	state["gold"] = int(state["gold"]) - take
	c["gold"] = int(c["gold"]) + take
	c["wins"] = int(c["wins"]) + 1
	c["renown"] = int(c["renown"]) + CrewData.WIN_RENOWN
	var frag: String = ""
	var have: Array = state["map_fragments"]
	if CrewData.def(id)["style"] == "treasure" and not have.is_empty():
		frag = str(have.pop_back())
		var maps: Dictionary = root(state)["maps"]
		if not maps.has(id):
			maps[id] = []
		(maps[id] as Array).append(frag)
	_news(state, "pcrew.news.beat_you", [CrewData.def(id)["name"], take])
	return {"gold": take, "fragment": frag}


## A map fragment a crew stole comes back from one of its ships, or "" when it holds none.
static func take_back_map(state: Dictionary, id: String) -> String:
	var maps: Dictionary = root(state)["maps"]
	if not maps.has(id) or (maps[id] as Array).is_empty():
		return ""
	var m: String = str((maps[id] as Array).pop_back())
	if not (state["map_fragments"] as Array).has(m):
		state["map_fragments"].append(m)
	return m


## The guards of a claimed island are beaten: its stash is the player's and the claim is gone.
static func take_claim(state: Dictionary, island: String) -> int:
	var claims: Dictionary = root(state)["claims"]
	if not claims.has(island):
		return 0
	var stash: int = int(claims[island]["stash"])
	claims.erase(island)
	state["gold"] = int(state["gold"]) + stash
	root(state)["player_renown"] = int(root(state)["player_renown"]) + CrewData.WIN_RENOWN
	return stash


## Text of one news line, in the current language.
static func news_text(n: Dictionary) -> String:
	var args: Array = []
	for a in n["args"]:
		if a is int or a is float:
			args.append(int(a))
			continue
		var s: String = str(a)
		if WorldMap.REGIONS.has(s):
			s = Loc.t("region." + s)
		elif PortData.PORTS.has(s):
			s = str(PortData.PORTS[s]["name"])
		args.append(s)
	var t: String = Loc.t(str(n["key"]))
	return t % args if not args.is_empty() else t
