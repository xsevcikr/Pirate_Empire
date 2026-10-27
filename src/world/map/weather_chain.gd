class_name WeatherChain
extends RefCounted
## Weather as a Markov chain stepped every few game hours, biased by the region's tendency.

const STATES: Array[String] = ["clear", "overcast", "rain", "storm", "fog"]
const STEP_HOURS: float = 6.0
const STAY: float = 0.55  ## chance to keep the current state each step

var state: String = "clear"
var rng := RandomNumberGenerator.new()
var visited: Dictionary = {}


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	visited[state] = true


## One step. `tendency`: state -> weight (the region's typical weather); other states get a small floor weight.
func step(tendency: Dictionary) -> String:
	if rng.randf() >= 1.0 - STAY:
		visited[state] = true
		return state
	var total: float = 0.0
	var w: Dictionary = {}
	for s in STATES:
		var v: float = tendency.get(s, 0.0) + 0.04
		w[s] = v
		total += v
	var r: float = rng.randf() * total
	for s in STATES:
		r -= w[s]
		if r <= 0.0:
			state = s
			break
	visited[state] = true
	return state


## Sea state bump (Beaufort-ish) by weather.
static func sea_state_bonus(s: String) -> int:
	match s:
		"storm":
			return 3
		"rain":
			return 1
	return 0
