class_name LagoonData
extends RefCounted
## The player's own pirate lagoon on Skull Atoll: the build grid, the buildings and their levels, the four lagoon
## ranks and the piers of the harbour. Level arrays are indexed level-1; gold and food are per in-game day.

const ISLAND: String = "Skull Atoll"
const CLAIM_COST: int = 1500
const CELL_M: float = 14.0  ## one building plot
const PAD_H_M: float = 4.0  ## height of the levelled ground the lagoon is built on
const PAD_RADIUS_M: float = 92.0
const PAD_BLEND_M: float = 40.0
const PAD_OFFSET: float = 0.3  ## the pad sits this fraction of the island radius towards the harbour side
const DOCK_RADIUS_M: float = 90.0  ## the player can land anywhere this close to the pier heads
const DOCK_OFFSHORE_M: float = 70.0
const TRIBUTE_PER_RESIDENT: float = 3.0  ## gold a day each pirate living in the lagoon pays into the chest
const CHEST_BASE: float = 1500.0  ## what the chest holds before warehouses
const DEMOLISH_REFUND: float = 0.5
const REPAIR_SHARE: float = 0.3  ## repairing a raided building costs this share of its level's price
const SELL_SHARE: float = 0.4  ## a fleet ship sold at the lagoon fetches this share of its price
const RAID_CHANCE: float = 0.05  ## per day, from the second rank up
const RAID_STRENGTH_PER_RANK: float = 70.0
const RAID_CHEST_LOSS: float = 0.5
const HULL_REPAIR_PER_DAY: float = 0.1  ## moored ships mend this much hull a day per shipyard level
const MAX_VILLAGERS: int = 28  ## people drawn walking about, however many live there
const GUN_DEFENCE: float = 4.0  ## defence per gun on a broadside of a moored ship

## Ranks of the lagoon: the plot radius (in cells), how many piers can be built, and the price of reaching it.
const RANKS: Array[Dictionary] = [
	{"id": "hideout", "extent": 2, "piers": 1, "cost": 0},
	{"id": "cove", "extent": 3, "piers": 2, "cost": 4000},
	{"id": "haven", "extent": 4, "piers": 4, "cost": 15000},
	{"id": "capital", "extent": 5, "piers": 6, "cost": 40000},
]

## Every building that goes on a plot. Stats per level: beds (pirates who can live there), income, morale (on
## landing), defence, storage (chest room), food (into the larder), repair (shipyard level for the fleet),
## heal (wounded tended on landing), ships (the shipyard's top class index). `deco` items are cheap one-level props.
const BUILDINGS: Dictionary = {
	"hut": {"cost": [300, 1000, 2800], "beds": [4, 8, 14]},
	"tavern": {"cost": [1200, 3500, 8000], "income": [30, 70, 140], "morale": [4, 7, 10], "heal": [1, 3, 6]},
	"market": {"cost": [1500, 4000, 9000], "income": [60, 150, 320]},
	"warehouse": {"cost": [1000, 3000, 7000], "storage": [2000, 5000, 12000], "income": [10, 25, 50]},
	"shipyard": {"cost": [2500, 8000, 20000], "repair": [1, 2, 3], "ships": [2, 4, 99]},
	"tower": {"cost": [1200, 3500, 9000], "defence": [40, 90, 160]},
	"battery": {"cost": [2000, 5000], "defence": [70, 150]},
	"farm": {"cost": [800, 2200], "food": [4, 10], "beds": [1, 2]},
	"campfire": {"cost": [150], "morale": [2], "deco": true},
	"flagpole": {"cost": [250], "morale": [2], "deco": true},
	"lanterns": {"cost": [120], "morale": [1], "deco": true},
	"palms": {"cost": [80], "morale": [1], "deco": true},
	"well": {"cost": [600], "morale": [2], "food": [1], "deco": true},
	"treasure": {"cost": [2500], "morale": [4], "deco": true},
	"statue": {"cost": [5000], "morale": [6], "deco": true},
}
const ORDER: Array[String] = ["hut", "tavern", "market", "warehouse", "shipyard", "farm", "tower", "battery", "campfire", "flagpole", "lanterns", "palms", "well", "treasure", "statue"]

## Housing bought at the harbour office: beds on top of the huts, so more pirates can live in the lagoon.
const HOUSING: Dictionary = {"cost": [2000, 6000, 15000, 35000], "beds": [10, 25, 45, 70]}

