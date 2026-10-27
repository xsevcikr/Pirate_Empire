class_name UpgradeEffects
extends RefCounted
## What each upgrade tier does to a ship's stats (spec section 5). Lines without a stat here (cannons, ram,
## specialty, armor) are recorded and bought but act through combat code later.

const PER_TIER: Dictionary = {
	"hull": {"hull_hp": 0.10},
	"sails": {"max_speed_kn": 0.04, "turn_rate_deg_s": 0.05},
	"rudder": {"turn_rate_deg_s": 0.08, "rudder_hp": 0.20},
	"quarters": {"crew_max": 0.10},
}


## A copy of `base` with the owned upgrades applied. `owned` maps line -> tier.
static func apply(base: ShipStats, owned: Dictionary) -> ShipStats:
	var s: ShipStats = base.duplicate()
	for line: String in owned:
		if not PER_TIER.has(line):
			continue
		var tiers: int = int(owned[line])
		for stat: String in PER_TIER[line]:
			var v: float = float(s.get(stat))
			var scaled: float = v * (1.0 + PER_TIER[line][stat] * tiers)
			s.set(stat, int(round(scaled)) if typeof(s.get(stat)) == TYPE_INT else scaled)
	return s
