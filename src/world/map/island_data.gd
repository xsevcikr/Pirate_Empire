class_name IslandData
extends RefCounted
## The 24 hand-named islands of the Ashen Archipelago, in the order WorldGen places them within each region,
## and the look of each biome. `city` is empty for islands without a harbour.

## region -> list of {name, city, tier, biome, note}. Haven Rock is always the first island overall.
const BY_REGION: Dictionary = {
	"haven_waters": [
		{"name": "Haven Rock", "city": "Blackwater Town", "tier": "capital", "biome": "rocky", "note": "pirate capital"},
		{"name": "Gallows Key", "city": "Gallows Cove", "tier": "town", "biome": "tropical", "note": "smuggler port"},
		{"name": "Brimstone Isle", "city": "Sulphur Landing", "tier": "village", "biome": "volcanic", "note": "sulphur village"},
		{"name": "Skull Atoll", "city": "", "tier": "", "biome": "tropical", "note": "hidden cove"},
	],
	"albion_shallows": [
		{"name": "Port Regal", "city": "Port Regal", "tier": "capital", "biome": "temperate", "note": "navy capital, star fort, admiralty"},
		{"name": "Fort Sterling", "city": "Fort Sterling", "tier": "town", "biome": "temperate", "note": "garrison town"},
		{"name": "Kingsbridge", "city": "Kingsbridge", "tier": "town", "biome": "tropical", "note": "market town"},
		{"name": "Admiralty Rock", "city": "", "tier": "", "biome": "rocky", "note": "prison island"},
	],
	"merchants_reach": [
		{"name": "Saint Marguerite", "city": "Saint Marguerite", "tier": "capital", "biome": "temperate", "note": "trade capital, bank, insurance"},
		{"name": "Goldharbor", "city": "Goldharbor", "tier": "city", "biome": "temperate", "note": "counting houses"},
		{"name": "Pepperpoint", "city": "Pepperpoint", "tier": "town", "biome": "tropical", "note": "plantation town"},
		{"name": "Silkwater", "city": "Silkwater", "tier": "village", "biome": "jungle", "note": "weavers' village"},
	],
	"coral_isles": [
		{"name": "Tavai Lagoon", "city": "Tavai Lagoon", "tier": "city", "biome": "lagoon", "note": "stilt city on a lagoon"},
		{"name": "Pearlhome", "city": "Pearlhome", "tier": "town", "biome": "tropical", "note": "pearl divers"},
		{"name": "Turtle Cay", "city": "Turtle Cay", "tier": "village", "biome": "tropical", "note": "fishing village"},
		{"name": "Moana Reef", "city": "", "tier": "", "biome": "lagoon", "note": "sunken temple (tour 2)"},
	],
	"iron_marches": [
		{"name": "Ironhold", "city": "Ironhold", "tier": "capital", "biome": "rocky", "note": "fortress capital, foundries"},
		{"name": "Cinder Bay", "city": "", "tier": "", "biome": "volcanic", "note": "volcano (tour 4)"},
		{"name": "Forgefall", "city": "Forgefall", "tier": "town", "biome": "rocky", "note": "mining town"},
		{"name": "Ashport", "city": "Ashport", "tier": "town", "biome": "volcanic", "note": "coal port"},
	],
	"dead_reach": [
		{"name": "Wraith Isle", "city": "", "tier": "", "biome": "ruined", "note": "ruined chapel (tour 3)"},
		{"name": "Bonefield Shoals", "city": "", "tier": "", "biome": "rocky", "note": "shipwreck reef"},
		{"name": "Frostmourn", "city": "", "tier": "", "biome": "ice", "note": "ice island, glaciers"},
		{"name": "Kraken's Maw", "city": "", "tier": "", "biome": "ruined", "note": "whirlpool atoll (final tour)"},
	],
}

