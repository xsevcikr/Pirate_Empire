class_name CollisionModel
extends RefCounted
## Impact rules (spec section 11): energy from the reduced mass, damage by material, leaks, masts, crew overboard,
## floating cargo, grounding and docking too fast. Pure functions plus a seeded roll for the chance-based parts.

## Hull damage per unit of impact energy, by what was hit.
const MATERIAL: Dictionary = {"rock": 1.0, "reef": 0.7, "ship": 0.8, "dock": 0.5, "sand": 0.15, "ice": 0.9}
const ENERGY_PER_DAMAGE_J: float = 2000.0
const RAM_TAKEN_MULT: float = 0.7  ## the ram upgrade takes 30% less...
const RAM_DEALT_MULT: float = 1.5  ## ...and deals 150%
const LEAK_FRACTION: float = 0.10  ## a single hit above this share of hull HP opens a leak
const MAST_FRACTION: float = 0.25
const MAST_BREAK_CHANCE: float = 0.30
const OVERBOARD_PER_CREW: float = 0.02
const CRATE_CHANCE_PER_10T: float = 0.10
const SAND_STUCK_KN: float = 4.0  ## sand under this speed leaves the ship stuck
const ROCK_HOLE_KN: float = 6.0  ## rock above this tears a hole
const DOCK_MAX_KN: float = 3.0
const DOCK_FINE_GOLD: int = 50
const KEDGE_HOLD_S: float = 30.0
const LEAK_T_PER_S: float = 0.15  ## water taken in per second by a fresh impact leak
## Contacts weaker than this are just bumping, not collisions.
const MIN_DAMAGE: float = 1.0


## Mass that matters in a collision. Land (or anything with m2 <= 0) counts as infinite: all of the ship's mass.
static func reduced_mass(m1: float, m2: float) -> float:
	if m2 <= 0.0 or m1 <= 0.0:
		return maxf(m1, m2)
	return m1 * m2 / (m1 + m2)


static func impact_energy(m1: float, m2: float, v_rel: float) -> float:
	return 0.5 * reduced_mass(m1, m2) * v_rel * v_rel


static func hull_damage(energy: float, material: String, ram_dealt: bool = false, ram_taken: bool = false) -> float:
	var d: float = energy / ENERGY_PER_DAMAGE_J * float(MATERIAL[material])
	if ram_dealt:
		d *= RAM_DEALT_MULT
	if ram_taken:
		d *= RAM_TAKEN_MULT
	return d


## What a hit of `damage` does beyond hull damage. `rng` makes the chance-based results repeatable.
static func consequences(damage: float, hull_hp: float, crew_on_deck: int, cargo_t: float, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"leak": false, "mast_breaks": false, "overboard": 0, "crates": 0}
	if hull_hp <= 0.0 or damage < MIN_DAMAGE:
		return out
	var share: float = damage / hull_hp
	if share > LEAK_FRACTION:
		out["leak"] = true
	if share > MAST_FRACTION:
		out["mast_breaks"] = rng.randf() < MAST_BREAK_CHANCE
		for i in crew_on_deck:
			if rng.randf() < OVERBOARD_PER_CREW:
				out["overboard"] += 1
	if share > LEAK_FRACTION:
		for i in int(cargo_t / 10.0):
			if rng.randf() < CRATE_CHANCE_PER_10T:
				out["crates"] += 1
	return out


## What running aground does. `material` is what is under the bow, `speed_kn` the speed on contact.
static func grounding(material: String, speed_kn: float) -> String:
	if material == "sand":
		return "stuck" if speed_kn < SAND_STUCK_KN else "slide"
	if material == "rock" and speed_kn > ROCK_HOLE_KN:
		return "hole"
	return "bump"


## Rocks and reefs above the hole speed tear a hole: this much extra water per second, on top of damage.
static func hole_leak() -> float:
	return LEAK_T_PER_S * 2.0


## Docking faster than DOCK_MAX_KN hits the pier: damage to the dock and bow, and a fine.
static func dock_hit(speed_kn: float, ship_mass_kg: float) -> Dictionary:
	if speed_kn <= DOCK_MAX_KN:
		return {"hit": false, "dock_damage": 0.0, "bow_damage": 0.0, "fine": 0}
	var v: float = speed_kn * 0.5144
	var e: float = impact_energy(ship_mass_kg, 0.0, v)
	return {"hit": true, "dock_damage": hull_damage(e, "dock"), "bow_damage": hull_damage(e, "dock") * 0.5, "fine": DOCK_FINE_GOLD}


# ---- ship against ship: angle, scraping and hull breaches ------------------------------------------------------

## Where a ship is struck changes how much its hull gives. The stem and sternpost are the strongest timbers; the
## long flat side between them is where a ram goes through.
const ANGLE_BOW: float = 0.6  ## struck on the stem, as when ramming head-on
const ANGLE_BEAM: float = 1.3  ## struck square on the side (T-bone)
const SCRAPE_SHARE: float = 0.12  ## share of the sliding energy that a sideswipe turns into hull damage
const SCRAPE_MIN_MS: float = 1.0
## Breach sizes by the share of hull HP one impact took: none, small, medium, large.
const BREACH_SHARE: Array[float] = [0.0, 0.05, 0.16, 0.32]
## Water a breach lets in, tonnes per second, by size. A large hole sinks a sloop in about two minutes if nobody bails.
const BREACH_LEAK_T_PER_S: Array[float] = [0.0, 0.07, 0.17, 0.34]


## Hull factor for a ship struck along the local direction `toward_hit` (ship space, from its centre to the contact).
## 0.6 on the stem or stern, rising smoothly to 1.3 square on the side.
static func angle_factor(toward_hit: Vector3) -> float:
	var flat := Vector2(toward_hit.x, toward_hit.z)
	if flat.length() < 0.001:
		return 1.0
	var side: float = absf(flat.normalized().x)  # 0 = dead ahead or astern, 1 = abeam
	return lerpf(ANGLE_BOW, ANGLE_BEAM, side * side)


## Hull damage from two hulls grinding past each other at `v_slide` m/s along the contact.
static func scrape_damage(m1: float, m2: float, v_slide: float) -> float:
	if v_slide < SCRAPE_MIN_MS:
		return 0.0
	return impact_energy(m1, m2, v_slide) * SCRAPE_SHARE / ENERGY_PER_DAMAGE_J * float(MATERIAL["ship"])


## 0 = no breach, 1 small, 2 medium, 3 large, from the damage one impact did against the whole hull.
static func breach_size(damage: float, hull_hp: float) -> int:
	if hull_hp <= 0.0 or damage < MIN_DAMAGE:
		return 0
	var share: float = damage / hull_hp
	for size in range(BREACH_SHARE.size() - 1, 0, -1):
		if share >= BREACH_SHARE[size]:
			return size
	return 0


static func breach_leak(size: int) -> float:
	return BREACH_LEAK_T_PER_S[clampi(size, 0, BREACH_LEAK_T_PER_S.size() - 1)]


## Splits a contact into the push straight into the other hull and the slide along it. `rel` is our velocity
## relative to the other body and `n` the unit normal from us toward it (both flat).
static func split_contact(rel: Vector3, n: Vector3) -> Dictionary:
	var closing: float = maxf(rel.dot(n), 0.0)
	var slide: Vector3 = rel - n * rel.dot(n)
	slide.y = 0.0
	return {"closing": closing, "slide": slide.length()}
