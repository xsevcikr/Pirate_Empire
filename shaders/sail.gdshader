shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Canvas sail: billows with the wind, flutters when luffing, and tears where damaged.

uniform float billow : hint_range(0.0, 1.0) = 0.6;
uniform float flutter : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bulge_dir = vec3(0.0, 0.0, -1.0);
uniform float bulge_depth = 2.0;
uniform vec3 canvas_color : source_color = vec3(0.80, 0.72, 0.55);
uniform vec3 stain_color : source_color = vec3(0.55, 0.45, 0.32);
uniform float time_offset = 0.0;

varying vec2 v_uv;
varying vec3 v_obj;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_uv = UV;
	v_obj = VERTEX;
	float shape = sin(UV.x * 3.14159) * sin(UV.y * 3.14159);
	float t = TIME + time_offset;
	float ripple = sin(UV.x * 9.0 + t * 7.0) * sin(UV.y * 6.0 - t * 5.0) * 0.12 * flutter * shape;
	float bulge = (billow * shape * bulge_depth) + ripple * bulge_depth;
	// Slight gentle motion even when full
	bulge += sin(t * 1.3 + UV.x * 2.0) * 0.05 * billow * shape;
	VERTEX += bulge_dir * bulge;
}

void fragment() {
	float weave = fbm(v_uv * vec2(60.0, 80.0));
	float stains = fbm(v_uv * 5.0 + 3.0);
	vec3 col = mix(canvas_color, stain_color, smoothstep(0.55, 0.95, stains) * 0.35);
	col *= 0.92 + 0.16 * weave;
	// Seams between canvas panels
	float seam = smoothstep(0.02, 0.0, abs(fract(v_uv.x * 7.0) - 0.5) - 0.48);
	col *= 1.0 - 0.18 * seam;
	float hole = fbm(v_uv * 9.0 + 7.0);
	if (hole < damage * 0.55) {
		discard;
	}
	float edge = smoothstep(damage * 0.55, damage * 0.55 + 0.04, hole);
	col = mix(vec3(0.1, 0.07, 0.04), col, edge);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	BACKLIGHT = col * 0.9;
}
