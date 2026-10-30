class_name OceanCurrent
extends RefCounted
## Ocean streams between regions (0.5 to 2 kn) and the twice-daily tide that strengthens and slackens them.
## Pure functions: the world feeds them a position and the game time in hours.

const KN_TO_MS: float = 0.5144
const TIDE_PERIOD_H: float = 12.42
const TIDE_RANGE_M: float = 1.2
const TIDE_STREAM_SWING: float = 0.25  ## streams run 25% stronger on the flood tide and 25% weaker on the ebb
const MAX_KN: float = 2.0

## Each stream is a straight band: it flows from `from` to `to`, `width_m` either side of the line.
const STREAMS: Array[Dictionary] = [
	{"id": "haven_south", "from": Vector2(0, 1200), "to": Vector2(0, 4600), "width_m": 700.0, "kn": 1.0},
	{"id": "albion_drift", "from": Vector2(-6200, 4600), "to": Vector2(-2200, 700), "width_m": 800.0, "kn": 0.8},
	{"id": "iron_return", "from": Vector2(6200, 4600), "to": Vector2(2200, 600), "width_m": 800.0, "kn": 1.2},
	{"id": "coral_run", "from": Vector2(-6200, -5200), "to": Vector2(-2400, -6400), "width_m": 700.0, "kn": 1.5},
	{"id": "dead_reach_gyre", "from": Vector2(-3200, -6200), "to": Vector2(3200, -6200), "width_m": 900.0, "kn": 2.0},
	{"id": "reef_gate", "from": Vector2(-5800, -1400), "to": Vector2(-3000, 1200), "width_m": 600.0, "kn": 0.5},
]


## Tide height in metres above mean sea level; positive on the flood.
static func tide_m(hours: float) -> float:
	return TIDE_RANGE_M * sin(TAU * hours / TIDE_PERIOD_H)


static func tide_rising(hours: float) -> bool:
	return cos(TAU * hours / TIDE_PERIOD_H) > 0.0


static func tide_factor(hours: float) -> float:
	return 1.0 + TIDE_STREAM_SWING * sin(TAU * hours / TIDE_PERIOD_H)


## Distance from p to the stream's centre line, and the position along it (0..1).
static func _along(s: Dictionary, p: Vector2) -> Vector2:
	var a: Vector2 = s["from"]
	var ab: Vector2 = (s["to"] as Vector2) - a
	var f: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2((a + ab * f).distance_to(p), f)


## How strongly stream `s` acts at p: 1 on the line, easing to 0 at the edge and past the ends.
static func influence(s: Dictionary, p: Vector2) -> float:
	var da: Vector2 = _along(s, p)
	var edge: float = 1.0 - clampf(da.x / float(s["width_m"]), 0.0, 1.0)
	var ends: float = clampf(minf(da.y, 1.0 - da.y) * 6.0, 0.0, 1.0)
	return smoothstep(0.0, 1.0, edge) * ends


## Water velocity at p in m/s (x east, y south), tide included, never above 2 kn.
static func velocity_at(p: Vector2, hours: float = 0.0) -> Vector2:
	var v: Vector2 = Vector2.ZERO
	for s in STREAMS:
		var w: float = influence(s, p)
		if w > 0.0:
			var dir: Vector2 = ((s["to"] as Vector2) - (s["from"] as Vector2)).normalized()
			v += dir * float(s["kn"]) * KN_TO_MS * w
	v *= tide_factor(hours)
	return v.limit_length(MAX_KN * KN_TO_MS)


static func speed_kn(p: Vector2, hours: float = 0.0) -> float:
	return velocity_at(p, hours).length() / KN_TO_MS


## Streams whose band the point lies in (a ship sailing there has "sailed" them).
static func streams_at(p: Vector2) -> Array[String]:
	var out: Array[String] = []
	for s in STREAMS:
		if influence(s, p) > 0.15:
			out.append(s["id"])
	return out
