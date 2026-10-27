class_name Progression
extends RefCounted
## The captain's XP, level, skill points and ranks, kept in state["captain_xp"], state["captain_level"],
## state["skills"] (full skill id -> rank) and state["skill_points_spent"].


static func xp(state: Dictionary) -> int:
	return int(state.get("captain_xp", 0))


static func level_for_xp(total: int) -> int:
	var lvl: int = 1
	while lvl < ProgressionData.MAX_LEVEL and total >= ProgressionData.xp_to_reach(lvl + 1):
		lvl += 1
	return lvl


## Adds XP, levels the captain up as far as it goes and returns how many levels were gained.
static func add_xp(state: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var before: int = int(state.get("captain_level", 1))
	state["captain_xp"] = xp(state) + amount
	var after: int = level_for_xp(xp(state))
	state["captain_level"] = after
	return after - before


static func points_total(state: Dictionary) -> int:
	return (int(state.get("captain_level", 1)) - 1) * ProgressionData.POINTS_PER_LEVEL


static func points_free(state: Dictionary) -> int:
	return points_total(state) - int(state.get("skill_points_spent", 0))


static func rank(state: Dictionary, full_id: String) -> int:
	return int((state.get("skills", {}) as Dictionary).get(full_id, 0))


static func can_spend(state: Dictionary, full_id: String) -> bool:
	return not ProgressionData.skill(full_id).is_empty() and rank(state, full_id) < ProgressionData.MAX_RANK and points_free(state) > 0


static func spend(state: Dictionary, full_id: String) -> bool:
	if not can_spend(state, full_id):
		return false
	if not state.has("skills"):
		state["skills"] = {}
	state["skills"][full_id] = rank(state, full_id) + 1
	state["skill_points_spent"] = int(state.get("skill_points_spent", 0)) + 1
	return true


## Hands every point back so the captain can rebuild.
static func respec(state: Dictionary) -> void:
	state["skills"] = {}
	state["skill_points_spent"] = 0


## The value of one stat at a given rank (0 is the neutral value).
static func value_at(full_id: String, rank_n: int) -> float:
	var s: Dictionary = ProgressionData.skill(full_id)
	if s.is_empty() or rank_n <= 0:
		return float(s.get("neutral", 0.0))
	return float((s["ranks"] as Array)[clampi(rank_n, 1, ProgressionData.MAX_RANK) - 1])


## The captain's current value of a skill's stat by stat name, e.g. stat(state, "reload_mult").
static func stat(state: Dictionary, stat_name: String) -> float:
	for full_id in ProgressionData.skill_ids():
		var s: Dictionary = ProgressionData.skill(full_id)
		if s["stat"] == stat_name:
			return value_at(full_id, rank(state, full_id))
	return 0.0


static func ship_tier(class_id: String) -> int:
	return int(ProgressionData.CLASS_TIER.get(class_id, 1))


## XP for an event: kind is "sink", "capture", "duel", "tour", "island" or "trade"; ctx carries class_id, tour_id or gold.
static func xp_for(kind: String, ctx: Dictionary = {}) -> int:
	match kind:
		"sink":
			return int(ProgressionData.XP["sink_per_tier"]) * ship_tier(str(ctx.get("class_id", "")))
		"capture":
			return int(ProgressionData.XP["capture_per_tier"]) * ship_tier(str(ctx.get("class_id", "")))
		"duel":
			return int(ProgressionData.XP["duel"])
		"island":
			return int(ProgressionData.XP["island"])
		"tour":
			return int(ProgressionData.TOUR_XP.get(str(ctx.get("tour_id", "")), ProgressionData.TOUR_XP_DEFAULT))
		"trade":
			return int(ctx.get("gold", 0)) / int(ProgressionData.XP["trade_gold_per_xp"])
	return 0
