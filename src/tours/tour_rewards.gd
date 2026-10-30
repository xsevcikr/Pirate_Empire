class_name TourRewards
extends RefCounted
## Perks won in tours and from bosses. Each is recorded once in the tours record; a few change the game at once.

## Perks that other systems read. frost_sails stops storm mast damage, kraken_ink adds the ink cloud ability.
const EFFECTS: Dictionary = {
	"explosive_blueprint": {"ammo": {"explosive": 40}},
	"armor_t5": {"upgrade": {"armor": 5}},
}

## Which boss rewards are granted by beating the boss in its arena rather than by a tour.
const BOSS_PERKS: Dictionary = {
	"valcourt": ["ship_sovereign"],
	"ghost_admiral": ["ship_revenant"],
	"kraken": ["kraken_ink"],
	"black_ibrahim": ["pirate_king_crown"],
}


## Records a perk once and applies its effect once. Returns true when it was new.
static func grant_perk(state: Dictionary, perk: String) -> bool:
	var perks: Array = TourState.root(state)["perks"]
	if perks.has(perk):
		return false
	perks.append(perk)
	var fx: Dictionary = EFFECTS.get(perk, {})
	for k: String in fx.get("ammo", {}):
		state["ammo"][k] = int(state["ammo"].get(k, 0)) + int(fx["ammo"][k])
	for k: String in fx.get("upgrade", {}):
		state["upgrades"][k] = maxi(int(state["upgrades"].get(k, 0)), int(fx["upgrade"][k]))
	return true


static func has(state: Dictionary, perk: String) -> bool:
	return TourState.root(state)["perks"].has(perk)


## What a boss gives for a first defeat. Later defeats give nothing.
static func boss_defeated(state: Dictionary, boss_id: String) -> Array[String]:
	var out: Array[String] = []
	for perk: String in BOSS_PERKS.get(boss_id, []):
		if grant_perk(state, perk):
			out.append(perk)
	return out


## Storm mast damage multiplier: frost-proof sails take none.
static func storm_mast_factor(state: Dictionary) -> float:
	return 0.0 if has(state, "frost_sails") else TourHazards.FROST_STORM_MAST_DAMAGE
