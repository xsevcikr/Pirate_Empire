shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Cartoon sail on the Kenney sail mesh: keeps the palette colours (or a chosen canvas colour and pattern), billows and
// flutters with the wind, lets the light through a little and tears where it is damaged.

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool custom = false;  // false: Kenney palette colours; true: canvas_color and pattern
uniform float billow : hint_range(0.0, 1.0) = 0.6;
uniform float flutter : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bulge_dir = vec3(0.0, 0.0, 1.0);  // unused by the Kenney mesh: the belly follows the model's +Z
uniform float bulge_depth = 1.0;
uniform vec3 canvas_color : source_color = vec3(0.93, 0.92, 0.88);
uniform vec3 trim_color : source_color = vec3(0.78, 0.2, 0.16);
uniform float trim_width = 0.04;
uniform float time_offset = 0.0;
uniform int pattern = 0;  // 0 plain, 1 striped, 2 skull, 3 torn, 4 black
uniform vec3 mark_color : source_color = vec3(0.1, 0.1, 0.1);
uniform vec2 sail_size = vec2(4.4, 4.7);  // model-space width and height
uniform float shade : hint_range(0.0, 1.0) = 0.5;

varying vec2 v_uv;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_uv = vec2(VERTEX.x / sail_size.x + 0.5, VERTEX.y / sail_size.y);
	float shape = sin(clamp(v_uv.x, 0.0, 1.0) * 3.14159) * sin(clamp(v_uv.y, 0.0, 1.0) * 3.14159);
	float t = TIME + time_offset;
	float ripple = sin(v_uv.x * 9.0 + t * 7.0) * sin(v_uv.y * 6.0 - t * 5.0) * 0.12 * flutter * shape;
	// the model's own belly is a half-full sail: full wind deepens it, slack wind flattens it
	float belly = (billow - 0.55) * 1.1 * shape + ripple + sin(t * 1.3 + v_uv.x * 2.0) * 0.04 * billow * shape;
	VERTEX.z += belly * bulge_depth;
}

void fragment() {
	vec3 col;
	if (custom) {
		col = canvas_color;
		float edge_d = min(min(v_uv.x, 1.0 - v_uv.x), min(v_uv.y, 1.0 - v_uv.y));
		col = mix(col, trim_color, smoothstep(trim_width, trim_width - 0.012, edge_d) * 0.9);
		if (pattern == 1) {
			col = mix(col, mark_color, step(0.5, fract(v_uv.y * 6.0)) * 0.85);
		} else if (pattern == 2) {
			vec2 sp = (v_uv - vec2(0.5, 0.5)) * vec2(1.7, 1.0);
			float head = 1.0 - smoothstep(0.17, 0.19, length(sp * vec2(1.0, 1.1)));
			float eyes = step(min(length(sp - vec2(-0.07, 0.04)), length(sp - vec2(0.07, 0.04))), 0.045);
			float bone = step(abs(abs(sp.x) - abs(sp.y + 0.2)), 0.025) * step(abs(sp.y + 0.2), 0.14);
			col = mix(col, mark_color, clamp(head * (1.0 - eyes) + bone, 0.0, 1.0));
		} else if (pattern == 4) {
			col = mix(col, mark_color, 0.92);
		}
	} else {
		col = texture(albedo_tex, UV).rgb;
	}
	float tear_bias = pattern == 3 ? 0.35 : 0.0;
	float hole = noise(v_uv * 9.0 + 7.0) * 0.6 + noise(v_uv * 19.0) * 0.4;
	if (hole < max(damage, tear_bias * smoothstep(0.55, 1.0, v_uv.y)) * 0.55) {
		discard;
	}
	float edge = smoothstep(damage * 0.55, damage * 0.55 + 0.04, hole);
	col = mix(vec3(0.16, 0.1, 0.07), col, edge);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	BACKLIGHT = col * 0.45;
}

void light() {
	float nl = abs(dot(NORMAL, LIGHT));
	float band = smoothstep(0.0, 0.2, nl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * mix(shade, 1.0, band) / PI * 1.15;
}
