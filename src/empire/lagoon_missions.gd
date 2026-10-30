class_name LagoonMissions
extends RefCounted
## Jobs the pirates living in the lagoon go out on while the captain is away, sent from the harbour office. The
## crew leaves the lagoon for some days and comes back with gold, a few may die on the way, and now and then a
## whole party never returns. state["lagoon"] keeps:
##   missions: [{id, crew, back}]           parties out now; `back` is the day they come home
##   mission_log: [{id, sent, alive, gold, day}]  the latest returns, newest first; alive 0 means lost
##   away: int                              residents out on missions (their beds stay theirs)

const LOG_SIZE: int = 6
const MORALE_SAFETY: float = 0.01  ## each point of the lagoon's morale bonus takes this share off the risks
const MAX_SAFETY: float = 0.3

## crew: pirates sent; days: time away; gold: [low, high] if all come back; risk: chance each pirate dies;
## lost: chance the whole party never returns; rank: lagoon rank needed; icon: catalogue picture.
const MISSIONS: Array[Dictionary] = [
	{"id": "fishing", "crew": 3, "days": 1, "gold": [60, 140], "risk": 0.02, "lost": 0.0, "rank": 0, "icon": "pirate/barrel"},
	{"id": "wreck_dive", "crew": 4, "days": 2, "gold": [160, 420], "risk": 0.06, "lost": 0.01, "rank": 0, "icon": "pirate/chest"},
	{"id": "merchant_raid", "crew": 6, "days": 2, "gold": [350, 800], "risk": 0.1, "lost": 0.03, "rank": 0, "icon": "pirate/ship-pirate-small"},
	{"id": "smuggling", "crew": 5, "days": 3, "gold": [500, 1100], "risk": 0.07, "lost": 0.05, "rank": 1, "icon": "pirate/crate"},
	{"id": "treasure_hunt", "crew": 8, "days": 4, "gold": [900, 2400], "risk": 0.12, "lost": 0.06, "rank": 1, "icon": "dungeon/coin"},
	{"id": "convoy_raid", "crew": 12, "days": 4, "gold": [1800, 4200], "risk": 0.18, "lost": 0.08, "rank": 2, "icon": "pirate/ship-pirate-medium"},
	{"id": "fort_raid", "crew": 20, "days": 6, "gold": [4000, 9000], "risk": 0.25, "lost": 0.12, "rank": 3, "icon": "pirate/cannon"},
]


static func mission(id: String) -> Dictionary:
	for m: Dictionary in MISSIONS:
		if m["id"] == id:
			return m
	return {}


static func active(s: Dictionary) -> Array:
	return Lagoon.data(s).get("missions", []) if Lagoon.claimed(s) else []


static func log_of(s: Dictionary) -> Array:
	return Lagoon.data(s).get("mission_log", []) if Lagoon.claimed(s) else []


static func away(s: Dictionary) -> int:
	return int(Lagoon.data(s).get("away", 0)) if Lagoon.claimed(s) else 0


## Parties that can be out at once: one more for every lagoon rank.
static func slots(s: Dictionary) -> int:
	return Lagoon.rank_of(s) + 1 if Lagoon.claimed(s) else 0


static func is_out(s: Dictionary, id: String) -> bool:
	for m: Dictionary in active(s):
		if m["id"] == id:
			return true
	return false


## Share taken off the death and loss chances by the taverns, fires and statues of the lagoon.
static func safety(s: Dictionary) -> float:
	return minf(Lagoon.morale_bonus(s) * MORALE_SAFETY, MAX_SAFETY)


static func risk(s: Dictionary, id: String) -> float:
	return float(mission(id)["risk"]) * (1.0 - safety(s))


static func loss_chance(s: Dictionary, id: String) -> float:
	return float(mission(id)["lost"]) * (1.0 - safety(s))


## Why a party cannot be sent ("" when it can): "unclaimed", "rank", "out", "slots", "crew".
static func send_problem(s: Dictionary, id: String) -> String:
	if not Lagoon.claimed(s):
		return "unclaimed"
	var m: Dictionary = mission(id)
	if Lagoon.rank_of(s) < int(m["rank"]):
		return "rank"
	if is_out(s, id):
		return "out"
	if active(s).size() >= slots(s):
		return "slots"
	if int(Lagoon.data(s)["pop"]) < int(m["crew"]):
		return "crew"
	return ""


static func send(s: Dictionary, id: String) -> bool:
	if send_problem(s, id) != "":
		return false
	var m: Dictionary = mission(id)
	var l: Dictionary = Lagoon.data(s)
	var n: int = int(m["crew"])
	l["pop"] = int(l["pop"]) - n
	l["away"] = away(s) + n
	if not l.has("missions"):
		l["missions"] = []
	l["missions"].append({"id": id, "crew": n, "back": int(s["day"]) + int(m["days"])})
	return true


## Bring home every party whose day has come. Gold goes straight to the captain's purse. Returns the log entries
## of the parties that came back (or did not), oldest first.
static func daily(s: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not Lagoon.claimed(s):
		return out
	var l: Dictionary = Lagoon.data(s)
	var still: Array = []
	for p: Dictionary in active(s):
		if int(p["back"]) > int(s["day"]):
			still.append(p)
			continue
		out.append(_resolve(s, p, rng))
	l["missions"] = still
	var history: Array = l.get("mission_log", [])
	for e in out:
		history.push_front(e)
	l["mission_log"] = history.slice(0, LOG_SIZE)
	return out


static func _resolve(s: Dictionary, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var l: Dictionary = Lagoon.data(s)
	var id: String = p["id"]
	var m: Dictionary = mission(id)
	var sent: int = int(p["crew"])
	l["away"] = maxi(away(s) - sent, 0)
	var e: Dictionary = {"id": id, "sent": sent, "alive": 0, "gold": 0, "day": int(s["day"])}
	if rng.randf() < loss_chance(s, id):
		return e
	var alive: int = 0
	var r: float = risk(s, id)
	for i in sent:
		if rng.randf() >= r:
			alive += 1
	if alive == 0:
		return e
	var g: int = int(rng.randi_range(int(m["gold"][0]), int(m["gold"][1])) * float(alive) / float(sent))
	s["gold"] = int(s["gold"]) + g
	l["pop"] = mini(int(l["pop"]) + alive, maxi(Lagoon.beds(s) - away(s), 0))
	e["alive"] = alive
	e["gold"] = g
	return e


## One line for the toast and the log card.
static func report(e: Dictionary) -> String:
	var title: String = Loc.t("mission." + str(e["id"]))
	if int(e["alive"]) == 0:
		return Loc.t("mission.report_lost") % [title, int(e["sent"])]
	var dead: int = int(e["sent"]) - int(e["alive"])
	if dead > 0:
		return Loc.t("mission.report_hurt") % [title, int(e["gold"]), dead]
	return Loc.t("mission.report_ok") % [title, int(e["gold"])]


static func restore_types(l: Dictionary) -> void:
	l["away"] = int(l.get("away", 0))
	l["housing"] = int(l.get("housing", 0))
	for p: Dictionary in l.get("missions", []):
		p["crew"] = int(p["crew"])
		p["back"] = int(p["back"])
	for e: Dictionary in l.get("mission_log", []):
		for k in ["sent", "alive", "gold", "day"]:
			e[k] = int(e[k])
