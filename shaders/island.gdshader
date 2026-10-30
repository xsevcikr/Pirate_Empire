shader_type spatial;
// Cartoon terrain: flat-shaded facets in bright vertex colours, steep faces in banded rock, soft two-band toon light.

uniform vec3 rock_color : source_color = vec3(0.55, 0.55, 0.62);
uniform float saturation = 1.0;
uniform float rim_amount = 0.12;

varying vec3 v_obj;
varying flat vec4 v_col;
varying vec3 v_view;

void vertex() {
	v_obj = VERTEX;
	v_col = COLOR;
}

void fragment() {
	// flat facets: the normal comes from the screen-space slope of the surface
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	float slope = 1.0 - clamp(world_n.y, 0.0, 1.0);
	vec3 c = pow(v_col.rgb, vec3(1.45));
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation) * 1.2;
	float rocky = step(0.42, slope);
	float band = floor(v_obj.y * 0.35);
	vec3 strata = rock_color * (0.85 + 0.15 * mod(band, 2.0));
	c = mix(c, strata, rocky);
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = ALBEDO * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount;
}

#include "res://shaders/toon.gdshaderinc"
