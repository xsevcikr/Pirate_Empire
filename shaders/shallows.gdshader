shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Shallow water skirt around an island: turquoise fading to nothing, with a breathing foam line at the beach.

uniform vec3 shallow : source_color = vec3(0.25, 0.9, 0.85);
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
	// two flat turquoise bands, a crisp white surf line that breathes in and out
	float surf = 0.07 + 0.04 * sin(t * 0.9 + UV.x * 6.0);
	float foam_line = step(v, surf) * step(0.35, 0.5 + 0.5 * sin(UV.x * 90.0 + t));
	float foam_ring = step(abs(v - surf - 0.1), 0.012);
	vec3 col = mix(shallow, shallow * vec3(0.8, 0.95, 1.05), step(0.35, v));
	col = mix(col, foam, max(foam_line, foam_ring * 0.8));
	float a = 0.9 * (1.0 - smoothstep(0.55, 1.0, v));
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.92);
}
