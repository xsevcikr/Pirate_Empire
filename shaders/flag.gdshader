shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec3 base_color : source_color = vec3(0.05, 0.05, 0.06);
uniform vec3 mark_color : source_color = vec3(0.95, 0.95, 0.95);
uniform float skull = 1.0;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(UV.x * 9.0 - TIME * 6.0) * 0.25 * k;
	VERTEX.y += sin(UV.x * 7.0 - TIME * 5.0) * 0.08 * k;
}

void fragment() {
	vec2 p = (UV - vec2(0.45, 0.5)) * vec2(2.0, 2.0);
	float skull_d = length(p * vec2(1.0, 1.15) - vec2(0.0, 0.1));
	float jaw = step(abs(p.x), 0.22) * step(abs(p.y + 0.38), 0.14);
	float eyes = 1.0 - step(0.0, 0.12 - min(length(p - vec2(-0.2, 0.15)), length(p - vec2(0.2, 0.15))));
	float head = (1.0 - smoothstep(0.42, 0.46, skull_d)) + jaw;
	float bones = step(abs(abs(p.x) - abs(p.y) * 1.0), 0.07) * step(abs(p.y), 0.75) * step(0.3, abs(p.x));
	float mark = clamp(head * eyes + bones, 0.0, 1.0) * skull;
	ALBEDO = mix(base_color, mark_color, mark);
}
