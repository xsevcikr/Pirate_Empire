class_name Bounty
extends RefCounted
## The price on the captain's head and the name the captain has made. Every lawful flag the player attacks, sinks,
## loots or burns puts gold on the player's head with that faction (state["bounty"], 0..500). The biggest bounty
## gives the wanted stars; stars send bounty hunters after the ship and make harbour inspections likelier, four stars
## close that faction's lawful ports. A bounty fades after a quiet day and can be pardoned by the faction's governor
## or bribed away at a pirate haven. The other way round, the navy pays for every pirate taken, and the wanted
## posters pay for the rival crews' ships. Infamy (state["fame"]) is the pirate reputation: it climbs with every
## prize and raid, its ranks open the big ships and make merchants strike their colours sooner.

const FACTIONS: Array[String] = ["navy", "merchant", "reef_folk", "iron_dominion"]  ## pirates post no bounties
const MAX: float = 500.0
const CRIME: Dictionary = {"attack": 10.0, "sink": 15.0, "capture": 20.0, "raze": 25.0}
const FAME: Dictionary = {"sink": 2, "raze": 3, "pirate_taken": 1, "poster": 5}
const QUIET_DAYS: int = 1            ## a bounty starts to fade only after this many days without a crime
const DECAY_PER_DAY: float = 6.0
const PARDON_GOLD_PER_POINT: int = 40
const BRIBE_GOLD_PER_POINT: int = 70  ## at a pirate haven, for any flag, half the bounty at a time
const BRIBE_SHARE: float = 0.5
const CLOSED_STARS: int = 4           ## the faction's lawful ports turn the ship away from here

## The navy's reward for a pirate ship, by the share of its price, and the floor and ceiling of it.
const PIRATE_REWARD_SHARE: float = 0.06
const PIRATE_REWARD_RANGE: Vector2i = Vector2i(60, 900)
## A rival crew's poster pays this much per point of the crew's renown for each of its ships taken or sunk.
const POSTER_GOLD_PER_RENOWN: int = 6

## Hunters: [stars, hunters per wave, hours between waves].
const HUNTERS: Array = [[1, 1, 30.0], [2, 2, 20.0], [3, 2, 12.0], [4, 3, 8.0], [5, 3, 6.0]]
const HUNTER_CLASSES: Array = [["cutter", "sloop"], ["sloop", "brigantine"], ["brigantine", "frigate"], ["frigate", "corvette"], ["frigate", "man_o_war"]]
const HUNTER_SHIP_FACTION: Dictionary = {"navy": "navy", "merchant": "navy", "reef_folk": "navy", "iron_dominion": "iron"}

## Infamy ranks: [fame needed, id]. Each rank above the first makes merchants surrender a little sooner.
const RANKS: Array = [[0, "nobody"], [40, "cutthroat"], [120, "buccaneer"], [300, "sea_wolf"], [600, "dread_pirate"], [1000, "pirate_lord"]]
const FEAR_PER_RANK: float = 0.03
## A haven's tavern knocks this much off a hand's hire price for each rank.
const HAVEN_HIRE_DISCOUNT_PER_RANK: float = 0.04


static func value(state: Dictionary, faction: String) -> float:
	return float(state["bounty"].get(faction, 0.0))


static func set_value(state: Dictionary, faction: String, v: float) -> void:
	state["bounty"][faction] = clampf(v, 0.0, MAX)


static func top_faction(state: Dictionary) -> String:
	var best: String = ""
	var best_v: float = 0.0
	for f: String in FACTIONS:
		if value(state, f) > best_v:
			best_v = value(state, f)
			best = f
	return best


static func stars_for(v: float) -> int:
	var s: int = int(Reputation.hunter_response(v)["stars"])
	return 5 if v >= MAX else s


static func stars(state: Dictionary) -> int:
	var f: String = top_faction(state)
	return stars_for(value(state, f)) if f != "" else 0


## A crime against `faction`: "attack", "sink", "capture" or "raze". Returns the stars it moved from and to.
static func crime(state: Dictionary, faction: String, kind: String) -> Vector2i:
	if not FACTIONS.has(faction) or not CRIME.has(kind):
		return Vector2i(stars(state), stars(state))
	var before: int = stars(state)
	var marque: String = str(state.get("marque", ""))
	if marque != "" and marque == faction:  # a letter of marque makes it lawful war
		return Vector2i(before, before)
	set_value(state, faction, value(state, faction) + float(CRIME[kind]))
	state["bounty_crime_day"] = int(state["day"])
	if FAME.has(kind):
		state["fame"] = int(state["fame"]) + int(FAME[kind])
	return Vector2i(before, stars(state))


