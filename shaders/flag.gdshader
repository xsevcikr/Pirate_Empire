shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec3 base_color : source_color = vec3(0.05, 0.05, 0.06);
uniform vec3 mark_color : source_color = vec3(0.95, 0.95, 0.95);
uniform float skull = 1.0;
uniform int layout = 0;  // 0 plain, 1 split, 2 cross, 3 border
uniform bool use_pixels = false;
uniform sampler2D pixel_tex : filter_nearest;
uniform vec3 field_color : source_color = vec3(0.05, 0.05, 0.06);

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
	vec3 field = base_color;
	if (layout == 1) {
		field = UV.y < 0.5 ? base_color : field_color;
	} else if (layout == 2) {
		field = (abs(UV.x - 0.5) < 0.08 || abs(UV.y - 0.5) < 0.12) ? field_color : base_color;
	} else if (layout == 3) {
		float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		field = e < 0.09 ? field_color : base_color;
	}
	vec3 col = mix(field, mark_color, mark);
	if (use_pixels) {
		vec4 px = texture(pixel_tex, vec2(UV.x, 1.0 - UV.y));
		col = mix(col, px.rgb, px.a);
	}
	ALBEDO = col;
}
