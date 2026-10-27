class_name CaptureFate
extends RefCounted
## What the player does with a captured ship. Pure data/maths so the numbers are testable.

enum Fate { CAPTURE, SELL, STRIP_AND_SINK, RELEASE, RANSOM, PRESS_CREW }

const SELL_FRACTION: float = 0.5
const STRIP_EQUIPMENT_FRACTION: float = 0.3
const RANSOM_FRACTION: float = 0.2
const RANSOM_RESCUE_CHANCE: float = 0.2
const PRESS_JOIN_FRACTION: float = 0.25
const PRESS_LOYALTY_DELTA: float = -10.0
const RELEASE_REPUTATION: float = 5.0
const RELEASE_MORALE: float = 10.0
const STRIP_NOTORIETY: float = 5.0
const RANSOM_REPUTATION: float = -2.0
const SINK_REPUTATION: float = -4.0


## `info`: {ship_value, cargo_value, equipment_value, survivors, prize_crew_available, kindly_crew}
## Returns a dictionary of effects: gold, reputation (with the victim's faction), notoriety, morale, loyalty,
## recruits, ship_added, rescue_fleet.
static func resolve(fate: Fate, info: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"gold": 0.0, "reputation": 0.0, "notoriety": 0.0, "morale": 0.0, "loyalty": 0.0,
		"recruits": 0, "ship_added": false, "rescue_fleet": false, "ok": true}
	var ship_value: float = info.get("ship_value", 0.0)
	match fate:
		Fate.CAPTURE:
			if info.get("prize_crew_available", 0) < 1:
				out["ok"] = false
				return out
			out["ship_added"] = true
			out["gold"] = info.get("cargo_value", 0.0)
		Fate.SELL:
			out["gold"] = ship_value * SELL_FRACTION + info.get("cargo_value", 0.0)
		Fate.STRIP_AND_SINK:
			out["gold"] = info.get("cargo_value", 0.0) + info.get("equipment_value", 0.0) * STRIP_EQUIPMENT_FRACTION
			out["notoriety"] = STRIP_NOTORIETY
			out["reputation"] = SINK_REPUTATION
		Fate.RELEASE:
			out["reputation"] = RELEASE_REPUTATION
			if info.get("kindly_crew", false):
				out["morale"] = RELEASE_MORALE
		Fate.RANSOM:
			out["gold"] = ship_value * RANSOM_FRACTION
			out["reputation"] = RANSOM_REPUTATION
			out["rescue_fleet"] = rng.randf() < RANSOM_RESCUE_CHANCE
		Fate.PRESS_CREW:
			out["recruits"] = int(floor(info.get("survivors", 0) * PRESS_JOIN_FRACTION))
			out["loyalty"] = PRESS_LOYALTY_DELTA
	return out
