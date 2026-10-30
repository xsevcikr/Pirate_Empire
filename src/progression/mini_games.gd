class_name MiniGames
extends RefCounted
## What the tavern and sea games pay out: settles a finished game against the state (gold, rumours, map fragments,
## recruits, morale, XP) and records the stats. The games themselves are the classes in games/.

const RUMOURS: int = 3


static func valid_bet(state: Dictionary, bet: int) -> bool:
	return bet >= GameData.BET_MIN and bet <= GameData.BET_MAX and bet <= int(state["gold"])


static func _gold(state: Dictionary, delta: int) -> void:
	state["gold"] = maxi(int(state["gold"]) + delta, 0)
	if delta > 0:
		Achievements.record(state, "gold_earned", float(delta))


static func _played(state: Dictionary, game: String, won: bool) -> void:
	Achievements.record(state, "games_played")
	Achievements.record(state, "games_" + game + ("_won" if won else "_lost"))


## Liar's dice. `shady`: the opponent is a dodgy sort who may stake a map fragment on a big bet.
static func settle_dice(state: Dictionary, game: LiarsDice, bet: int, shady: bool, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"gold": 0, "map_fragment": ""}
	if not game.over:
		return out
	_played(state, "dice", game.player_won)
	if game.player_won:
		out["gold"] = bet
		_gold(state, bet)
		if shady and bet >= int(GameData.LIARS_DICE["shady_bet_min"]) and rng.randf() < float(GameData.LIARS_DICE["map_fragment_chance"]):
			var frag: String = MapFragments.next_missing(state)
			if frag != "" and MapFragments.add(state, frag):
				out["map_fragment"] = frag
	else:
		out["gold"] = -bet
		_gold(state, -bet)
	return out


static func settle_bones(state: Dictionary, game: Bones, bet: int, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"gold": 0, "rumour": -1}
	if not game.over:
		return out
	var delta: int = game.payout(bet)
	_played(state, "bones", delta > 0)
	_gold(state, delta)
	out["gold"] = delta
	if delta > 0 and rng.randf() < float(GameData.BONES["rumour_chance"]):
		out["rumour"] = rng.randi_range(0, RUMOURS - 1)
	return out


static func settle_arm_wrestle(state: Dictionary, won: bool, ship_has_room: bool) -> Dictionary:
	var out: Dictionary = {"morale": 0.0, "recruit": false}
	_played(state, "arm", won)
	if won:
		out["morale"] = float(GameData.ARM_WRESTLE["recruit_morale"])
		state["morale"] = clampf(float(state["morale"]) + float(out["morale"]), 0.0, 100.0)
		out["recruit"] = ship_has_room
	return out


static func settle_drinking(state: Dictionary, game: DrinkingContest) -> Dictionary:
	_played(state, "drinking", game.rounds_won() > 0)
	_gold(state, game.gold())
	return {"gold": game.gold(), "rumour": game.rival_rumour()}


## Selling or eating a fish. Eating adds food days; selling pays its value.
static func settle_fishing(state: Dictionary, game: Fishing, eat: bool) -> Dictionary:
	var out: Dictionary = {"gold": 0, "food_days": 0.0, "bottle": false}
	_played(state, "fishing", game.phase == Fishing.Phase.CAUGHT)
	if game.phase != Fishing.Phase.CAUGHT:
		return out
	if eat:
		out["food_days"] = game.food_days()
		state["supplies"]["food"] = float(state["supplies"].get("food", 0.0)) + float(out["food_days"])
	else:
		out["gold"] = game.value()
		_gold(state, int(out["gold"]))
	out["bottle"] = game.bottle()
	Achievements.record(state, "fish_caught")
	return out


static func settle_range(state: Dictionary, game: GunneryRange) -> Dictionary:
	var xp: int = game.gunnery_xp()
	Progression.add_xp(state, xp)
	_played(state, "range", game.hits > 0)
	for m: Dictionary in state["roster"]:
		if m["type"] == "gunner":
			m["xp"] = int(m["xp"]) + game.crew_xp()
	return {"xp": xp, "crew_xp": game.crew_xp()}


static func settle_knife(state: Dictionary, game: KnifeThrow) -> Dictionary:
	var out: Dictionary = {"gold": game.gold(), "outfit": false}
	_played(state, "knife", game.total() > 0)
	_gold(state, game.gold())
	if game.earns_outfit():
		var key: String = str(GameData.KNIFE["outfit"])
		var owned: Array = Customization.get_custom(state)["owned"]
		if not owned.has(key):
			owned.append(key)
			out["outfit"] = true
	return out
