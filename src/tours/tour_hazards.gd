class_name TourHazards
extends RefCounted
## The voyage hazards of tours 3 to 6 as pure rules: moonlight, the ghost storm, the Ironhold blockade, the iceberg
## field and the Kraken's whirlpool. The world applies the numbers to the ship; nothing here touches a node.

const MOON_FROM_H: float = 21.0
const MOON_TO_H: float = 4.0
const GHOST_BOLT_EVERY_S: float = 20.0
const GHOST_BOLT_DAMAGE: float = 150.0
const GHOST_SLOOPS: int = 3
const PATROL_SIGHT_M: float = 600.0
const PATROL_SIGHT_NIGHT_M: float = 300.0
const PATROL_COUNT: int = 4
const BERG_COUNT: int = 14
const BERG_RADIUS_M: Array[float] = [18.0, 55.0]
const BERG_FIELD_M: float = 900.0
const WHIRL_RADIUS_M: float = 1400.0
const WHIRL_SWIRL_MS: float = 3.0
const WHIRL_INWARD_MS: float = 1.6
const WHIRL_CORE_M: float = 250.0
const FROST_STORM_MAST_DAMAGE: float = 1.0  ## 0 with frost-proof sails


static func moonlit(hour: float) -> bool:
	return hour >= MOON_FROM_H or hour < MOON_TO_H


## Only heated or blessed shot hurts a ghost.
static func ghost_hit(ammo: String) -> bool:
	return ammo == "heated" or ammo == "blessed"


## Hull damage a ghost storm does over `seconds` to a ship inside it.
static func ghost_storm_damage(seconds: float) -> float:
	return floorf(seconds / GHOST_BOLT_EVERY_S) * GHOST_BOLT_DAMAGE


## True when a patrol at `patrol` sees a ship at `ship`. Night halves the sight range.
static func patrol_sees(ship: Vector2, patrol: Vector2, night: bool) -> bool:
	return ship.distance_to(patrol) <= (PATROL_SIGHT_NIGHT_M if night else PATROL_SIGHT_M)


## Patrol positions ringed round an island, from a seeded rng.
static func patrols(centre: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var base: float = rng.randf() * TAU
	for i in PATROL_COUNT:
		var a: float = base + TAU * float(i) / float(PATROL_COUNT)
		out.append(centre + Vector2(cos(a), sin(a)) * 900.0)
	return out


## An iceberg field: positions and radii, never on top of the centre where the ship arrives.
static func icebergs(centre: Vector2, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while out.size() < BERG_COUNT:
		var p: Vector2 = centre + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * BERG_FIELD_M
		if p.distance_to(centre) < 200.0:
			continue
		out.append({"pos": p, "radius": rng.randf_range(BERG_RADIUS_M[0], BERG_RADIUS_M[1])})
	return out


## Whether the ship at `p` (radius `r`) touches a berg. The material of the contact is "ice".
static func berg_hit(p: Vector2, r: float, bergs: Array[Dictionary]) -> bool:
	for b in bergs:
		if p.distance_to(b["pos"] as Vector2) < r + float(b["radius"]):
			return true
	return false


## Whirlpool current at `p` in m/s: swirling round the centre and drawn inward, strongest near the core.
static func whirlpool(p: Vector2, centre: Vector2) -> Vector2:
	var d: float = p.distance_to(centre)
	if d > WHIRL_RADIUS_M or d < 1.0:
		return Vector2.ZERO
	var inward: Vector2 = (centre - p) / d
	var tangent := Vector2(-inward.y, inward.x)
	var k: float = 1.0 - d / WHIRL_RADIUS_M
	return tangent * WHIRL_SWIRL_MS * (0.4 + k) + inward * WHIRL_INWARD_MS * (0.3 + k)


## A ship that is inside the core is drawn under.
static func in_whirl_core(p: Vector2, centre: Vector2) -> bool:
	return p.distance_to(centre) <= WHIRL_CORE_M


## Sailing outward along the spiral: the best heading is outward turned a quarter turn against the swirl.
static func escape_heading(p: Vector2, centre: Vector2) -> Vector2:
	var out: Vector2 = (p - centre).normalized()
	var swirl: Vector2 = whirlpool(p, centre).normalized()
	return (out * 0.8 - swirl * 0.2).normalized() if swirl != Vector2.ZERO else out