## Piers: how many ships each moors and how far it reaches out from the beach.
const PIER: Dictionary = {"cost": [1200, 3500, 8000], "berths": [1, 2, 3], "length_m": [34.0, 50.0, 66.0]}
## Bearings of the pier slots either side of the harbour line, in order of building.
const PIER_BEARINGS: Array[float] = [-0.14, 0.14, -0.42, 0.42, -0.7, 0.7]


static func levels(type: String) -> int:
	return (BUILDINGS[type]["cost"] as Array).size()


static func cost(type: String, level: int) -> int:
	return int(BUILDINGS[type]["cost"][level - 1])


## A stat of one building at a level, 0 when the building does not have it.
static func stat(type: String, level: int, key: String) -> float:
	var arr: Array = BUILDINGS[type].get(key, [])
	if arr.is_empty():
		return 0.0
	return float(arr[mini(level, arr.size()) - 1])


static func is_deco(type: String) -> bool:
	return bool(BUILDINGS[type].get("deco", false))


static func rank(index: int) -> Dictionary:
	return RANKS[clampi(index, 0, RANKS.size() - 1)]


static func pier_cost(level: int) -> int:
	return int(PIER["cost"][level - 1])


static func pier_levels() -> int:
	return (PIER["cost"] as Array).size()


## Plot cells open at a rank: inside the rank's radius, the centre kept for the captain's hall.
static func cells(rank_index: int) -> Array[Vector2i]:
	var e: int = int(rank(rank_index)["extent"])
	var out: Array[Vector2i] = []
	for y in range(-e, e + 1):
		for x in range(-e, e + 1):
			if (x != 0 or y != 0) and Vector2(x, y).length() <= float(e) + 0.5:
				out.append(Vector2i(x, y))
	return out


static func cell_open(rank_index: int, c: Vector2i) -> bool:
	return (c.x != 0 or c.y != 0) and Vector2(c.x, c.y).length() <= float(rank(rank_index)["extent"]) + 0.5


# ---- where things are on the island ---------------------------------------------------------------------

static func island_index() -> int:
	return PortData.gen().index_of(ISLAND)


static func island() -> Dictionary:
	return PortData.gen().islands[island_index()]


## Direction from the atoll to Haven Rock: the harbour faces home.
static func harbour_dir() -> Vector2:
	var to: Vector2 = -(island()["pos"] as Vector2)
	return to.normalized() if to.length() > 1.0 else Vector2(0, -1)


## Island-local centre of the levelled build ground.
static func pad_center() -> Vector2:
	return harbour_dir() * float(island()["radius"]) * PAD_OFFSET


## Island-local centre of a plot. Seen from the harbour looking inland, +x runs to the right and +y away from the sea.
static func cell_local(c: Vector2i) -> Vector2:
	var fwd: Vector2 = harbour_dir()
	return pad_center() + cell_right() * (c.x * CELL_M) + fwd * (-c.y * CELL_M)


static func cell_right() -> Vector2:
	var fwd: Vector2 = harbour_dir()
	return Vector2(fwd.y, -fwd.x)


## The plot under an island-local point (it may be closed).
static func cell_at(local: Vector2) -> Vector2i:
	var d: Vector2 = local - pad_center()
	return Vector2i(roundi(d.dot(cell_right()) / CELL_M), roundi(-d.dot(harbour_dir()) / CELL_M))


## Yaw (degrees) that makes a building face the harbour.
static func facing_yaw() -> float:
	var f: Vector2 = harbour_dir()
	return rad_to_deg(atan2(f.x, f.y))


## World position offshore of the piers, where the player lands.
static func dock_point() -> Vector2:
	var isl: Dictionary = island()
	return (isl["pos"] as Vector2) + harbour_dir() * (float(isl["radius"]) + DOCK_OFFSHORE_M)


static func near_dock(p: Vector2) -> bool:
	return p.distance_to(dock_point()) <= DOCK_RADIUS_M


## Bearing (radians, island-local) of a pier slot.
static func pier_angle(slot: int) -> float:
	return harbour_dir().angle() + PIER_BEARINGS[slot]


## True where trees, rocks and camps must not grow: the build ground and the strip down to the piers.
static func keep_clear(local: Vector2) -> bool:
	if local.distance_to(pad_center()) < PAD_RADIUS_M + 12.0:
		return true
	var fwd: Vector2 = harbour_dir()
	var along: float = local.dot(fwd)
	var side: float = absf(local.dot(Vector2(-fwd.y, fwd.x)))
	return along > float(island()["radius"]) * PAD_OFFSET and side < float(island()["radius"]) * 0.75
