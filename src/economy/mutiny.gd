class_name Mutiny
extends RefCounted
## The three ways out of a mutiny: pay them off, duel the ringleader, or maroon the mutineers.

enum Option { PAY_OFF, DUEL, MAROON }

const PAY_PER_CREW: int = 100  ## same as CrewManager.pay_off_mutiny
const PAY_OFF_MORALE: float = 30.0
const DUEL_BASE_WIN: float = 0.45
const DUEL_WIN_PER_LEVEL: float = 0.02
const DUEL_WEAPON_BONUS: float = 0.15  ## any weapon better than the rusty cutlass
const DUEL_WIN_MORALE: float = 40.0
const DUEL_LOSS_GOLD_FRACTION: float = 0.5
const DUEL_LOSS_MORALE: float = 25.0
const MAROON_CREW_FRACTION: float = 0.4
const MAROON_MORALE: float = 35.0


static func pay_off_cost(state: Dictionary) -> int:
	return PAY_PER_CREW * int(state["crew"])


static func duel_win_chance(state: Dictionary) -> float:
	var bonus: float = DUEL_WEAPON_BONUS if state["melee"] != "rusty_cutlass" else 0.0
	return clampf(DUEL_BASE_WIN + DUEL_WIN_PER_LEVEL * float(state.get("captain_level", 1)) + bonus + CrewPersona.duel_bonus(state), 0.05, 0.95)


## Resolve one option. Returns {ok, text_key}. `rng` makes the duel repeatable.
static func resolve(option: Option, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	match option:
		Option.PAY_OFF:
			var cost: int = pay_off_cost(state)
			if cost > int(state["gold"]):
				return {"ok": false, "text_key": "mutiny.cannot_pay"}
			state["gold"] = int(state["gold"]) - cost
			CrewLife.add_morale(state, PAY_OFF_MORALE)
			return {"ok": true, "text_key": "mutiny.paid"}
		Option.DUEL:
			if rng.randf() < duel_win_chance(state):
				state["morale"] = DUEL_WIN_MORALE
				return {"ok": true, "text_key": "mutiny.duel_won"}
			state["gold"] = floori(int(state["gold"]) * (1.0 - DUEL_LOSS_GOLD_FRACTION))
			state["morale"] = DUEL_LOSS_MORALE
			return {"ok": false, "text_key": "mutiny.duel_lost"}
		Option.MAROON:
			var n: int = ceili(float(state["crew"]) * MAROON_CREW_FRACTION)
			CrewPersona.remove_least_loyal(state, n)  # the mutineers are the least loyal men
			state["morale"] = MAROON_MORALE
			return {"ok": true, "text_key": "mutiny.marooned"}
	return {"ok": false, "text_key": ""}
