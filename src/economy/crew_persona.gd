class_name CrewPersona
extends RefCounted
## Every named hand has a personality and his own loyalty to the captain (0 to 100). Loyalty drifts toward the
## ship's morale each day and moves with the things each personality cares about. Loyal men fight harder, stand by
## the captain in a mutiny and talk the others down; disloyal men slip away in port and lead the mutinies.
## Plain functions on the save-state dictionary, like CrewLife.

## Trait -> what it does. melee: blade damage on deck. nerve: how hard he presses (multiplies morale_effic).
## panics / rallies: deck-fight behaviour. The loyalty numbers are per day or per event.
const TRAITS: Dictionary = {
	"brave": {"melee": 1.15, "nerve": 1.05, "rallies": true, "boarding_win": 4.0},
	"steadfast": {"floor": 35.0, "drift_down": 0.5},
	"greedy": {"loot_mult": 2.0, "cut_high": -3.0, "cut_low": 2.0},
	"drunkard": {"rum": 2.0, "no_rum": -5.0},
	"superstitious": {"storm": -4.0, "omen_chance": 0.05, "omen": -6.0},
	"hothead": {"melee": 1.10, "defeat": -6.0, "brawl_below": 40.0, "brawl_chance": 0.10},
	"cheerful": {"ship_morale": 1.0},
	"coward": {"melee": 0.85, "panics": true, "defeat": -4.0, "desert_mult": 1.6},
}
const TRAIT_ORDER: PackedStringArray = ["brave", "steadfast", "greedy", "drunkard", "superstitious", "hothead", "cheerful", "coward"]

## Loyalty bands: name -> lowest loyalty in it.
const BANDS: Dictionary = {"devoted": 80.0, "loyal": 55.0, "wavering": 30.0, "disloyal": 0.0}
const BAND_ORDER: PackedStringArray = ["devoted", "loyal", "wavering", "disloyal"]

const START_LOYALTY: float = 50.0
const START_SPREAD: float = 10.0
const DRIFT: float = 0.15  ## share of the gap to the ship's morale closed each day
## Every hand, whatever his nature, on these events.
const EVENT: Dictionary = {"victory": 3.0, "boarding_win": 2.0, "defeat": -5.0, "loot_per_50_gold": 1.0, "level_up": 5.0, "parley": 2.0}
const LOOT_MAX: float = 10.0  ## one share-out can move a man's loyalty at most this much
const CHEER_MAX: float = 3.0  ## cheerful hands lift the ship's morale by at most this much a day
const BRAWL_MORALE: float = -3.0
const DESERT_BELOW: float = 20.0
const DESERT_CHANCE: float = 0.3  ## per disloyal man per day in port
## Fighting the deck: devoted men press harder, disloyal men hang back and break early.
const DEVOTED_NERVE: float = 1.08
const DISLOYAL_NERVE: float = 0.90
## Mutiny: each loyal man raises the captain's duel odds; when half the roster is devoted they talk it down.
const DUEL_PER_LOYAL: float = 0.02
const DUEL_LOYAL_MAX: float = 0.20
const TALK_DOWN_SHARE: float = 0.5
const TALK_DOWN_DAYS: int = 7


## Gives `m` a personality and starting loyalty if he has none. Deterministic from the seed and his name.
static func ensure(m: Dictionary, seed_value: int) -> void:
	if m.has("trait") and m.has("loyalty"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(m.get("name", "Hand"))) ^ (seed_value * 7907) ^ (hash(str(m.get("type", "green"))) * 31)
	if not m.has("trait"):
		m["trait"] = TRAIT_ORDER[rng.randi() % TRAIT_ORDER.size()]
	if not m.has("loyalty"):
		m["loyalty"] = clampf(START_LOYALTY + rng.randf_range(-START_SPREAD, START_SPREAD), 0.0, 100.0)


static func ensure_all(state: Dictionary) -> void:
	var seed_value: int = int(state.get("seed", 1))
	for i in state["roster"].size():
		ensure(state["roster"][i], seed_value + i * 13)


