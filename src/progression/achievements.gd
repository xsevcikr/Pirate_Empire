class_name Achievements
extends RefCounted
## Lifetime stats and achievement unlocks, kept in state["stats"] (name -> number) and state["achievements"]
## (id -> day unlocked).


static func stats(state: Dictionary) -> Dictionary:
	if not state.has("stats"):
		state["stats"] = {}
	return state["stats"]


## Records a stat event. Most stats add up; the "best_*" ones keep their maximum.
static func record(state: Dictionary, name: String, amount: float = 1.0) -> void:
	var s: Dictionary = stats(state)
	if AchievementData.MAX_STATS.has(name):
		s[name] = maxf(float(s.get(name, 0.0)), amount)
	else:
		s[name] = float(s.get(name, 0.0)) + amount


## A counter's value: stored stats plus the ones that live elsewhere in the state.
static func value(state: Dictionary, name: String) -> float:
	match name:
		"captain_level":
			return float(state.get("captain_level", 1))
		"bases_owned":
			return float((state.get("bases", []) as Array).size())
		"prizes_taken":
			return float(state.get("prizes_taken", 0))
		"rivals_beaten":
			var n: int = 0
			for r: Dictionary in (state.get("rivals", {}) as Dictionary).values():
				if bool(r.get("defeated", false)):
					n += 1
			return float(n)
		"recruited_molly":
			return 1.0 if (state.get("officers", []) as Array).has("molly") else 0.0
		"best_skill_rank":
			var best: int = 0
			for id in ProgressionData.skill_ids():
				best = maxi(best, Progression.rank(state, id))
			return float(best)
		"days_without_starving":
			return float(int(state.get("day", 0))) if float(stats(state).get("starved_days", 0.0)) <= 0.0 else 0.0
	return float(stats(state).get(name, 0.0))


static func unlocked(state: Dictionary, id: String) -> bool:
	return (state.get("achievements", {}) as Dictionary).has(id)


static func count(state: Dictionary) -> int:
	return (state.get("achievements", {}) as Dictionary).size()


## Unlocks everything whose goal is met and returns the ids newly unlocked.
static func check(state: Dictionary) -> Array[String]:
	if not state.has("achievements"):
		state["achievements"] = {}
	var fresh: Array[String] = []
	for a in AchievementData.LIST:
		var id: String = str(a["id"])
		if state["achievements"].has(id):
			continue
		if value(state, str(a["stat"])) >= float(a["goal"]):
			state["achievements"][id] = int(state.get("day", 0))
			fresh.append(id)
	return fresh
