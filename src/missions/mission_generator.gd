class_name MissionGenerator
extends RefCounted
## Builds missions from templates. Every mission is checked so it is winnable for the given player.

const TYPES: Dictionary = {
	"hunt": {"reward": [1500, 40000], "power_factor": 0.9},
	"escort": {"reward": [800, 12000], "power_factor": 0.6},
	"delivery": {"reward": [600, 15000], "power_factor": 0.0},
	"treasure": {"reward": [3000, 80000], "power_factor": 0.4},
	"siege": {"reward": [10000, 90000], "power_factor": 1.1},
	"rescue": {"reward": [2000, 20000], "power_factor": 0.7},
	"explore": {"reward": [1000, 10000], "power_factor": 0.0},
}
const WEIGHTS: Dictionary = {"hunt": 20, "escort": 16, "delivery": 18, "treasure": 10, "siege": 4, "rescue": 8, "explore": 10}
const SPEED_MS: float = 5.0  ## conservative sailing speed for deadline checks
const DEADLINE_SLACK: float = 2.0


## `ctx`: {player_power, player_speed_ms, port_pos Vector2, nav SeaNav, gen WorldGen}.
## Returns a mission dictionary; never one whose enemy is far stronger than the player or whose goal is unreachable.
static func generate(rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	var type: String = _pick(rng)
	var spec: Dictionary = TYPES[type]
	var power: float = ctx["player_power"]
	var gen: WorldGen = ctx["gen"]
	var nav: SeaNav = ctx["nav"]
	var port: Vector2 = ctx["port_pos"]
	var m: Dictionary = {"type": type, "power_required": 0.0, "reward": 0}
	var lo: int = spec["reward"][0]
	var hi: int = spec["reward"][1]
	# Harder missions pay more, but never ask for more than the player can bring.
	var diff: float = rng.randf()
	m["reward"] = int(lerpf(lo, hi, diff * diff))
	m["power_required"] = minf(power * spec["power_factor"] * lerpf(0.4, 1.0, diff), power * 0.9)
	var dest: Vector2 = port
	var candidates: Array[Dictionary] = []
	for p in gen.pois:
		if p["type"] in ["port", "cave", "treasure_island", "fort", "wreck"] and p["pos"] != port:
			candidates.append(p)
	for attempt in 30:
		var c: Dictionary = candidates[rng.randi() % candidates.size()]
		var path: PackedVector2Array = nav.find_path(port, c["pos"])
		if path.size() > 0:
			dest = c["pos"]
			m["path_length"] = path.size() * SeaNav.CELL_M
			break
	if not m.has("path_length"):
		m["type"] = "explore"
		m["power_required"] = 0.0
		m["path_length"] = 0.0
	m["dest"] = dest
	var speed: float = maxf(ctx.get("player_speed_ms", SPEED_MS), 1.0)
	m["deadline_s"] = (m["path_length"] / speed) * DEADLINE_SLACK + 600.0
	return m


static func is_winnable(m: Dictionary, ctx: Dictionary) -> bool:
	if m["power_required"] > ctx["player_power"]:
		return false
	var speed: float = maxf(ctx.get("player_speed_ms", SPEED_MS), 1.0)
	if m["deadline_s"] < m["path_length"] / speed * 1.2:
		return false
	var spec: Dictionary = TYPES[m["type"]]
	return m["reward"] >= spec["reward"][0] and m["reward"] <= spec["reward"][1]


static func _pick(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for w in WEIGHTS.values():
		total += w
	var r: int = rng.randi() % total
	for k in WEIGHTS.keys():
		r -= WEIGHTS[k]
		if r < 0:
			return k
	return "hunt"
