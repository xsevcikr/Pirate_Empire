class_name DeckFishing
extends RefCounted
## The easy fishing moment from the ship's rail: cast with E, wait for the float to bob, press E again while it
## dips and the fish lands on deck as food for the crew. Pressing too early does nothing; waiting too long lets the
## fish go and the line is cast again. No tension bar, no way to lose anything.

enum Phase { IDLE, WAITING, BITE, CAUGHT, MISSED }

const WAIT_MIN_S: float = 2.5
const WAIT_MAX_S: float = 6.0
const BITE_WINDOW_S: float = 2.5  ## generous on purpose: the game is for young captains
const SHOW_S: float = 2.2  ## how long a caught fish (or the miss) is shown before the line goes back in
## Food units (one unit feeds four men for a day) for each fish; the ids and their weights are the old fishing game's.
const FOOD: Dictionary = {"sardine": 1, "bass": 2, "tuna": 3, "marlin": 5}

var phase: Phase = Phase.IDLE
var fish: String = ""
var timer: float = 0.0
var rng: RandomNumberGenerator


func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r != null else RandomNumberGenerator.new()


func cast() -> void:
	phase = Phase.WAITING
	fish = ""
	timer = rng.randf_range(WAIT_MIN_S, WAIT_MAX_S)


func stop() -> void:
	phase = Phase.IDLE
	timer = 0.0


func is_out() -> bool:
	return phase != Phase.IDLE


## Advance the clock. Returns true when the phase changed this tick.
func tick(delta: float) -> bool:
	if phase == Phase.IDLE:
		return false
	timer -= delta
	if timer > 0.0:
		return false
	match phase:
		Phase.WAITING:
			phase = Phase.BITE
			timer = BITE_WINDOW_S
		Phase.BITE:
			phase = Phase.MISSED
			timer = SHOW_S
		Phase.CAUGHT, Phase.MISSED:
			cast()
	return true


## The captain pulls the line. Only a bite catches anything; returns true for a catch.
func pull() -> bool:
	if phase != Phase.BITE:
		return false
	fish = Fishing.pick_fish(rng)
	phase = Phase.CAUGHT
	timer = SHOW_S
	return true


static func food_for(fish_id: String) -> int:
	return int(FOOD.get(fish_id, 1))


## Put the catch in the ship's stores. Returns the food units added.
static func land(state: Dictionary, fish_id: String) -> int:
	var food: int = food_for(fish_id)
	var sup: Dictionary = state["supplies"]
	sup["food"] = float(sup.get("food", 0.0)) + float(food)
	Achievements.record(state, "fish_caught")
	return food
