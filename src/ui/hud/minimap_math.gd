class_name MinimapMath
extends RefCounted
## Maths of the corner minimap, kept apart from the drawing so it can be tested: the map is north-up and centred
## on the ship, world x east and z south become screen x right and y down.

const RANGES_M: Array[float] = [800.0, 1500.0, 3000.0, 6000.0]  ## the radius the map shows, zoomed with + and -
const ISLAND_MIN_PX: float = 13.0  ## islands are drawn at least this big (in radius) so they read as land, not dots
const ISLAND_MAX_GROW: float = 3.0
const SHIP_COLOURS: Dictionary = {
	"player": Color(1.0, 0.95, 0.75),
	"pirate": Color(0.85, 0.2, 0.15),
	"navy": Color(0.3, 0.5, 1.0),
	"merchant": Color(0.95, 0.8, 0.25),
	"reef_folk": Color(0.2, 0.8, 0.75),
	"iron_dominion": Color(0.75, 0.75, 0.8),
}
const OTHER_SHIP: Color = Color(0.8, 0.45, 0.9)  ## rival crews and anything without a colour of its own


## A world point as an offset in pixels from the centre of the map.
static func to_map(world: Vector2, centre: Vector2, range_m: float, radius_px: float) -> Vector2:
	return (world - centre) / range_m * radius_px


## True when a circle of `r_px` at `offset` shows at least partly inside the map.
static func touches(offset: Vector2, r_px: float, radius_px: float) -> bool:
	return offset.length() - r_px < radius_px


## A marker beyond the rim pulled onto it, so a far place still shows its bearing.
static func pin_to_rim(offset: Vector2, radius_px: float, inset_px: float) -> Vector2:
	var limit: float = radius_px - inset_px
	if offset.length() <= limit:
		return offset
	return offset.normalized() * limit


static func next_range(i: int) -> int:
	return (i + 1) % RANGES_M.size()


## Where home is: the lagoon harbour on Skull Atoll, the player's base whether or not it is claimed yet.
static func home_pos() -> Vector2:
	return LagoonData.dock_point()


static func ship_colour(faction: String) -> Color:
	return SHIP_COLOURS.get(faction, OTHER_SHIP)


## Distance and eight-point bearing from `from` to `to`, e.g. "3.2 km NE".
static func bearing_text(from: Vector2, to: Vector2) -> String:
	var d: Vector2 = to - from
	var names: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var deg: float = fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)
	return "%.1f km %s" % [d.length() / 1000.0, names[int(round(deg / 45.0)) % 8]]


## How much bigger than life an island is drawn so that it reads on a small chart: never smaller than
## ISLAND_MIN_PX in radius, never more than ISLAND_MAX_GROW times its size.
static func island_grow(radius_px: float) -> float:
	return clampf(ISLAND_MIN_PX / maxf(radius_px, 0.001), 1.0, ISLAND_MAX_GROW)
