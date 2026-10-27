class_name WaveModel
extends RefCounted
## Sum of 12 Gerstner waves. The same parameters feed shaders/ocean.gdshader,
## so the CPU surface used for buoyancy matches the rendered surface.

const WAVE_COUNT: int = 12
const GRAVITY: float = 9.81

## Sea state table: [state, significant wave height m, dominant wavelength m, steepness Q]
const SEA_TABLE: Array = [
	[0.0, 0.1, 8.0, 0.05],
	[2.0, 0.5, 18.0, 0.15],
	[4.0, 1.5, 35.0, 0.25],
	[6.0, 3.5, 60.0, 0.35],
	[8.0, 6.0, 90.0, 0.45],
	[9.0, 9.0, 120.0, 0.55],
]

var sea_state: float = 3.0
var time: float = 0.0
var wave_dirs: PackedVector2Array = PackedVector2Array()
var wave_k: PackedFloat32Array = PackedFloat32Array()
var wave_amp: PackedFloat32Array = PackedFloat32Array()
var wave_q: PackedFloat32Array = PackedFloat32Array()
var wave_omega: PackedFloat32Array = PackedFloat32Array()
var wave_phase: PackedFloat32Array = PackedFloat32Array()


func _init(state: float = 3.0, wave_dir: Vector2 = Vector2(1, 0)) -> void:
	configure(state, wave_dir)


static func sea_params(state: float) -> Dictionary:
	var s: float = clampf(state, 0.0, 9.0)
	for i in range(SEA_TABLE.size() - 1):
		var a: Array = SEA_TABLE[i]
		var b: Array = SEA_TABLE[i + 1]
		if s <= b[0]:
			var t: float = inverse_lerp(a[0], b[0], s)
			return {
				"height": lerpf(a[1], b[1], t),
				"length": lerpf(a[2], b[2], t),
				"steepness": lerpf(a[3], b[3], t),
			}
	var last: Array = SEA_TABLE[SEA_TABLE.size() - 1]
	return {"height": last[1], "length": last[2], "steepness": last[3]}


func configure(state: float, wave_dir: Vector2) -> void:
	sea_state = clampf(state, 0.0, 9.0)
	var p: Dictionary = sea_params(sea_state)
	var base_dir: Vector2 = wave_dir.normalized()
	wave_dirs.resize(WAVE_COUNT)
	wave_k.resize(WAVE_COUNT)
	wave_amp.resize(WAVE_COUNT)
	wave_q.resize(WAVE_COUNT)
	wave_omega.resize(WAVE_COUNT)
	wave_phase.resize(WAVE_COUNT)
	var weights: Array[float] = []
	var lengths: Array[float] = []
	var sum_sq: float = 0.0
	for i in WAVE_COUNT:
		var u: float = fmod((i + 0.5) * 0.618034, 1.0)
		var length: float = p["length"] * lerpf(0.3, 1.7, u)
		var w: float = exp(-pow(log(length / p["length"]), 2.0) / 0.5)
		lengths.append(length)
		weights.append(w)
		sum_sq += w * w
	var amp_scale: float = p["height"] / (2.0 * sqrt(2.0)) / sqrt(sum_sq)
	for i in WAVE_COUNT:
		var spread: float = (fmod(i * 0.381966 + 0.13, 1.0) - 0.5) * deg_to_rad(70.0)
		wave_dirs[i] = base_dir.rotated(spread)
		wave_k[i] = TAU / lengths[i]
		wave_amp[i] = weights[i] * amp_scale
		wave_omega[i] = sqrt(GRAVITY * wave_k[i])
		wave_phase[i] = fmod(i * 2.399963, TAU)
		wave_q[i] = clampf(p["steepness"] / (WAVE_COUNT * wave_k[i] * wave_amp[i]), 0.0, 1.0)


## World point of the water surface that started at (x, z) at rest.
func displaced(x: float, z: float, t: float) -> Vector3:
	var out := Vector3(x, 0.0, z)
	for i in WAVE_COUNT:
		var d: Vector2 = wave_dirs[i]
		var phase: float = wave_k[i] * (d.x * x + d.y * z) - wave_omega[i] * t + wave_phase[i]
		var c: float = cos(phase)
		var qa: float = wave_q[i] * wave_amp[i]
		out.x += qa * d.x * c
		out.z += qa * d.y * c
		out.y += wave_amp[i] * sin(phase)
	return out


## Surface height at world (x, z): inverts the horizontal Gerstner displacement.
func height_at(x: float, z: float, t: float = -1.0) -> float:
	var time_s: float = time if t < 0.0 else t
	var px: float = x
	var pz: float = z
	for _i in 4:
		var q: Vector3 = displaced(px, pz, time_s)
		px += x - q.x
		pz += z - q.z
	return displaced(px, pz, time_s).y


func normal_at(x: float, z: float, t: float = -1.0) -> Vector3:
	var e: float = 0.5
	var hx: float = height_at(x + e, z, t) - height_at(x - e, z, t)
	var hz: float = height_at(x, z + e, t) - height_at(x, z - e, t)
	return Vector3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)).normalized()


func shader_wave_a() -> PackedVector4Array:
	var arr := PackedVector4Array()
	for i in WAVE_COUNT:
		arr.append(Vector4(wave_dirs[i].x, wave_dirs[i].y, wave_k[i], wave_amp[i]))
	return arr


func shader_wave_b() -> PackedVector4Array:
	var arr := PackedVector4Array()
	for i in WAVE_COUNT:
		arr.append(Vector4(wave_q[i], wave_omega[i], wave_phase[i], 0.0))
	return arr
