shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// A ring of white surf around a hull: broken into dashes that drift and breathe, so a ship never sits dead on the water.

uniform float speed = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float ang = atan(p.y, p.x);
	float t = TIME;
	float ring = smoothstep(0.78, 0.86, d) * (1.0 - smoothstep(0.93, 1.0, d));
	float dashes = step(0.0, sin(ang * 14.0 + t * 1.4 + sin(ang * 5.0 - t) * 2.0));
	float inner = smoothstep(0.55, 0.8, d) * (1.0 - smoothstep(0.8, 0.9, d)) * 0.5;
	float a = clamp(ring * mix(0.55, 1.0, dashes) + inner * 0.6, 0.0, 1.0);
	ALBEDO = vec3(1.0);
	ALPHA = a * (0.85 + 0.15 * sin(t * 2.0));
}
