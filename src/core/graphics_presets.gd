class_name GraphicsPresets
extends RefCounted
## Quality presets Low to Ultra (plus Steam Deck) applied to an Environment and viewport.

const TABLE: Dictionary = {
	"low": {"ssao": false, "glow": false, "fog_volumetric": false, "shadow_size": 1024, "msaa": 0, "ocean_waves": 4, "particles": 0.25, "view_m": 1500.0},
	"medium": {"ssao": false, "glow": true, "fog_volumetric": false, "shadow_size": 2048, "msaa": 0, "ocean_waves": 6, "particles": 0.5, "view_m": 3000.0},
	"high": {"ssao": true, "glow": true, "fog_volumetric": false, "shadow_size": 4096, "msaa": 1, "ocean_waves": 8, "particles": 1.0, "view_m": 6000.0},
	"ultra": {"ssao": true, "glow": true, "fog_volumetric": true, "shadow_size": 8192, "msaa": 2, "ocean_waves": 8, "particles": 1.5, "view_m": 12000.0},
	"deck": {"ssao": false, "glow": true, "fog_volumetric": false, "shadow_size": 2048, "msaa": 0, "ocean_waves": 6, "particles": 0.5, "view_m": 3000.0},
}


static func apply(preset: String, env: Environment) -> bool:
	if not TABLE.has(preset):
		return false
	var p: Dictionary = TABLE[preset]
	env.ssao_enabled = p["ssao"]
	env.glow_enabled = p["glow"]
	env.volumetric_fog_enabled = p["fog_volumetric"]
	return true


static func sun_shadow_size(preset: String) -> int:
	return TABLE[preset]["shadow_size"]