## Tells the player when a crime raised the stars.
static func announce(moved: Vector2i, faction: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus == null or moved.y <= moved.x:
		return
	bus.toast.emit(Loc.t("bounty.stars_up") % [moved.y, Loc.t("faction." + faction)])
	if moved.y >= CLOSED_STARS and moved.x < CLOSED_STARS:
		bus.toast.emit(Loc.t("bounty.ports_closed") % Loc.t("faction." + faction))


## A pirate ship taken or sunk: the navy owes a reward, payable at any lawful port. Returns the gold owed for it.
static func pirate_taken(state: Dictionary, price: int, crew_id: String = "") -> int:
	var gold: int = clampi(roundi(float(price) * PIRATE_REWARD_SHARE), PIRATE_REWARD_RANGE.x, PIRATE_REWARD_RANGE.y)
	if crew_id != "" and state.get("crews", {}).has(crew_id):
		gold += POSTER_GOLD_PER_RENOWN * int(state["crews"][crew_id].get("renown", 0))
		state["fame"] = int(state["fame"]) + int(FAME["poster"])
	state["fame"] = int(state["fame"]) + int(FAME["pirate_taken"])
	state["bounty_claims"] = int(state.get("bounty_claims", 0)) + gold
	return gold


## What one of a rival crew's ships is worth on its poster.
static func poster_reward(state: Dictionary, crew_id: String) -> int:
	return POSTER_GOLD_PER_RENOWN * int(PirateCrews.get_crew(state, crew_id).get("renown", 0))


## The posters on the board: every rival crew still sailing, richest first. [{crew, reward}]
static func posters(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in PirateCrews.alive_ids(state):
		out.append({"crew": id, "reward": poster_reward(state, id)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["reward"]) > int(b["reward"]))
	return out


static func can_collect(state: Dictionary, port_id: String) -> bool:
	return int(state.get("bounty_claims", 0)) > 0 and bool(PortData.PORTS[port_id]["lawful"])


## Pays out the navy's rewards. Returns the gold paid.
static func collect(state: Dictionary, port_id: String) -> int:
	if not can_collect(state, port_id):
		return 0
	var gold: int = int(state["bounty_claims"])
	state["gold"] = int(state["gold"]) + gold
	state["bounty_claims"] = 0
	return gold


## The governor's price to clear the bounty of the port's own flag, or -1 when he will not deal.
static func pardon_cost(state: Dictionary, port_id: String) -> int:
	var port: Dictionary = PortData.PORTS[port_id]
	var f: String = port["faction"]
	if not bool(port["lawful"]) or value(state, f) <= 0.0 or Reputation.tier(float(state["rep"].get(f, 0.0))) in ["hated", "hostile"]:
		return -1
	return ceili(value(state, f)) * PARDON_GOLD_PER_POINT


static func pardon(state: Dictionary, port_id: String) -> bool:
	var cost: int = pardon_cost(state, port_id)
	if cost < 0 or cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	set_value(state, PortData.PORTS[port_id]["faction"], 0.0)
	return true


## A haven's clerk will lose half of any flag's papers, for a price. -1 when there is nothing to lose or no clerk.
static func bribe_cost(state: Dictionary, port_id: String, faction: String) -> int:
	if bool(PortData.PORTS[port_id]["lawful"]) or value(state, faction) <= 0.0:
		return -1
	return ceili(value(state, faction) * BRIBE_SHARE) * BRIBE_GOLD_PER_POINT


static func bribe(state: Dictionary, port_id: String, faction: String) -> bool:
	var cost: int = bribe_cost(state, port_id, faction)
	if cost < 0 or cost > int(state["gold"]):
		return false
	state["gold"] = int(state["gold"]) - cost
	set_value(state, faction, value(state, faction) - ceilf(value(state, faction) * BRIBE_SHARE))
	return true


## Whether a port lets the ship in: a lawful port shuts on four stars with its own flag.
static func port_open(state: Dictionary, port_id: String) -> bool:
	var port: Dictionary = PortData.PORTS[port_id]
	return not bool(port["lawful"]) or stars_for(value(state, port["faction"])) < CLOSED_STARS


## A new day: every bounty fades once the captain has kept quiet a full day.
static func day_tick(state: Dictionary) -> void:
	if int(state["day"]) - int(state.get("bounty_crime_day", -99)) <= QUIET_DAYS:
		return
	for f: String in FACTIONS:
		if value(state, f) > 0.0:
			set_value(state, f, value(state, f) - DECAY_PER_DAY)


## Who comes hunting at these stars: {count, interval_h, classes}. Zero stars sends nobody.
static func hunters(star_count: int) -> Dictionary:
	if star_count <= 0:
		return {"count": 0, "interval_h": 0.0, "classes": []}
	var row: Array = HUNTERS[clampi(star_count, 1, HUNTERS.size()) - 1]
	return {"count": int(row[1]), "interval_h": float(row[2]), "classes": HUNTER_CLASSES[clampi(star_count, 1, HUNTERS.size()) - 1]}


## Whether a wave of hunters is due at `now_h`; schedules the next one when it is.
static func hunters_due(state: Dictionary, now_h: float) -> bool:
	var h: Dictionary = hunters(stars(state))
	if int(h["count"]) == 0:
		state["hunter_next_h"] = -1.0
		return false
	var next: float = float(state.get("hunter_next_h", -1.0))
	if next < 0.0:  # the first wave gives the captain a head start of one interval
		state["hunter_next_h"] = now_h + float(h["interval_h"])
		return false
	if now_h < next:
		return false
	state["hunter_next_h"] = now_h + float(h["interval_h"])
	return true


# ---- infamy ------------------------------------------------------------------------------------------------

static func rank_index(fame: int) -> int:
	var idx: int = 0
	for i in RANKS.size():
		if fame >= int(RANKS[i][0]):
			idx = i
	return idx


static func rank_id(fame: int) -> String:
	return str(RANKS[rank_index(fame)][1])


## Fame still needed for the next rank (0 at the top).
static func to_next_rank(fame: int) -> int:
	var i: int = rank_index(fame)
	return 0 if i + 1 >= RANKS.size() else int(RANKS[i + 1][0]) - fame


## How much sooner a merchant strikes when the player comes for it (added to its surrender threshold).
static func fear(state: Dictionary) -> float:
	return FEAR_PER_RANK * float(rank_index(int(state.get("fame", 0))))


static func hire_mult(state: Dictionary, port_id: String) -> float:
	if bool(PortData.PORTS[port_id]["lawful"]):
		return 1.0
	return 1.0 - HAVEN_HIRE_DISCOUNT_PER_RANK * float(rank_index(int(state.get("fame", 0))))
