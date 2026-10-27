shader_type spatial;
// Terrain colour from vertex colour, broken up with noise; steep faces turn to bare rock.

uniform vec3 rock_color : source_color = vec3(0.36, 0.32, 0.28);

varying vec3 v_obj;
varying vec4 v_col;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 5.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_obj = VERTEX;
	v_col = COLOR;
}

void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - clamp(world_n.y, 0.0, 1.0);
	float n1 = fbm(v_obj.xz * 0.12);
	float n2 = fbm(v_obj.xz * 0.9 + v_obj.y);
	vec3 c = v_col.rgb * (0.75 + 0.5 * n1) * (0.9 + 0.2 * n2) * 0.62;
	float rocky = smoothstep(0.35, 0.6, slope + (n1 - 0.5) * 0.3);
	vec3 strata = rock_color * (0.8 + 0.4 * sin(v_obj.y * 1.7 + n2 * 4.0));
	c = mix(c, strata, rocky);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