## The hand just signed on (the last on the roster) gets his personality.
static func ensure_last(state: Dictionary) -> void:
	if not state["roster"].is_empty():
		ensure(state["roster"].back(), int(state.get("seed", 1)) + (state["roster"].size() - 1) * 13)


## Hands without a personality (old test fixtures, enemy crews) take no part in any of the rules below.
static func has_persona(m: Dictionary) -> bool:
	return m.has("trait")


static func trait_of(m: Dictionary) -> String:
	return str(m.get("trait", ""))


static func loyalty(m: Dictionary) -> float:
	return float(m.get("loyalty", START_LOYALTY))


static func band(value: float) -> String:
	for b: String in BAND_ORDER:
		if value >= BANDS[b]:
			return b
	return "disloyal"


static func _t(m: Dictionary, key: String, fallback: Variant) -> Variant:
	return TRAITS.get(trait_of(m), {}).get(key, fallback)


static func add_loyalty(m: Dictionary, amount: float) -> void:
	var floor_value: float = float(_t(m, "floor", 0.0))
	var v: float = clampf(loyalty(m) + amount, 0.0, 100.0)
	if amount < 0.0:
		v = maxf(v, minf(floor_value, loyalty(m)))
	m["loyalty"] = v


## Something happened to the whole crew: "victory", "boarding_win", "defeat" or "parley". Each personality adds
## its own part on top of the common one.
static func on_event(state: Dictionary, kind: String) -> void:
	for m: Dictionary in state["roster"]:
		if has_persona(m):
			add_loyalty(m, float(EVENT.get(kind, 0.0)) + float(_t(m, kind, 0.0)))


## The crew's shares were paid out: `crew_share` gold over the whole crew. Greedy men count every coin twice.
static func on_loot(state: Dictionary, crew_share: float) -> void:
	if crew_share <= 0.0:
		return
	var base: float = EVENT["loot_per_50_gold"] * floorf(crew_share / 50.0)
	for m: Dictionary in state["roster"]:
		if has_persona(m):
			add_loyalty(m, minf(base * float(_t(m, "loot_mult", 1.0)), LOOT_MAX))


## Men gained levels: a man who is getting better at his trade on this ship warms to it.
static func on_level_up(m: Dictionary) -> void:
	add_loyalty(m, EVENT["level_up"])


## One day. `causes` is the morale cause dictionary CrewLife.daily_tick built (rum_ration, no_rum, storm_day, ...).
## Loyalty drifts toward the morale the ship ended the day on. Returns {morale_delta, events: [{key, name}],
## deserted: [names]}; the caller applies morale_delta to the ship's morale and removes the deserters.
static func daily(state: Dictionary, causes: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"morale_delta": 0.0, "events": [], "deserted": []}
	var morale: float = float(state["morale"])
	var cut: float = float(state.get("captain_cut", Morale.CUT_DEFAULT))
	var cheer: float = 0.0
	for m: Dictionary in state["roster"]:
		if not has_persona(m):
			continue
		var tr: String = trait_of(m)
		var gap: float = morale - loyalty(m)
		var drift: float = gap * DRIFT
		if drift < 0.0:
			drift *= float(_t(m, "drift_down", 1.0))
		var d: float = drift
		match tr:
			"drunkard":
				d += float(TRAITS[tr]["rum"]) if bool(causes.get("rum_ration", false)) else float(TRAITS[tr]["no_rum"])
				if not bool(causes.get("rum_ration", false)) and out["events"].size() < 2 and rng.randf() < 0.3:
					out["events"].append({"key": "persona.ev_dry", "name": m["name"]})
			"greedy":
				if cut > Morale.CUT_HIGH_ABOVE:
					d += float(TRAITS[tr]["cut_high"])
				elif cut < Morale.CUT_LOW_BELOW:
					d += float(TRAITS[tr]["cut_low"])
			"superstitious":
				if bool(causes.get("storm_day", false)):
					d += float(TRAITS[tr]["storm"])
				if rng.randf() < float(TRAITS[tr]["omen_chance"]):
					d += float(TRAITS[tr]["omen"])
					if out["events"].size() < 2:
						out["events"].append({"key": "persona.ev_omen", "name": m["name"]})
			"hothead":
				if morale < float(TRAITS[tr]["brawl_below"]) and rng.randf() < float(TRAITS[tr]["brawl_chance"]):
					out["morale_delta"] = float(out["morale_delta"]) + BRAWL_MORALE
					if out["events"].size() < 2:
						out["events"].append({"key": "persona.ev_brawl", "name": m["name"]})
			"cheerful":
				if cheer < CHEER_MAX:
					cheer += float(TRAITS[tr]["ship_morale"])
		add_loyalty(m, d)
	out["morale_delta"] = float(out["morale_delta"]) + cheer
	if cheer > 0.0 and out["events"].size() < 2 and rng.randf() < 0.25:
		for m: Dictionary in state["roster"]:
			if trait_of(m) == "cheerful":
				out["events"].append({"key": "persona.ev_cheer", "name": m["name"]})
				break
	if bool(ctx.get("in_port", false)):
		out["deserted"] = _desert(state, rng)
	return out


