class_name Fleet
extends RefCounted
## The player's ships. A captured ship joins the fleet with a prize crew.

var flagship: Dictionary = {}
var ships: Array[Dictionary] = []


func add_captured(class_id: String, hull_fraction: float, prize_crew: int, name: String = "") -> Dictionary:
	var entry: Dictionary = {"class_id": class_id, "hull": hull_fraction, "crew": prize_crew, "name": name if name != "" else "Prize %d" % (ships.size() + 1)}
	ships.append(entry)
	return entry


func size() -> int:
	return ships.size()


func has_ship(name: String) -> bool:
	for s in ships:
		if s["name"] == name:
			return true
	return false
