class_name CustomizationData
extends RefCounted
## Everything the captain can change about the look of the ship and themself, and the small bonuses some choices carry.

const EMBLEMS: Array[String] = [
	"skull", "crossbones", "cutlass", "anchor", "kraken", "crown", "dagger", "hourglass", "heart", "star", "moon", "sun",
	"wave", "wolf", "raven", "serpent", "rose", "dice", "key", "chest", "compass", "bell", "flame", "trident",
]
const FLAG_COLORS: Array[Color] = [
	Color(0.05, 0.05, 0.06), Color(0.7, 0.1, 0.1), Color(0.1, 0.2, 0.55), Color(0.95, 0.95, 0.92), Color(0.9, 0.75, 0.15),
	Color(0.1, 0.45, 0.2), Color(0.5, 0.15, 0.55), Color(0.9, 0.45, 0.1), Color(0.35, 0.35, 0.38), Color(0.4, 0.22, 0.1),
]
const FLAG_LAYOUTS: Array[String] = ["plain", "split", "cross", "border"]
const PIXEL_SIZE: int = 16
## The 16 colours of the pixel flag editor; a pixel stores an index into this list.
const PIXEL_PALETTE: Array[Color] = [
	Color(0, 0, 0, 0), Color(0.05, 0.05, 0.06), Color(0.95, 0.95, 0.92), Color(0.7, 0.1, 0.1), Color(0.9, 0.45, 0.1), Color(0.9, 0.75, 0.15),
	Color(0.1, 0.45, 0.2), Color(0.1, 0.2, 0.55), Color(0.5, 0.15, 0.55), Color(0.4, 0.22, 0.1), Color(0.35, 0.35, 0.38), Color(0.2, 0.6, 0.9),
	Color(0.9, 0.6, 0.7), Color(0.55, 0.8, 0.35), Color(0.6, 0.55, 0.4), Color(0.8, 0.2, 0.4),
]

const SAIL_PATTERNS: Array[String] = ["plain", "striped", "skull", "torn", "black"]
const SAIL_COLORS: Array[Color] = [
	Color(0.80, 0.76, 0.64), Color(0.95, 0.94, 0.9), Color(0.1, 0.1, 0.1), Color(0.7, 0.12, 0.1), Color(0.15, 0.25, 0.5), Color(0.8, 0.65, 0.2),
]
const HULL_PAINTS: Array[String] = ["natural", "tarred", "red", "blue", "green", "white"]
const HULL_PAINT_COLORS: Array[Color] = [
	Color(0.45, 0.3, 0.17), Color(0.12, 0.1, 0.09), Color(0.55, 0.12, 0.1), Color(0.14, 0.24, 0.45), Color(0.15, 0.35, 0.2), Color(0.85, 0.83, 0.78),
]
const TRIM_COLORS: Array[Color] = [Color(0.9, 0.75, 0.15), Color(0.95, 0.95, 0.92), Color(0.7, 0.1, 0.1), Color(0.05, 0.05, 0.06)]
const LANTERN_STYLES: Array[String] = ["none", "brass", "iron", "ghostly"]
const GOLD_LEAF_FAME: int = 2000
const FALSE_COLORS_REP_LOSS: float = 10.0

## Figureheads: ten, some with a small bonus (stat -> value).
const FIGUREHEADS: Dictionary = {
	"plain": {}, "mermaid": {}, "lion": {}, "eagle": {}, "wolf": {}, "dragon": {}, "angel": {}, "skeleton": {},
	"siren": {"morale_bonus": 10.0}, "kraken": {"monster_damage_mult": 0.95},
}
const FIGUREHEAD_ORDER: Array[String] = ["plain", "mermaid", "lion", "eagle", "wolf", "dragon", "angel", "skeleton", "siren", "kraken"]

## Pets: stat -> value.
const PETS: Dictionary = {
	"parrot": {"spot_time_mult": 0.9},
	"monkey": {"loot_mult": 1.05},
	"cat": {"food_duration_mult": 1.05},
}
const PET_ORDER: Array[String] = ["parrot", "monkey", "cat"]

## Captain looks: choices per slot. "cost" is gold at an outfitter; "achievement" earns it free.
const CAPTAIN_SLOTS: Dictionary = {
	"face": ["weathered", "scarred", "bearded", "young"],
	"hat": ["tricorn", "bandana", "bicorne", "feathered", "none"],
	"coat": ["plain", "navy_blue", "crimson", "leather", "gold_trim", "duelist"],
	"boots": ["worn", "buckled", "tall", "sandals"],
	"eye_patch": ["off", "on"],
	"peg_leg": ["off", "on"],
	"hook": ["off", "on"],
}
## Items not free from the start: slot/choice -> {"cost": gold} or {"achievement": id}.
const GATED: Dictionary = {
	"coat/crimson": {"cost": 600}, "coat/gold_trim": {"cost": 2500}, "hat/feathered": {"cost": 400},
	"boots/tall": {"cost": 300}, "coat/navy_blue": {"achievement": "first_blood"}, "hat/bicorne": {"achievement": "seasoned_captain"},
	"coat/leather": {"achievement": "prize_hunter"}, "coat/duelist": {"game": "knife"}, "boots/buckled": {"achievement": "well_off"},
}
const DEFAULT_CAPTAIN: Dictionary = {
	"face": "weathered", "hat": "tricorn", "coat": "plain", "boots": "worn", "eye_patch": "off", "peg_leg": "off", "hook": "off",
}
