class_name DeckBridge
extends RefCounted
## Turns two ships and the running state into a DeckCombat, and the finished fight back into crew counts.

## Who defends, by ship faction: archetype weights in order of rank. The first slots are the best men.
const MIX: Dictionary = {
	"navy": ["officer", "marine", "marine", "marine", "sailor"],
	"pirate": ["captain", "brute", "brawler", "sailor", "marine", "brawler"],
	"merchant": ["officer", "sailor", "brawler", "sailor", "brute"],
	"default": ["officer", "sailor", "marine", "sailor", "sailor"],
}
const CAPTAIN_MIN_CREW: int = 18  ## smaller ships have no captain worth a duel


## Enemy line-up for `count` men: the on-screen twelve and the rest in reserve.
static func enemy_roster(faction: String, count: int) -> Dictionary:
	var crew_id: String = CrewData.id_of_faction(faction)
	if crew_id != "":
		return CrewDeck.roster(crew_id, count, count >= CAPTAIN_MIN_CREW)
	var mix: Array = MIX.get(faction, MIX["default"])
	var shown: int = mini(count, DeckData.MAX_ON_SCREEN)
	var out: Array = []
	for i in shown:
		var kind: String = str(mix[i % mix.size()])
		if kind == "captain" and count < CAPTAIN_MIN_CREW:
			kind = "officer"
		if i > 0 and kind == "captain":
			kind = "marine"
		out.append(kind)
	var reserve_kind: String = "sailor" if faction in ["merchant", "default"] else "marine"
	return {"fighters": out, "reserve": maxi(count - shown, 0), "reserve_kind": reserve_kind}


## `committed`: men sent across; the rest of the crew stays aboard.
static func build(committed: int, quality: float, morale: float, enemy_faction: String, enemy_count: int, enemy_quality: float,
		enemy_morale: float, state: Dictionary, seed_value: int) -> DeckCombat:
	var roster: Array = state.get("roster", [])
	var crew: Array = []
	var ids: Array = []
	for m: Dictionary in roster:
		ids.append(m)
	var on_screen: int = mini(maxi(committed - 1, 0), DeckData.MAX_ON_SCREEN - 1)
	for i in on_screen:
		if i < ids.size():
			crew.append({"type": str(ids[i]["type"]), "level": int(ids[i].get("level", 1)), "name": str(ids[i].get("name", "Hand"))})
		else:
			crew.append({"type": "green", "level": 1, "name": "Hand"})
	var theirs: Dictionary = enemy_roster(enemy_faction, enemy_count)
	theirs["morale"] = enemy_morale
	var mine: Dictionary = {
		"level": int(state.get("captain_level", 1)), "melee": str(state.get("melee", "rusty_cutlass")), "ranged": str(state.get("pistol", "flintlock")),
		"shots": int(state.get("pistol_shots", 10)), "hp": CaptainHealth.hp(state), "rum": CaptainHealth.rum_bottles(state), "crew": crew, "reserve": maxi(committed - 1 - on_screen, 0), "morale": morale,
		"effic": Morale.efficiency(morale) * clampf(quality, 0.5, 1.5),
		"skills": {
			"stamina_add": Progression.stat(state, "stamina_add"), "melee_damage_mult": Progression.stat(state, "melee_damage_mult"),
			"parry_window_mult": Progression.stat(state, "parry_window_mult"), "pistol_reload_mult": Progression.stat(state, "pistol_reload_mult"),
		},
	}
	var c := DeckCombat.new()
	c.setup(mine, theirs, seed_value)
	if theirs.has("crew"):
		CrewDeck.toughen(c, str(theirs["crew"]))
	return c


## Man-for-man autopilot for the captain, used when no hands are on the controls (tests, replays).
static func autopilot(c: DeckCombat, dt: float) -> void:
	var p: FighterState = c.player
	if not p.is_standing():
		return
	p.think_left -= dt
	if p.think_left > 0.0:
		return
	p.think_left = DeckData.AI_THINK_S
	p.move_intent = Vector2.ZERO
	var t: FighterState = c.nearest_enemy(p)
	if t != null:
		DeckAI._fight(c, p, t, 1.0)
