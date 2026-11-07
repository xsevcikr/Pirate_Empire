shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, specular_schlick_ggx;
// Gerstner ocean. Wave parameters come from WaveModel so the CPU surface matches.
// wave_a[i] = (dir.x, dir.y, k, amplitude); wave_b[i] = (Q, omega, phase, 0)

const int WAVES = 12;

uniform vec4 wave_a[12];
uniform vec4 wave_b[12];
uniform float ocean_time = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.08, 0.78, 0.74);
uniform vec3 deep_color : source_color = vec3(0.01, 0.16, 0.30);
uniform vec3 sky_color : source_color = vec3(0.55, 0.7, 0.9);
uniform float murk : hint_range(0.0, 1.0) = 0.0;  // bad weather: the bright blues go slate grey-green
uniform vec3 foam_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float fade_start = 900.0;
uniform float fade_end = 3000.0;

varying float v_height;
varying float v_foam;
varying float v_amp_scale;
varying vec3 v_world;
varying float v_crest;

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
	v_crest = clamp(disp.y / v_amp_scale * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(v_world.xz, cam.xz);
	float near = 1.0 - smoothstep(40.0, 700.0, dist);
	vec2 p = v_world.xz;
	float t = ocean_time;
	// cartoon sea: three flat blue bands picked by wave height and a slow noise, white crisp foam on the crests
	float h0 = fbm(p * 0.05 + vec2(t * 0.08, t * 0.03));
	float h1 = fbm(p * 0.22 - vec2(t * 0.12, -t * 0.07));
	float crest = clamp(v_height / v_amp_scale * 0.5 + 0.5, 0.0, 1.0);
	float level = crest * 0.55 + h0 * 0.35 + h1 * 0.2;
	vec3 deep = vec3(0.05, 0.36, 0.62);
	vec3 mid = vec3(0.09, 0.52, 0.78);
	vec3 light_c = vec3(0.22, 0.7, 0.9);
	vec3 col = mix(deep, mid, step(0.5, level));
	col = mix(col, light_c, step(0.8, level));
	float grey = dot(col, vec3(0.3, 0.5, 0.2));
	col = mix(col, vec3(grey) * vec3(0.78, 0.95, 0.98), murk * 0.85) * (1.0 - murk * 0.4);
	float breakup = fbm(p * 0.7 + vec2(t * 0.15, 0.0));
	float foam = step(0.55, v_foam * (0.4 + 1.2 * breakup)) + step(0.9, h1) * step(0.55, crest) * near;
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// sun sparkles on the swell: tiny cells that blink on and off
	vec2 cell = floor(p * 2.5 + vec2(t * 0.5, t * 0.3));
	float tw = hash(cell) ;
	float blink = step(0.992, tw) * step(0.0, sin(t * 3.0 + tw * 40.0));
	EMISSION = col * 0.05 + vec3(1.0, 0.97, 0.85) * blink * near * (1.0 - foam) * 0.9;
}


// Soft two-band light on the swell, with a hard little sun glint on the facing slopes.
void light() {
	float nl = dot(NORMAL, LIGHT);
	float lit = mix(0.7, 1.0, smoothstep(-0.05, 0.1, nl));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI * 0.9;
	vec3 h = normalize(LIGHT + VIEW);
	float glint = step(0.992, dot(NORMAL, h));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * 0.8;
}
