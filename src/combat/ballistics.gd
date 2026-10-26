class_name Ballistics
extends RefCounted
## Projectile integration shared by live shots and the aiming prediction.

const DRAG: float = 0.0003  # per metre, quadratic


static func step(pos: Vector3, vel: Vector3, gravity: float, dt: float, drag: float = DRAG) -> Array:
	vel += Vector3(0, -gravity, 0) * dt - vel * vel.length() * drag * dt
	pos += vel * dt
	return [pos, vel]


## Horizontal landing point on the plane y = water_y (flat-water prediction).
static func landing_point(origin: Vector3, vel: Vector3, gravity: float, water_y: float = 0.0, drag: float = DRAG) -> Vector3:
	var pos: Vector3 = origin
	var v: Vector3 = vel
	var dt: float = 0.01
	for _i in 1500:
		var prev: Vector3 = pos
		var out: Array = step(pos, v, gravity, dt, drag)
		pos = out[0]
		v = out[1]
		if pos.y <= water_y and v.y < 0.0:
			var t: float = inverse_lerp(prev.y, pos.y, water_y)
			return prev.lerp(pos, t)
	return pos
