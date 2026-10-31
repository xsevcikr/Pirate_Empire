class_name SeaShanty
extends RefCounted
## The crew sings at sea (H): the music gives way to a shanty for one verse-and-chorus round, and the first song of
## each day lifts morale. A crew that is too low to sing, or in the middle of a fight, will not.

const MIN_MORALE: float = 40.0  ## the same spirit the siren waters ask for
const MORALE_GAIN: float = 4.0
const SING_S: float = 70.0


## Why the crew will not sing now ("" when it will): "morale" or "fight".
static func refusal(state: Dictionary, fighting: bool) -> String:
	if fighting:
		return "fight"
	if float(state.get("morale", 0.0)) < MIN_MORALE:
		return "morale"
	return ""


## Strike up the next shanty. Returns {track, shanty, morale}: the morale the song gave (0 after the day's first).
static func sing(state: Dictionary, day: int) -> Dictionary:
	var n: int = AudioData.SHANTIES.size()
	var i: int = posmod(day + int(state.get("shanties_sung", 0)), n)
	state["shanties_sung"] = int(state.get("shanties_sung", 0)) + 1
	var gain: float = 0.0
	if int(state.get("shanty_day", -99)) != day:
		state["shanty_day"] = day
		gain = MORALE_GAIN
		state["morale"] = minf(float(state["morale"]) + gain, 100.0)
	return {"track": "shanty_" + AudioData.SHANTIES[i], "shanty": AudioData.SHANTIES[i], "morale": gain}
