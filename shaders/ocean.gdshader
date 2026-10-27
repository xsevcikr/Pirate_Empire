shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, specular_schlick_ggx;
// Gerstner ocean. Wave parameters come from WaveModel so the CPU surface matches.
// wave_a[i] = (dir.x, dir.y, k, amplitude); wave_b[i] = (Q, omega, phase, 0)

const int WAVES = 12;

uniform vec4 wave_a[12];
uniform vec4 wave_b[12];
uniform float ocean_time = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.1, 0.62, 0.62);
uniform vec3 deep_color : source_color = vec3(0.012, 0.075, 0.15);
uniform vec3 sky_color : source_color = vec3(0.55, 0.7, 0.9);
uniform vec3 foam_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float fade_start = 900.0;
uniform float fade_end = 3000.0;

varying float v_height;
varying float v_foam;
varying float v_amp_scale;
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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(11.3, 7.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(world.xz, cam.xz);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	vec3 disp = vec3(0.0);
	vec3 n = vec3(0.0, 1.0, 0.0);
	float pinch = 0.0;
	float total_amp = 0.0;
	for (int i = 0; i < WAVES; i++) {
		vec2 d = wave_a[i].xy;
		float k = wave_a[i].z;
		float a = wave_a[i].w * fade;
		float q = wave_b[i].x;
		float w = wave_b[i].y;
		float ph = k * dot(d, world.xz) - w * ocean_time + wave_b[i].z;
		float c = cos(ph);
		float s = sin(ph);
		disp.x += q * a * d.x * c;
		disp.z += q * a * d.y * c;
		disp.y += a * s;
		n.x -= d.x * k * a * c;
		n.z -= d.y * k * a * c;
		n.y -= q * k * a * s;
		pinch += q * k * a * s;
		total_amp += a;
	}
	VERTEX += disp;
	NORMAL = normalize(n);
	v_height = disp.y;
	v_foam = smoothstep(0.4, 0.7, pinch) * fade;
	v_amp_scale = max(total_amp, 0.05);
	v_world = world + disp;
}

void fragment() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(v_world.xz, cam.xz);
	float near = 1.0 - smoothstep(40.0, 700.0, dist);
	// small ripples on top of the big swell, scrolling with the wind
	vec2 p = v_world.xz;
	float t = ocean_time;
	vec2 e = vec2(0.12, 0.0);
	vec2 q = p * 0.33 + vec2(t * 0.35, t * 0.12);
	float h0 = fbm(q);
	vec2 g = vec2(fbm(q + e.xy) - h0, fbm(q + e.yx) - h0) / e.x;
	vec2 q2 = p * 1.1 - vec2(t * 0.5, -t * 0.3);
	float h2 = fbm(q2);
	g += vec2(fbm(q2 + e.xy) - h2, fbm(q2 + e.yx) - h2) / e.x * 0.2;
	vec3 wn = (INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz;
	wn = normalize(wn + vec3(-g.x, 0.0, -g.y) * 0.07 * near);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	float ndv = clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	float crest = clamp(v_height / v_amp_scale * 0.5 + 0.5, 0.0, 1.0);
	vec3 water = mix(deep_color, shallow_color, crest * 0.55 + 0.15 * h0);
	// foam: crest lines broken up by noise, plus streaks in the troughs of the ripple field
	float breakup = fbm(p * 0.8 + vec2(t * 0.15, 0.0));
	float foam = clamp(v_foam * (0.4 + 1.2 * breakup) + smoothstep(0.8, 0.95, h2) * crest * 0.25 * near, 0.0, 1.0);
	vec3 col = mix(water, foam_color, foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.85, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = 0.5 * fresnel * sky_color * (1.0 - foam) + shallow_color * 0.2 * crest * crest * (1.0 - foam);
}
