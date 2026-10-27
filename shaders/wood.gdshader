shader_type spatial;
render_mode cull_disabled;
// Weathered planks: grooves, per-plank tint, grain and butt joints, from object-space position.

uniform vec3 wood_color : source_color = vec3(0.50, 0.34, 0.19);
uniform vec3 dark_color : source_color = vec3(0.20, 0.12, 0.07);
uniform float plank_width = 0.32;
uniform float plank_len = 2.6;
uniform bool along_x = false;
uniform float wear : hint_range(0.0, 1.0) = 0.5;
uniform float rough = 0.85;
uniform bool use_vertex_color = false;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 v_obj;
varying vec4 v_col;

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
	v_obj = VERTEX;
	v_col = COLOR;
}

void fragment() {
	vec3 p = v_obj;
	float along = along_x ? p.x : p.z;
	float across = along_x ? (abs(NORMAL.y) > 0.5 ? p.z : p.y) : (abs(NORMAL.y) > 0.5 ? p.x : p.y);
	float row = floor(across / plank_width);
	float joint = floor((along + hash(vec2(row, 3.0)) * plank_len) / plank_len);
	float id = hash(vec2(row, joint));
	float groove = smoothstep(0.0, 0.03, fract(across / plank_width)) * smoothstep(0.0, 0.03, 1.0 - fract(across / plank_width));
	float jline = smoothstep(0.0, 0.012, fract((along + hash(vec2(row, 3.0)) * plank_len) / plank_len)) ;
	float grain = noise(vec2(along * 1.5, across * 14.0)) * 0.6 + noise(vec2(along * 6.0, across * 40.0)) * 0.4;
	vec3 c = mix(dark_color, wood_color, 0.65 + 0.35 * id);
	c *= 0.78 + 0.35 * grain;
	c = mix(c, c * vec3(0.8, 0.82, 0.86), wear * noise(p.xz * 2.2 + p.y));
	c *= mix(0.35, 1.0, groove * jline);
	if (use_vertex_color) {
		float m = dot(c, vec3(0.33)) / 0.36;
		c = v_col.rgb * clamp(m, 0.45, 1.5);
	}
	ALBEDO = c * tint;
	ROUGHNESS = rough - 0.15 * grain;
	SPECULAR = 0.25;
}
