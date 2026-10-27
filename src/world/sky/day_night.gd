class_name DayNight
extends Node
## Drives sun direction, light color, sky colors and fog from the in-game hour.

var sun: DirectionalLight3D
var env: Environment
var sky_material: ProceduralSkyMaterial
var ocean: Ocean
var clouds: CloudLayer

const DAWN: Color = Color(1.0, 0.62, 0.38)
const NOON: Color = Color(1.0, 0.96, 0.9)
const NIGHT: Color = Color(0.45, 0.55, 0.85)


func apply_hour(hour: float) -> void:
	# Sun rises at 6:00, peaks at 12:00 (latitude 18 N), sets at 18:00.
	var day_angle: float = (hour - 6.0) / 12.0 * PI
	var elevation: float = sin(day_angle) * deg_to_rad(72.0)
	var azimuth: float = deg_to_rad(90.0) + (hour - 6.0) / 12.0 * PI
	var sun_dir := Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
	var day_amount: float = clampf(sin(elevation) * 4.0 + 0.1, 0.0, 1.0)
	var low: float = 1.0 - clampf(absf(sin(elevation)) * 2.2, 0.0, 1.0)
	if sun:
		var light_dir: Vector3 = sun_dir if sin(elevation) > 0.0 else -sun_dir
		sun.look_at_from_position(Vector3.ZERO, -light_dir, Vector3.UP)
		var col: Color = NOON.lerp(DAWN, low)
		if sin(elevation) <= 0.0:
			col = NIGHT
			sun.light_energy = 0.12
		else:
			sun.light_energy = lerpf(0.2, 1.6, clampf(sin(elevation) * 2.0, 0.0, 1.0))
		sun.light_color = col
	var top_day := Color(0.18, 0.38, 0.75)
	var horizon_day := Color(0.62, 0.78, 0.92)
	var top_night := Color(0.01, 0.02, 0.07)
	var horizon_night := Color(0.04, 0.06, 0.14)
	var top: Color = top_night.lerp(top_day, day_amount)
	var sunset: Color = Color(1.0, 0.5, 0.22)
	var horizon: Color = horizon_night.lerp(horizon_day, day_amount).lerp(sunset, low * day_amount * 0.85)
	top = top.lerp(Color(0.22, 0.26, 0.5), low * day_amount * 0.7)
	if sky_material:
		sky_material.sky_top_color = top
		sky_material.sky_horizon_color = horizon
		sky_material.ground_horizon_color = horizon
		sky_material.ground_bottom_color = top_night.lerp(Color(0.1, 0.2, 0.3), day_amount)
		sky_material.sun_angle_max = 30.0
		sky_material.sky_curve = 0.12
		sky_material.sky_energy_multiplier = 1.1
	if env:
		env.fog_light_color = horizon
		env.fog_density = lerpf(0.0006, 0.0016, low)
		env.ambient_light_energy = lerpf(0.25, 1.25, day_amount)
	if ocean:
		ocean.set_sky_color(horizon.lerp(top, 0.7))
	if clouds:
		var lit: Color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.62, 0.4), low * day_amount).lerp(Color(0.08, 0.1, 0.18), 1.0 - day_amount)
		var shade: Color = Color(0.58, 0.68, 0.82).lerp(Color(0.55, 0.38, 0.4), low * day_amount).lerp(Color(0.03, 0.04, 0.09), 1.0 - day_amount)
		clouds.tint(lit, shade, 0.5)
