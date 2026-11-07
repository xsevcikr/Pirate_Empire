class_name Mooring
extends RefCounted
## Leaving the ship at a harbour: close to a pier and slow, F ties her up alongside and the captain walks ashore
## with his crew. Only the rules live here; the world moves the ship and opens the dock district.

const MAX_SPEED_KN: float = 3.0  ## same as docking with Space
const PIER_GAP_M: float = 1.2  ## between the pier's edge and the ship's side
const STERN_ON_PIER_M: float = 5.0  ## how far the stern lies along the planks, so the gangway reaches
const PIER_START_M: float = 6.0
const PARTY_MAX: int = 8  ## crew who come ashore with the captain; the rest stay aboard on watch


## Whether F can take the captain ashore here: in a harbour's dock zone (or off the lagoon's piers) and slow enough.
static func can_disembark(port_id: String, at_lagoon: bool, speed_kn: float) -> bool:
	return (port_id != "" or at_lagoon) and speed_kn <= MAX_SPEED_KN


## Why F does nothing yet, as a string key, or "" when it works or there is no harbour near.
static func blocked_reason(port_id: String, at_lagoon: bool, speed_kn: float) -> String:
	if port_id == "" and not at_lagoon:
		return ""
	return "moor.too_fast" if speed_kn > MAX_SPEED_KN else ""


## Where the ship lies while the captain is ashore: alongside the pier of `port_id`, her side a little off the
## planks, bow pointing out to sea so she can sail straight off, and her stern only a few metres along the pier so a
## big hull stays clear of the warehouses. Returns {pos: Vector2, yaw: float}.
static func berth(port_id: String, length_m: float, beam_m: float) -> Dictionary:
	var port: Dictionary = PortData.PORTS[port_id]
	var dock: Vector2 = port["dock"]
	var isl: Vector2 = PortData.gen().islands[port["island"]]["pos"]
	var to_island: Vector2 = (isl - dock).normalized()
	var side: Vector2 = Vector2(to_island.y, -to_island.x)  # starboard of the pier, looking at the island
	var out_to_sea: Vector2 = -to_island
	var along: float = length_m * 0.5 - STERN_ON_PIER_M - PIER_START_M  # the pier starts 6 m in from the dock point
	var pos: Vector2 = dock + side * (PortScene.PIER_WIDTH_M * 0.5 + PIER_GAP_M + beam_m * 0.5) + out_to_sea * along
	# the ship's forward is -z: yaw so that -basis.z points out to sea
	return {"pos": pos, "yaw": atan2(-out_to_sea.x, -out_to_sea.y)}


## The crew who come ashore, as roster types, in roster order; the captain is not in it.
static func shore_party(roster: Array) -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in roster:
		if out.size() >= PARTY_MAX:
			break
		out.append(str(m.get("type", "seasoned")))
	return out
