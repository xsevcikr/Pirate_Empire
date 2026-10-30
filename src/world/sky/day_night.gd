class_name DayNight
extends Node
## Drives sun direction, light color, sky colors and fog from the in-game hour, then darkens and greys them by the
## weather (WeatherSystem fills `weather` and `flash`). Stars, the moon and the ships' lanterns come out at night.

var sun: DirectionalLight3D
var env: Environment
var sky_material: ProceduralSkyMaterial
var ocean: Ocean
var clouds: CloudLayer
var stars: StarDome
var lights: NightLights
var weather: Dictionary = {}  ## WeatherRules.blend() output; empty means a clear day
var flash: float = 0.0  ## 0..1, a lightning flash

const STORM_SKY: Color = Color(0.3, 0.34, 0.4)

const DAWN: Color = Color(1.0, 0.62, 0.38)
const NOON: Color = Color(1.0, 0.94, 0.82)
const NIGHT: Color = Color(0.45, 0.55, 0.85)


func apply_hour(hour: float) -> void:
	# Sun rises at 6:00, peaks at 12:00 (latitude 18 N), sets at 18:00.
	var day_angle: float = (hour - 6.0) / 12.0 * PI
	var elevation: float = sin(day_angle) * deg_to_rad(72.0)
	var azimuth: float = deg_to_rad(90.0) + (hour - 6.0) / 12.0 * PI
	var sun_dir := Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
	var day_amount: float = clampf(sin(elevation) * 4.0 + 0.1, 0.0, 1.0)
	var low: float = 1.0 - clampf(absf(sin(elevation)) * 2.2, 0.0, 1.0)
	var dim: float = float(weather.get("dim", 0.0))
	var cover: float = float(weather.get("clouds", 0.5))
	low *= 1.0 - dim  # no red sunset through storm clouds
	if sun:
		var light_dir: Vector3 = sun_dir if sin(elevation) > 0.0 else -sun_dir
		sun.look_at_from_position(Vector3.ZERO, -light_dir, Vector3.UP)
		var col: Color = NOON.lerp(DAWN, low)
		if sin(elevation) <= 0.0:
			col = NIGHT
			sun.light_energy = 0.12
		else:
			sun.light_energy = lerpf(0.2, 0.8, clampf(sin(elevation) * 2.0, 0.0, 1.0))
		sun.light_energy *= 1.0 - dim * 0.75
		sun.light_energy += flash * 1.5
		sun.light_color = col.lerp(Color(0.85, 0.9, 1.0), flash)
	var top_day := Color(0.28, 0.58, 0.96)
	var horizon_day := Color(0.78, 0.9, 1.0)
	var top_night := Color(0.01, 0.02, 0.07)
	var horizon_night := Color(0.04, 0.06, 0.14)
	var top: Color = top_night.lerp(top_day, day_amount)
	var sunset: Color = Color(1.0, 0.62, 0.38)
	var horizon: Color = horizon_night.lerp(horizon_day, day_amount).lerp(sunset, low * day_amount * 0.85)
	top = top.lerp(Color(0.22, 0.26, 0.5), low * day_amount * 0.7)
	var grey: Color = top_night.lerp(STORM_SKY, day_amount)
	top = top.lerp(grey * 0.85, dim).lerp(Color(0.8, 0.85, 1.0), flash * 0.6)
	horizon = horizon.lerp(grey, dim).lerp(Color(0.85, 0.9, 1.0), flash * 0.6)
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
		env.fog_density = lerpf(0.0006, 0.0016, low) * float(weather.get("fog", 1.0))
		var amb_day: Color = Color(0.46, 0.52, 0.72).lerp(Color(0.66, 0.5, 0.52), low * day_amount * 0.6)
		env.ambient_light_color = Color(0.1, 0.13, 0.28).lerp(amb_day, day_amount)
		env.ambient_light_energy = lerpf(0.5, 0.78, day_amount) * (1.0 - dim * 0.35) + flash * 1.2
	if ocean:
		ocean.set_sky_color(horizon.lerp(top, 0.7))
	if clouds:
		var lit: Color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.62, 0.4), low * day_amount).lerp(Color(0.08, 0.1, 0.18), 1.0 - day_amount)
		var shade: Color = Color(0.58, 0.68, 0.82).lerp(Color(0.55, 0.38, 0.4), low * day_amount).lerp(Color(0.03, 0.04, 0.09), 1.0 - day_amount)
		lit = lit.lerp(lit * 0.45, dim)
		shade = shade.lerp(shade * 0.4, dim)
		clouds.tint(lit, shade, cover)
	var night: float = WeatherRules.night_amount(hour)
	if stars:
		stars.set_night(night, cover * cover, -sun_dir if sin(elevation) < 0.0 else Vector3(-0.4, 0.5, 0.6).normalized())
	if lights:
		lights.night = maxf(night, (dim - 0.2) * 1.2)
