// Shared soft two-band lighting for the cartoon surfaces: shaded faces never go below `shade` of the lit colour.
uniform float shade : hint_range(0.0, 1.0) = 0.55;
uniform float soft : hint_range(0.01, 0.6) = 0.14;

void light() {
	float nl = dot(NORMAL, LIGHT);
	float band = smoothstep(-soft * 0.5, soft * 0.5, nl);
	float lit = mix(shade, 1.0, band);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit * clamp(nl * 0.5 + 0.5, 0.0, 1.0) / PI;
}
