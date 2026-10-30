class_name CaptainHealth
extends RefCounted
## The captain's own hit points between fights, kept in state["captain_hp"]: they carry from one fight to the next,
## come back slowly while he is not fighting, and a pull of rum gives 50 at once.

static func hp(state: Dictionary) -> float:
	return clampf(float(state.get("captain_hp", DeckData.FIGHTER_HP)), 1.0, DeckData.FIGHTER_HP)


static func rum_supply(state: Dictionary) -> float:
	var sup: Dictionary = state.get("supplies", {})
	return float(sup.get("rum", 0.0))


## Bottles he can take into a fight: what the ship's rum allows, up to DeckData.RUM_PER_FIGHT.
static func rum_bottles(state: Dictionary) -> int:
	return mini(floori(rum_supply(state) / DeckData.RUM_SUPPLY_PER_DRINK + 0.0001), DeckData.RUM_PER_FIGHT)


## Write a finished deck fight back: his hit points (a captain who went down wakes battered) and the rum he drank.
static func after_fight(state: Dictionary, result: Dictionary) -> void:
	if bool(result.get("captain_down", false)):
		state["captain_hp"] = DeckData.KNOCKED_OUT_HP
	else:
		state["captain_hp"] = clampf(float(result.get("captain_hp", hp(state))), 1.0, DeckData.FIGHTER_HP)
	_use_rum(state, int(result.get("rum_drunk", 0)))


## Out of a fight his wounds close slowly: `dt` real seconds.
static func regen(state: Dictionary, dt: float) -> void:
	if not state.has("captain_hp"):
		return
	state["captain_hp"] = minf(hp(state) + DeckData.REGEN_HP_PER_S * dt, DeckData.FIGHTER_HP)


## Drink a bottle at sea or ashore: 50 hit points back. False when he is unhurt or the rum is gone.
static func drink(state: Dictionary) -> bool:
	if hp(state) >= DeckData.FIGHTER_HP or rum_supply(state) < DeckData.RUM_SUPPLY_PER_DRINK - 0.0001:
		return false
	state["captain_hp"] = minf(hp(state) + DeckData.RUM_HEAL, DeckData.FIGHTER_HP)
	_use_rum(state, 1)
	return true


static func _use_rum(state: Dictionary, drinks: int) -> void:
	if drinks <= 0 or not state.has("supplies"):
		return
	state["supplies"]["rum"] = maxf(rum_supply(state) - DeckData.RUM_SUPPLY_PER_DRINK * float(drinks), 0.0)
