class_name WeatherRules
extends RefCounted
## Weather and storm rules as pure functions: what each weather looks like, how hard the wind blows, and what a
## lightning strike or a breaking sea does to a ship. A storm only hurts a ship through a hit you can see coming (a
## lightning strike after St Elmo's fire, a big sea after the lookout's call) and never by chance alone. Storm hits
## stop at STORM_HULL_FLOOR of every hull section, so they never open a breach and a storm alone can never sink you.

## Per weather: wind (kn the wind settles toward), clouds (0..1 cover), dim (0..1 how much daylight is lost),
## fog (multiplier on the fog density), rain (0..1), storm (0..1, lightning and big seas), sight (0..1 how far a
## lookout sees, multiplied into the AI's detect range).
const PROFILES: Dictionary = {
	"clear": {"wind": 14.0, "clouds": 0.5, "dim": 0.0, "fog": 1.0, "rain": 0.0, "storm": 0.0, "sight": 1.0},
	"overcast": {"wind": 18.0, "clouds": 0.8, "dim": 0.25, "fog": 1.5, "rain": 0.0, "storm": 0.0, "sight": 0.9},
	"rain": {"wind": 21.0, "clouds": 0.92, "dim": 0.4, "fog": 2.4, "rain": 0.6, "storm": 0.0, "sight": 0.7},
	"storm": {"wind": 31.0, "clouds": 1.0, "dim": 0.65, "fog": 3.2, "rain": 1.0, "storm": 1.0, "sight": 0.55},
	"fog": {"wind": 7.0, "clouds": 0.6, "dim": 0.3, "fog": 9.0, "rain": 0.0, "storm": 0.0, "sight": 0.4},
}
const BLEND_S: float = 40.0  ## real seconds for one weather to turn into the next
const WIND_KN_PER_S: float = 0.6  ## how fast the wind speed follows the weather

## Night: how far a lookout sees by night, and the sun height (sin of elevation) where night is total.
const NIGHT_SIGHT: float = 0.6

## Lightning: a strike every LIGHTNING_EVERY_S seconds (random in the range) while the storm is full, aimed at a
## ship within LIGHTNING_RANGE_M of the player, after LIGHTNING_WARN_S of St Elmo's fire on its masthead.
const LIGHTNING_EVERY_S: Vector2 = Vector2(18.0, 40.0)
const LIGHTNING_RANGE_M: float = 500.0
const LIGHTNING_WARN_S: float = 3.0
const LIGHTNING_PLAYER_CHANCE: float = 0.35  ## share of strikes aimed at the player's ship when others are near
const LIGHTNING_MAST_SHARE: float = 0.45  ## of the mast's hit points
const LIGHTNING_SAIL_SHARE: float = 0.5  ## of the sail's hit points with every sail set; furled sails take less

## Big seas: one breaks over the player every WAVE_EVERY_S seconds in a full storm, WAVE_WARN_S after the call.
## Damage is WAVE_HULL_SHARE of the hull's hit points, all of it if the sea takes her on the beam and little if she
## meets it bow or stern on.
const WAVE_EVERY_S: Vector2 = Vector2(30.0, 55.0)
const WAVE_WARN_S: float = 5.0
const WAVE_HULL_SHARE: float = 0.07
const WAVE_HEAD_ON: float = 0.12  ## damage share left when the sea comes straight at the bow or the stern

const STORM_HULL_FLOOR: float = 0.25  ## storm hits never take a hull section below this share of its hit points


## The weather's numbers, blended `t` (0..1) of the way from `from` to `to`.
static func blend(from: String, to: String, t: float) -> Dictionary:
	var a: Dictionary = PROFILES.get(from, PROFILES["clear"])
	var b: Dictionary = PROFILES.get(to, PROFILES["clear"])
	var out: Dictionary = {}
	var k: float = clampf(t, 0.0, 1.0)
	for key: String in a:
		out[key] = lerpf(float(a[key]), float(b[key]), k)
	return out


## 0 at noon to 1 in the dead of night, from the in-game hour (the sun rises at 6 and sets at 18).
static func night_amount(hour: float) -> float:
	var elevation: float = sin((hour - 6.0) / 12.0 * PI)
	return clampf(0.5 - elevation * 3.0, 0.0, 1.0)


static func is_night(hour: float) -> bool:
	return night_amount(hour) >= 0.5


