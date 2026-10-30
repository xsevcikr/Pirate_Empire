class_name DestructionData
extends RefCounted
## Hit points and rules for forts and harbour buildings (spec section 11). Pure data plus the siege simulation
## the tests use to check that a frigate can breach a level 1 wall in about three broadsides.

## Fort wall HP by fort level 1..3, and how many segments it is cut into.
const WALL_HP: Array = BuildingData.DATA["fort_walls"]["wall_hp"]
const WALL_SEGMENTS: Array[int] = [8, 14, 20]  ## 8 to 20 segments, more for higher levels
const TOWER_HP: float = float(BuildingData.DATA["cannon_tower"]["hp"][0])
const GATE_HP: float = 3000.0
const HARBOUR_HP: Dictionary = {"dock": 400.0, "warehouse": 800.0, "crane": 300.0, "house": 250.0, "lighthouse": 1500.0}
const CRACK_AT: Array[float] = [0.66, 0.33]
const REBUILD_DAYS: float = 3.0
const REP_CIVILIAN: float = -5.0
const REP_FORT: float = -2.0
const BURN_S: float = 25.0
const BREACH_SEGMENTS: int = 3  ## adjacent wall segments gone: a gap a ship's crew can land through
const MAX_DEBRIS: int = 300
const RUBBLE_PIECES: int = 4

## How much of its damage a shot does to masonry and timber, by ammunition.
const SIEGE_FACTOR: Dictionary = {"round": 1.0, "chain": 0.05, "grape": 0.05, "heated": 1.0, "explosive": 1.4}
const KINDS_FORT: PackedStringArray = ["wall", "tower", "gate"]


static func segment_hp(level: int) -> float:
	return float(WALL_HP[level - 1]) / float(WALL_SEGMENTS[level - 1])


static func hp_of(kind: String, level: int = 1) -> float:
	match kind:
		"wall":
			return segment_hp(level)
		"tower":
			return TOWER_HP
		"gate":
			return GATE_HP
		_:
			return float(HARBOUR_HP[kind])


static func is_fort_part(kind: String) -> bool:
	return kind in KINDS_FORT


static func rep_cost(kind: String) -> float:
	return REP_FORT if is_fort_part(kind) else REP_CIVILIAN


## Crack stage of a building at `fraction` of its HP: 0 whole, 1 cracked, 2 badly cracked, 3 destroyed.
static func crack_stage(fraction: float) -> int:
	if fraction <= 0.0:
		return 3
	if fraction <= CRACK_AT[1]:
		return 2
	if fraction <= CRACK_AT[0]:
		return 1
	return 0


## Damage one shot does to a building.
static func shot_damage(gun_id: String, distance: float, ammo_id: String) -> float:
	return GunData.damage_at_range(gun_id, distance, ammo_id) * float(SIEGE_FACTOR[ammo_id])


## Broadsides of `guns` guns at a wall of `level`, each shot hitting one of the three segments being aimed at with
## `hit_chance`. Returns how many broadsides it took until BREACH_SEGMENTS adjacent segments are down (cap 12).
static func broadsides_to_breach(level: int, guns: int, gun_id: String, distance: float, hit_chance: float, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hp: PackedFloat32Array = PackedFloat32Array()
	for i in BREACH_SEGMENTS:
		hp.append(segment_hp(level))
	var dmg: float = shot_damage(gun_id, distance, "round")
	for b in range(1, 13):
		for g in guns:
			if rng.randf() < hit_chance:
				hp[rng.randi() % BREACH_SEGMENTS] -= dmg
		var down: bool = true
		for h in hp:
			if h > 0.0:
				down = false
		if down:
			return b
	return 12
