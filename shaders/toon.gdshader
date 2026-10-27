shader_type spatial;
render_mode cull_back;
// Cartoon surface for the Kenney models: flat palette colours, a soft two-band light and a faint rim.
// `tint` multiplies the colour (damage soot, hull paint); `flash` is an additive hit flash (characters own copies of their materials).

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool use_tex = true;
uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.22;
uniform float emit_amount : hint_range(0.0, 4.0) = 0.0;
uniform float saturation : hint_range(0.5, 2.0) = 1.12;
uniform vec4 flash : source_color = vec4(0.0);

vec3 saturate_col(vec3 c, float s) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(l), c, s);
}

void fragment() {
	vec3 c = albedo * tint;
	if (use_tex) {
		c *= texture(albedo_tex, UV).rgb;
	}
	c = saturate_col(c, saturation);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * (rim * rim_amount + emit_amount) + flash.rgb * flash.a;
}

#include "res://shaders/toon.gdshaderinc"
