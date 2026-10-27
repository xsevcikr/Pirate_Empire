shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, specular_schlick_ggx;
// Gerstner ocean. Wave parameters come from WaveModel so the CPU surface matches.
// wave_a[i] = (dir.x, dir.y, k, amplitude); wave_b[i] = (Q, omega, phase, 0)

const int WAVES = 12;

uniform vec4 wave_a[12];
uniform vec4 wave_b[12];
uniform float ocean_time = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.247, 0.816, 0.788);
uniform vec3 deep_color : source_color = vec3(0.043, 0.165, 0.29);
uniform vec3 sky_color : source_color = vec3(0.55, 0.7, 0.9);
uniform vec3 foam_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float fade_start = 900.0;
uniform float fade_end = 3000.0;

varying float v_height;
varying float v_foam;
varying float v_amp_scale;

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
}

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	float crest = clamp(v_height / v_amp_scale * 0.5 + 0.5, 0.0, 1.0);
	vec3 water = mix(deep_color, shallow_color, crest * 0.5);
	vec3 col = mix(water, foam_color, v_foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.08, 0.85, v_foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	// Sky reflection and crest subsurface glow
	EMISSION = 0.45 * fresnel * sky_color * (1.0 - v_foam) + shallow_color * 0.12 * crest * crest * (1.0 - v_foam);
}
