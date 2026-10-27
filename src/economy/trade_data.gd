class_name TradeData
extends RefCounted
## Numbers for the living economy (spec section 7): convoys, blockades, inspections, fences, bank, insurance, defeat.

# ---- convoys ----
const CONVOY_INTERVAL_H: float = 12.0
const CONVOY_SHIPS: Array[int] = [2, 5]  ## min, max merchant ships
const CONVOY_ESCORTS: Array[int] = [0, 2]
const UNITS_PER_SHIP: float = 25.0  ## market units of cargo one merchant carries
const CONVOY_SPEED_KN: float = 7.0
const M_PER_KN_H: float = 1852.0
const CONVOY_ARRIVAL_STOCK_CAP: float = 3.0  ## stock never exceeds this multiple of target
const CONVOY_SPAWN_RANGE_M: float = 900.0  ## real ships appear when the player is this close to a convoy
const CONVOY_STATS: Array[String] = ["lugger", "sloop", "schooner"]
const ESCORT_STATS: String = "sloop"

# ---- blockade ----
const BLOCKADE_RADIUS_M: float = 1500.0
const BLOCKADE_HOURS: float = 24.0
const BLOCKADE_EVENT_H: float = 48.0
const BLOCKADE_REP: float = -10.0
const BUILDING_STOCK_CUT: float = 0.2  ## per destroyed harbour building
const BUILDING_STOCK_DAYS: float = 3.0

# ---- inspections ----
const INSPECT_BASE: float = 0.10
const INSPECT_PER_STAR: float = 0.05
const INSPECT_NIGHT_MULT: float = 0.8  ## "-20% at night", read as a relative cut
const INSPECT_SMUGGLER_MULT: float = 0.5
const NIGHT_START_H: float = 20.0
const NIGHT_END_H: float = 5.0
const FINE_MULT: float = 2.0
const FINE_REP: float = -5.0
const BRIBE_FRACTION: float = 0.30
const BRIBE_SUCCESS: float = 0.60
const BRIBE_LEADERSHIP_BONUS: float = 0.15
const BRIBE_LEADERSHIP_RANK: int = 3
const FIGHT_REP_CAP: float = -40.0  ## the port turns hostile
const FIGHT_BOUNTY: float = 10.0
const FENCE_MULT: float = 1.5
const BLACK_MARKET_MULT: float = 1.0

# ---- bank, insurance, defeat ----
const BANK_INTEREST_PER_WEEK: float = 0.01
const INSURANCE_PREMIUM: float = 0.10  ## of the ship's list price
const DEFEAT_GOLD_LOSS: float = 0.5
const DEFEAT_CREW_LOSS: float = 0.3
const DEFEAT_START_CLASS: String = "cutter"
const INSURED_HULL: float = 0.3

# ---- standing shown on screen (price effect on the player) ----
const REP_MOD: Dictionary = {"hated": -0.15, "hostile": -0.08, "neutral": 0.0, "friendly": 0.05, "allied": 0.10}
