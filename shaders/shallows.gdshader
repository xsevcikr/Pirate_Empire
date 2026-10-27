shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Shallow water skirt around an island: turquoise fading to nothing, with a breathing foam line at the beach.

uniform vec3 shallow : source_color = vec3(0.2, 0.85, 0.78);
uniform vec3 foam : source_color = vec3(1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float v = UV.y;  // 0 at the beach, 1 at the outer edge
	float t = TIME;
	float surf = 0.05 + 0.04 * sin(t * 0.9 + UV.x * 6.0);
	float edge = smoothstep(surf + 0.05, surf, v) * (0.6 + 0.4 * noise(vec2(UV.x * 60.0, t * 0.6)));
	float lines = smoothstep(0.55, 0.8, noise(vec2(UV.x * 40.0, v * 14.0 - t * 0.5))) * smoothstep(0.5, 0.1, v) * 0.45;
	float a = (1.0 - smoothstep(0.0, 1.0, v)) * 0.62;
	ALBEDO = mix(shallow, foam, clamp(edge + lines, 0.0, 1.0));
	ALPHA = clamp(a + edge * 0.5 + lines * 0.5, 0.0, 0.9);
}
