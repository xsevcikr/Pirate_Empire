class_name LegendaryShips
extends RefCounted
## The two ships that cannot be bought: the Revenant, won in the Ghost Admiral's Ledger, and the Sovereign of
## Brass, taken from Admiral Valcourt. Owning one is a perk in the tours record; taking the helm swaps the flagship
## and parks the old one in the fleet.

const SHIPS: Dictionary = {
	"revenant": {"perk": "ship_revenant", "name": "The Revenant"},
	"sovereign": {"perk": "ship_sovereign", "name": "Sovereign of Brass"},
}


static func owned(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var perks: Array = TourState.root(state)["perks"]
	for id: String in SHIPS:
		if perks.has(SHIPS[id]["perk"]):
			out.append(id)
	return out


## Swap the flagship. The old ship goes to the fleet at its current hull; the crew and cargo stay aboard.
static func take_helm(state: Dictionary, class_id: String) -> bool:
	if not owned(state).has(class_id) or state["ship_class"] == class_id:
		return false
	var old: String = state["ship_class"]
	state["fleet"].append({"class": old, "name": str(state["ship_name"]), "crew": 0, "hull": float(state["ship_hull"])})
	state["ship_class"] = class_id
	state["ship_name"] = SHIPS[class_id]["name"]
	state["ship_hull"] = 1.0
	state["upgrades"] = {}
	state["crew"] = mini(int(state["crew"]), PortService.ship_stats(class_id).crew_max)
	return true
