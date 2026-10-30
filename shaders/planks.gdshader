shader_type spatial;
render_mode cull_back;
// Flat cartoon planks from object-space position: alternating warm tones with dark seams, no grain.

uniform vec3 wood_color : source_color = vec3(0.94, 0.59, 0.42);
uniform vec3 dark_color : source_color = vec3(0.45, 0.24, 0.18);
uniform float plank_width = 0.4;
uniform bool along_x = false;
uniform float seam = 0.06;
uniform vec3 tint : source_color = vec3(1.0);
uniform float saturation : hint_range(0.5, 2.0) = 1.1;

varying vec3 v_obj;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	float coord = (along_x ? v_obj.z : v_obj.x) / plank_width;
	float idx = floor(coord);
	float f = fract(coord);
	float tone = floor(hash(idx) * 3.0) / 3.0;
	vec3 c = wood_color * (0.9 + 0.14 * tone);
	float edge = smoothstep(0.0, seam, f) * smoothstep(1.0, 1.0 - seam, f);
	// butt joints: a short dark line across each plank, staggered
	float len = (along_x ? v_obj.x : v_obj.z) / (plank_width * 7.0) + hash(idx + 3.0);
	float joint = smoothstep(0.0, 0.015, fract(len)) * smoothstep(1.0, 0.985, fract(len));
	c = mix(dark_color, c, min(edge, joint));
	c *= tint;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), c, saturation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://shaders/toon.gdshaderinc"