## Palette and planting per biome: sand, grass, forest, rock colours; whether palms/bushes grow; density 0..1.
const BIOMES: Dictionary = {
	"rocky": {"sand": Color(0.62, 0.58, 0.5), "grass": Color(0.3, 0.38, 0.2), "forest": Color(0.2, 0.3, 0.16), "rock": Color(0.42, 0.4, 0.38), "palms": false, "bushes": true, "density": 0.35},
	"tropical": {"sand": Color(0.86, 0.78, 0.56), "grass": Color(0.24, 0.46, 0.17), "forest": Color(0.12, 0.34, 0.12), "rock": Color(0.4, 0.37, 0.33), "palms": true, "bushes": true, "density": 1.0},
	"jungle": {"sand": Color(0.7, 0.62, 0.42), "grass": Color(0.14, 0.38, 0.12), "forest": Color(0.07, 0.26, 0.08), "rock": Color(0.34, 0.33, 0.3), "palms": true, "bushes": true, "density": 1.0},
	"volcanic": {"sand": Color(0.25, 0.23, 0.22), "grass": Color(0.28, 0.22, 0.18), "forest": Color(0.2, 0.15, 0.12), "rock": Color(0.16, 0.14, 0.14), "palms": false, "bushes": false, "density": 0.2},
	"temperate": {"sand": Color(0.82, 0.76, 0.58), "grass": Color(0.34, 0.5, 0.2), "forest": Color(0.18, 0.36, 0.14), "rock": Color(0.44, 0.42, 0.38), "palms": false, "bushes": true, "density": 0.8},
	"lagoon": {"sand": Color(0.94, 0.9, 0.74), "grass": Color(0.3, 0.55, 0.28), "forest": Color(0.14, 0.4, 0.2), "rock": Color(0.5, 0.48, 0.44), "palms": true, "bushes": true, "density": 0.9},
	"ice": {"sand": Color(0.85, 0.9, 0.95), "grass": Color(0.78, 0.86, 0.92), "forest": Color(0.66, 0.76, 0.86), "rock": Color(0.7, 0.8, 0.9), "palms": false, "bushes": false, "density": 0.0},
	"ruined": {"sand": Color(0.5, 0.48, 0.44), "grass": Color(0.3, 0.34, 0.26), "forest": Color(0.2, 0.24, 0.2), "rock": Color(0.36, 0.35, 0.36), "palms": false, "bushes": false, "density": 0.15},
}

## Faction look of a harbour: wall, roof and flag colours.
const STYLES: Dictionary = {
	"pirate": {"wall": Color(0.3, 0.2, 0.13), "roof": Color(0.16, 0.1, 0.08), "flag": Color(0.05, 0.05, 0.05)},
	"navy": {"wall": Color(0.82, 0.8, 0.74), "roof": Color(0.18, 0.28, 0.5), "flag": Color(0.15, 0.25, 0.6)},
	"merchant": {"wall": Color(0.78, 0.66, 0.42), "roof": Color(0.55, 0.22, 0.12), "flag": Color(0.8, 0.65, 0.15)},
	"reef_folk": {"wall": Color(0.62, 0.5, 0.32), "roof": Color(0.7, 0.62, 0.3), "flag": Color(0.1, 0.55, 0.55)},
	"iron_dominion": {"wall": Color(0.3, 0.3, 0.32), "roof": Color(0.12, 0.12, 0.14), "flag": Color(0.7, 0.15, 0.1)},
	"none": {"wall": Color(0.45, 0.44, 0.42), "roof": Color(0.25, 0.25, 0.25), "flag": Color(0.4, 0.4, 0.4)},
}

## Economy of the cities that are not hand-tuned in PortData. Keys are city names.
const ECONOMY: Dictionary = {
	"Gallows Cove": {"producer": ["tobacco"], "consumer": ["rum", "iron"]},
	"Sulphur Landing": {"producer": ["timber"], "consumer": ["sugar", "rum"]},
	"Fort Sterling": {"producer": [], "consumer": ["gunpowder", "rum", "fish"]},
	"Kingsbridge": {"producer": ["tobacco"], "consumer": ["spices", "silk", "rum"]},
	"Goldharbor": {"producer": ["silk"], "consumer": ["sugar", "timber", "tea"]},
	"Pepperpoint": {"producer": ["spices", "sugar"], "consumer": ["iron", "rum"]},
	"Silkwater": {"producer": ["silk", "timber"], "consumer": ["fish", "tea"]},
	"Pearlhome": {"producer": ["fish", "tea"], "consumer": ["iron", "rum"]},
	"Turtle Cay": {"producer": ["fish"], "consumer": ["rum", "timber"]},
	"Forgefall": {"producer": ["iron"], "consumer": ["fish", "rum", "timber"]},
	"Ashport": {"producer": ["timber"], "consumer": ["tobacco", "fish"]},
}

## City name -> the id the economy already uses for it.
const LEGACY_IDS: Dictionary = {
	"Blackwater Town": "blackwater", "Saint Marguerite": "meridian", "Port Regal": "albion", "Ironhold": "ironhold", "Tavai Lagoon": "coral_landing",
}

const TIER_STATS: Dictionary = {
	"village": {"target": 60.0, "tavern": 1, "yard": 1},
	"town": {"target": 80.0, "tavern": 1, "yard": 1},
	"city": {"target": 100.0, "tavern": 2, "yard": 2},
	"capital": {"target": 120.0, "tavern": 3, "yard": 3},
}


static func entries_for(region: String) -> Array:
	return BY_REGION.get(region, [])


static func port_id_of(city: String) -> String:
	return LEGACY_IDS.get(city, city.to_lower().replace(" ", "_").replace("'", ""))


static func biome(name: String) -> Dictionary:
	return BIOMES.get(name, BIOMES["tropical"])


static func style(faction: String) -> Dictionary:
	return STYLES.get(faction, STYLES["none"])
