class_name CrewDeck
extends RefCounted
## Deck fights against a rival crew. Their men use the same weapons and moves as everyone else; what makes them
## hard is skill, not extra health: they parry and block more often, aim faster and never run. A crew's grit sets
## how much (CrewData). The fight itself is DeckCombat; this only shapes the enemy side.


## Enemy line-up for `count` of a crew's men, like DeckBridge.enemy_roster: officers, marksmen and bruisers up front,
## marines in reserve. The flagship brings the crew's captain.
static func roster(id: String, count: int, with_captain: bool) -> Dictionary:
	var shown: int = mini(count, DeckData.MAX_ON_SCREEN)
	var out: Array = []
	for i in shown:
		out.append("captain" if with_captain and i == 0 else CrewData.DECK_MIX[i % CrewData.DECK_MIX.size()])
	return {"fighters": out, "reserve": maxi(count - shown, 0), "reserve_kind": "marine", "crew": id}


## Sharpens every enemy fighter of a built fight by the crew's grit.
static func toughen(c: DeckCombat, id: String) -> void:
	var grit: float = float(CrewData.def(id)["grit"])
	for f in c.fighters:
		if f.team != 1:
			continue
		f.parry_skill = minf(0.9, f.parry_skill + CrewData.DECK_PARRY_ADD * grit)
		f.block_skill = minf(0.9, f.block_skill + CrewData.DECK_BLOCK_ADD * grit)
		f.panics = false
		f.aim_left *= lerpf(1.0, CrewData.DECK_AIM_MULT, grit)
	c.reserve_kind[1] = "marine"
	c.morale[1] = maxf(c.morale[1], 80.0 + 20.0 * grit)
