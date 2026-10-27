class_name KnifeThrow
extends RefCounted
## Knife throwing at a spinning board: you pick the moment, the board's angle decides if the blade lands on the
## target ring or the spokes. `timing_error` is how far off the sweet spot the throw was (0 perfect, 1 worst).

var scores: Array[int] = []


static func ring_score(timing_error: float) -> int:
	var e: float = absf(timing_error)
	for ring: Array in GameData.KNIFE["rings"]:
		if e <= float(ring[0]):
			return int(ring[1])
	return 0


func throw_knife(timing_error: float) -> bool:
	if scores.size() >= int(GameData.KNIFE["throws"]):
		return false
	scores.append(ring_score(timing_error))
	return true


func done() -> bool:
	return scores.size() >= int(GameData.KNIFE["throws"])


func total() -> int:
	var t: int = 0
	for s in scores:
		t += s
	return t


func gold() -> int:
	return total() * int(GameData.KNIFE["gold_per_point"])


func earns_outfit() -> bool:
	return total() >= int(GameData.KNIFE["outfit_score"])
