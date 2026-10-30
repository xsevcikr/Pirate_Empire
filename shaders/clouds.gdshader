shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// A drifting layer of cumulus on a huge flat quad that follows the camera. Lit by colours the day cycle sets.

uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade_color : source_color = vec3(0.62, 0.7, 0.82);
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_time = 0.0;
uniform vec2 wind_dir = vec2(1.0, 0.3);
uniform float horizon_fade = 9000.0;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 3.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz * 0.00045 + wind_dir * cloud_time * 0.002;
	float d = fbm(p);
	float c = smoothstep(1.0 - coverage - 0.015, 1.0 - coverage + 0.015, d);
	// sun-facing edges are bright, cores shaded: sample a little toward the light
	float d2 = fbm(p + vec2(0.012, -0.008));
	float shade = step(0.5, clamp((d - d2) * 9.0 + 0.5, 0.0, 1.0));
	vec3 col = mix(lit_color, shade_color, shade * 0.75 * c);
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(v_world.xz, cam.xz);
	float fade = 1.0 - smoothstep(horizon_fade * 0.35, horizon_fade, dist);
	ALBEDO = col;
	ALPHA = c * fade;
}
