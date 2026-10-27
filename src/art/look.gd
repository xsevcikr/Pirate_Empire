class_name Look
extends RefCounted
## The shared cartoon look: soft colour ambient, filmic tonemap, light glow, gentle SSAO and punchy colour grading,
## the recipe of Kenney's starter scene. Every scene that draws the world calls this instead of setting its own.


static func apply_environment(env: Environment) -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.62)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 0.8
	env.ssao_power = 12.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.06


static func apply_sun(sun: DirectionalLight3D, max_distance: float) -> void:
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.9
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = max_distance
