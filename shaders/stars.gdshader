shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, fog_disabled, shadows_disabled;
// Night sky on the inside of a huge sphere that follows the camera: hashed stars that twinkle, and the moon.
// The day cycle fades it in with `night` and hides it behind storm clouds with `cover`.

uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_dir = vec3(0.3, 0.6, -0.7);
uniform vec3 moon_color : source_color = vec3(0.92, 0.94, 1.0);
uniform float star_time = 0.0;

varying vec3 v_dir;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float above = smoothstep(-0.02, 0.12, d.y);
	vec3 cell = floor(d * 260.0);
	float h = hash3(cell);
	float star = step(0.9935, h);
	vec3 c = fract(d * 260.0) - 0.5;
	star *= smoothstep(0.32, 0.0, length(c));
	star *= 0.55 + 0.45 * sin(star_time * (1.5 + h * 4.0) + h * 40.0);
	float md = dot(d, normalize(moon_dir));
	float moon = smoothstep(0.9988, 0.9992, md);
	float halo = pow(max(md, 0.0), 220.0) * 0.35;
	float clear_sky = 1.0 - cover;
	vec3 col = vec3(star) * clear_sky * clear_sky + moon_color * (moon * (1.0 - cover * 0.8) + halo * clear_sky);
	ALBEDO = col * night * above;
}
