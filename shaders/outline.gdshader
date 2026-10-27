shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
// Inverted-hull outline: the model drawn again from the inside, pushed outwards a fixed number of screen pixels.

uniform vec3 line_color : source_color = vec3(0.12, 0.13, 0.22);
uniform float pixels : hint_range(0.0, 6.0) = 1.6;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = n.xy;
	if (length(dir) > 0.0001) {
		clip.xy += normalize(dir) * pixels * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = line_color;
}