## In port the disloyal men may walk off. Removes them from the roster and the crew count; returns their names.
static func _desert(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var names: Array = []
	var i: int = state["roster"].size() - 1
	while i >= 0:
		var m: Dictionary = state["roster"][i]
		if has_persona(m) and loyalty(m) < DESERT_BELOW and rng.randf() < DESERT_CHANCE * float(_t(m, "desert_mult", 1.0)):
			names.append(str(m["name"]))
			state["roster"].remove_at(i)
			state["crew"] = maxi(int(state["crew"]) - 1, 0)
		i -= 1
	return names


## Deck-fight modifiers for one hand: {melee_mult, nerve, panics, rallies}.
static func fight_mods(m: Dictionary) -> Dictionary:
	var nerve: float = float(_t(m, "nerve", 1.0))
	var panics: bool = bool(_t(m, "panics", false))
	match band(loyalty(m)):
		"devoted":
			nerve *= DEVOTED_NERVE
		"disloyal":
			nerve *= DISLOYAL_NERVE
			panics = true
	return {"melee_mult": float(_t(m, "melee", 1.0)), "nerve": nerve, "panics": panics, "rallies": bool(_t(m, "rallies", false))}


static func count_at_least(state: Dictionary, value: float) -> int:
	var n: int = 0
	for m: Dictionary in state["roster"]:
		if has_persona(m) and loyalty(m) >= value:
			n += 1
	return n


## Extra chance for the captain in a mutiny duel: the loyal men are at his back.
static func duel_bonus(state: Dictionary) -> float:
	return minf(DUEL_PER_LOYAL * float(count_at_least(state, BANDS["loyal"])), DUEL_LOYAL_MAX)


## Half the roster devoted: they talk the crew out of a mutiny (once every TALK_DOWN_DAYS).
static func talks_down(state: Dictionary) -> bool:
	var n: int = 0
	for m: Dictionary in state["roster"]:
		if has_persona(m):
			n += 1
	return n > 0 and float(count_at_least(state, BANDS["devoted"])) >= float(n) * TALK_DOWN_SHARE


## The man most likely to lead a mutiny: the least loyal hand. "" with an empty roster.
static func ringleader(state: Dictionary) -> String:
	var worst: Dictionary = {}
	for m: Dictionary in state["roster"]:
		if has_persona(m) and (worst.is_empty() or loyalty(m) < loyalty(worst)):
			worst = m
	return str(worst.get("name", ""))


## Take `n` men off, least loyal first (marooning the mutineers). Keeps `crew` in step. Returns how many went.
static func remove_least_loyal(state: Dictionary, n: int) -> int:
	var removed: int = 0
	while removed < n and int(state["crew"]) > 0:
		var worst: int = -1
		for i in state["roster"].size():
			if worst < 0 or loyalty(state["roster"][i]) < loyalty(state["roster"][worst]):
				worst = i
		if worst >= 0:
			state["roster"].remove_at(worst)
		state["crew"] = int(state["crew"]) - 1
		removed += 1
	return removed

