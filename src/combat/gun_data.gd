class_name GunData
extends RefCounted
## Cannon and ammunition tables (spec section 5).

## damage per ball, muzzle velocity m/s, effective range m, max range m, reload s, spread deg, weight t, price g
const GUNS: Dictionary = {
	"6pdr": {"damage": 40.0, "velocity": 330.0, "effective": 200.0, "max": 420.0, "reload": 6.0, "spread": 1.6, "weight": 0.8, "price": 300},
	"12pdr": {"damage": 70.0, "velocity": 320.0, "effective": 260.0, "max": 520.0, "reload": 8.0, "spread": 1.4, "weight": 1.4, "price": 900},
	"24pdr": {"damage": 120.0, "velocity": 300.0, "effective": 320.0, "max": 600.0, "reload": 11.0, "spread": 1.3, "weight": 2.6, "price": 2400},
	"32pdr": {"damage": 160.0, "velocity": 290.0, "effective": 340.0, "max": 640.0, "reload": 13.5, "spread": 1.5, "weight": 3.2, "price": 4000},
	"carronade": {"damage": 150.0, "velocity": 220.0, "effective": 140.0, "max": 280.0, "reload": 7.5, "spread": 2.6, "weight": 1.2, "price": 1800},
	"long9": {"damage": 55.0, "velocity": 360.0, "effective": 380.0, "max": 700.0, "reload": 7.0, "spread": 0.9, "weight": 1.4, "price": 1500},
}

## hull/sail/crew damage multipliers, range multiplier, fire chance per hull hit, cost per 10 shots
const AMMO: Dictionary = {
	"round": {"hull": 1.0, "sail": 0.25, "crew": 0.10, "range": 1.0, "fire": 0.0, "cost": 20, "rigging": 0.15},
	"chain": {"hull": 0.15, "sail": 2.0, "crew": 0.15, "range": 0.7, "fire": 0.0, "cost": 45, "rigging": 0.7},
	"grape": {"hull": 0.10, "sail": 0.40, "crew": 3.0, "range": 0.5, "fire": 0.0, "cost": 35, "rigging": 0.1},
	"heated": {"hull": 0.70, "sail": 0.50, "crew": 0.10, "range": 0.9, "fire": 0.25, "cost": 60, "rigging": 0.15},
	"explosive": {"hull": 1.40, "sail": 0.60, "crew": 0.50, "range": 0.8, "fire": 0.0, "cost": 120, "rigging": 0.15},
}
const AMMO_ORDER: PackedStringArray = ["round", "chain", "grape", "heated", "explosive"]

const MAX_ELEVATION_DEG: float = 12.0
const MIN_ELEVATION_DEG: float = -5.0


static func damage_at_range(gun_id: String, distance: float, ammo_id: String = "round") -> float:
	var g: Dictionary = GUNS[gun_id]
	var max_r: float = g["max"] * AMMO[ammo_id]["range"]
	var eff_r: float = g["effective"] * AMMO[ammo_id]["range"]
	var base: float = g["damage"]
	if distance <= eff_r:
		return base
	if distance >= max_r:
		return base * 0.4
	return base * lerpf(1.0, 0.4, inverse_lerp(eff_r, max_r, distance))


## Gravity used for cannonballs so a ball fired at 12 degrees reaches the gun's max range.
static func shot_gravity(gun_id: String) -> float:
	var g: Dictionary = GUNS[gun_id]
	return g["velocity"] * g["velocity"] * sin(deg_to_rad(2.0 * MAX_ELEVATION_DEG)) / g["max"]
