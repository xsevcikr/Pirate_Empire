class_name BuildingData
extends RefCounted
## Base buildings. Level arrays are indexed level-1. income/upkeep are gold per in-game day.

const DATA: Dictionary = {
	"dock": {"plots": 2, "cost": [1500, 5000, 14000], "days": [2, 4, 7], "income": [0, 0, 0], "upkeep": [10, 30, 60], "berths": [1, 3, 5]},
	"shipyard": {"plots": 4, "cost": [6000, 18000, 45000], "days": [4, 8, 14], "income": [0, 0, 0], "upkeep": [40, 90, 160]},
	"tavern": {"plots": 2, "cost": [1200, 4000, 11000], "days": [2, 4, 6], "income": [40, 90, 170], "upkeep": [0, 0, 0]},
	"market": {"plots": 3, "cost": [3000, 9000, 24000], "days": [3, 6, 10], "income": [80, 220, 480], "upkeep": [0, 0, 0], "storage_t": [200, 600, 1500]},
	"plantation": {"plots": 4, "cost": [4000], "days": [5], "income": [300], "upkeep": [0]},
	"distillery": {"plots": 3, "cost": [5500], "days": [5], "income": [420], "upkeep": [0]},
	"mine": {"plots": 4, "cost": [8000], "days": [7], "income": [500], "upkeep": [0]},
	"fort_walls": {"plots": 3, "cost": [3500, 10000, 28000], "days": [3, 6, 10], "income": [0, 0, 0], "upkeep": [50, 120, 250], "wall_hp": [4000, 9000, 20000], "garrison_cap": [40, 100, 200]},
	"cannon_tower": {"plots": 1, "cost": [2000, 4500], "days": [2, 2], "income": [0, 0], "upkeep": [25, 25], "hp": [1800, 1800], "guns": [6, 6], "range_m": [450, 450]},
	"lighthouse": {"plots": 1, "cost": [3500], "days": [3], "income": [0], "upkeep": [10]},
	"smuggler_market": {"plots": 3, "cost": [7500], "days": [5], "income": [250], "upkeep": [0]},
	"barracks": {"plots": 3, "cost": [6000], "days": [4], "income": [0], "upkeep": [60]},
	"hidden_cove": {"plots": 2, "cost": [4500], "days": [4], "income": [0], "upkeep": [15]},
	"shrine": {"plots": 1, "cost": [9000], "days": [3], "income": [0], "upkeep": [0]},
}

const BASE_TIERS: Dictionary = {
	"outpost": {"plots": 12, "active_buildings": 2, "upgrade_cost": 15000},
	"stronghold": {"plots": 24, "active_buildings": 99, "upgrade_cost": 60000},
	"fortress_capital": {"plots": 36, "active_buildings": 99, "upgrade_cost": 0},
}
const RUSH_GOLD_PER_HOUR: float = 40.0
const ACCRUAL_CAP_DAYS: float = 7.0
const MAX_BASES: int = 6


static func levels(type: String) -> int:
	return (DATA[type]["cost"] as Array).size()


static func cost(type: String, level: int) -> int:
	return DATA[type]["cost"][level - 1]


static func days(type: String, level: int) -> int:
	return DATA[type]["days"][level - 1]


static func income(type: String, level: int) -> int:
	return DATA[type]["income"][level - 1]


static func upkeep(type: String, level: int) -> int:
	return DATA[type]["upkeep"][level - 1]


static func plots(type: String) -> int:
	return DATA[type]["plots"]
