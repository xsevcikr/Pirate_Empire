class_name Goods
extends RefCounted
## The twelve trade goods. Prices in gold per unit, weight in tonnes per unit.

const DATA: Dictionary = {
	"fish": {"name": "Fish and salt meat", "base": 8.0, "weight": 0.05, "legal": true},
	"sugar": {"name": "Sugar", "base": 20.0, "weight": 0.05, "legal": true},
	"rum": {"name": "Rum", "base": 28.0, "weight": 0.05, "legal": true},
	"tobacco": {"name": "Tobacco", "base": 35.0, "weight": 0.04, "legal": true},
	"timber": {"name": "Timber and pitch", "base": 14.0, "weight": 0.1, "legal": true},
	"gunpowder": {"name": "Gunpowder", "base": 45.0, "weight": 0.05, "legal": false},
	"iron": {"name": "Iron and cannon parts", "base": 60.0, "weight": 0.1, "legal": false},
	"spices": {"name": "Spices", "base": 90.0, "weight": 0.02, "legal": true},
	"silk": {"name": "Silk and cloth", "base": 120.0, "weight": 0.02, "legal": true},
	"tea": {"name": "Tea and coffee", "base": 70.0, "weight": 0.03, "legal": true},
	"gems": {"name": "Gems", "base": 400.0, "weight": 0.005, "legal": true},
	"contraband": {"name": "Contraband", "base": 260.0, "weight": 0.01, "legal": false},
}

## Goods that war raises by 40%, plague by 60% (rum), and so on.
const EVENT_GOODS: Dictionary = {
	"war": ["gunpowder", "iron"],
	"plague": ["rum"],
	"blockade": [],  # all goods
	"festival": ["rum", "tobacco"],
	"famine": ["fish"],
}
const EVENT_MULT: Dictionary = {"war": 1.4, "plague": 1.6, "blockade": 1.5, "festival": 1.25, "famine": 1.8}


static func ids() -> Array:
	return DATA.keys()


static func base_price(id: String) -> float:
	return DATA[id]["base"]
