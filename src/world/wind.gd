class_name WindModel
extends RefCounted
## Global wind. `direction` is the unit vector (x, z) the wind blows TOWARD.

## [wind speed kn, sea state] used to derive the sea state from the wind.
const SEA_FROM_WIND: Array = [[1.0, 0.0], [6.0, 2.0], [13.5, 4.0], [24.5, 6.0], [37.0, 8.0], [48.0, 9.0]]

var direction: Vector2 = Vector2(0, 1)
var speed_kn: float = 16.0
var gust: float = 0.0

var _noise := FastNoiseLite.new()
var _t: float = 0.0


func _init() -> void:
	_noise.seed = 1729
	_noise.frequency = 1.0


func speed_ms() -> float:
	return MathUtils.knots_to_ms(speed_kn * (1.0 + gust))


func wind_from() -> Vector2:
	return -direction


func sea_state() -> float:
	var s: float = speed_kn
	for i in range(SEA_FROM_WIND.size() - 1):
		var a: Array = SEA_FROM_WIND[i]
		var b: Array = SEA_FROM_WIND[i + 1]
		if s <= b[0]:
			return lerpf(a[1], b[1], clampf(inverse_lerp(a[0], b[0], s), 0.0, 1.0))
	return 9.0


## Slow direction drift and +-20% gusts.
func update(delta: float) -> void:
	_t += delta
	gust = 0.2 * _noise.get_noise_1d(_t / 7.0)
	var drift: float = deg_to_rad(8.0) / 7200.0 * 48.0 * _noise.get_noise_1d(_t / 600.0 + 100.0)
	direction = direction.rotated(drift * delta * 60.0).normalized()


## Angle in degrees between the heading and the direction the wind comes from (0 = into the wind).
func angle_off_wind_deg(heading: Vector2) -> float:
	var h: Vector2 = heading.normalized()
	return rad_to_deg(acos(clampf(h.dot(wind_from()), -1.0, 1.0)))