## How far a lookout sees, as a share of the clear-day range.
static func sight(weather: Dictionary, hour: float) -> float:
	return float(weather.get("sight", 1.0)) * lerpf(1.0, NIGHT_SIGHT, night_amount(hour))


## A lightning strike on mast `mast`. `sail_level` 0..3 (furled sails take a quarter of the sail damage), `mult` the
## captain's storm skill, `mast_factor` 0 with frost-proof sails. Masts can fall; the hull is never touched.
static func lightning_strike(dm: DamageModel, mast: int, sail_level: int, mult: float, mast_factor: float) -> Dictionary:
	var out: Dictionary = {"mast": mast, "sail": 0.0, "mast_dmg": 0.0, "mast_fell": false}
	if dm == null or dm.sunk or mast < 0 or mast >= dm.mast_hp.size() or dm.mast_down[mast]:
		return out
	var sail_share: float = LIGHTNING_SAIL_SHARE * lerpf(0.25, 1.0, clampf(sail_level / 3.0, 0.0, 1.0))
	var sail: float = minf(dm.sail_hp[mast], dm.sail_max * sail_share * mult)
	dm.sail_hp[mast] -= sail
	var mdmg: float = minf(dm.mast_hp[mast], dm.mast_max * LIGHTNING_MAST_SHARE * mult * mast_factor)
	dm.mast_hp[mast] -= mdmg
	out["sail"] = sail
	out["mast_dmg"] = mdmg
	if dm.mast_hp[mast] <= 0.0 and mdmg > 0.0:
		dm.mast_down[mast] = true
		out["mast_fell"] = true
		dm.mast_fell.emit(mast)
	return out


## The mast lightning picks: the tallest one still standing (the main, the middle of the list).
static func strike_mast(dm: DamageModel) -> int:
	var n: int = dm.mast_hp.size()
	if n == 0:
		return -1
	var order: Array[int] = [n / 2]
	for i in n:
		if i != n / 2:
			order.append(i)
	for i in order:
		if not dm.mast_down[i]:
			return i
	return -1


## Damage share of a big sea by how she meets it: `heading` the way the bow points, `wave_dir` the way the sea runs.
static func wave_exposure(heading: Vector2, wave_dir: Vector2) -> float:
	if heading.length_squared() < 0.0001 or wave_dir.length_squared() < 0.0001:
		return 1.0
	var beam: float = absf(heading.normalized().cross(wave_dir.normalized()))  # 1 on the beam, 0 bow or stern on
	return lerpf(WAVE_HEAD_ON, 1.0, beam * beam)


## Hull damage of one big sea before the floor.
static func wave_damage(hull_hp: float, exposure: float, mult: float) -> float:
	return hull_hp * WAVE_HULL_SHARE * exposure * mult


## Takes up to `dmg` off the hull starting at `section`, spilling to the others, but never below the storm floor
## of any section, so no breach opens and no water comes in. Returns the damage actually taken.
static func storm_hull_hit(dm: DamageModel, section: int, dmg: float) -> float:
	if dm == null or dm.sunk or dmg <= 0.0:
		return 0.0
	var floor_hp: float = dm.section_max * STORM_HULL_FLOOR
	var remaining: float = dmg
	var n: int = dm.section_count
	for hop in n:
		var i: int = (clampi(section, 0, n - 1) + hop) % n
		var take: float = clampf(dm.section_hp[i] - floor_hp, 0.0, remaining)
		dm.section_hp[i] -= take
		remaining -= take
		if remaining <= 0.0:
			break
	return dmg - remaining


## The section a sea from `wave_dir` breaks on: the side it comes from, amidships.
static func wave_section(dm: DamageModel, heading: Vector2, wave_dir: Vector2) -> int:
	var from_starboard: bool = heading.cross(wave_dir) < 0.0  # x right, z back: a sea running to port came from starboard
	return dm.section_for(Vector3(1.0 if from_starboard else -1.0, 0.0, 0.0))


## Which side a sea comes from, for the lookout's call: "port", "starboard", "bow" or "stern".
static func wave_side(heading: Vector2, wave_dir: Vector2) -> String:
	var h: Vector2 = heading.normalized()
	var w: Vector2 = wave_dir.normalized()
	var along: float = h.dot(w)
	if absf(along) > 0.8:
		return "stern" if along > 0.0 else "bow"
	return "starboard" if h.cross(w) < 0.0 else "port"
