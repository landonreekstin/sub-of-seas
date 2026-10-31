shader_type spatial;
// A rain squall seen from outside: a grey curtain hanging from the cloud base, streaked and
// thickest through its middle, thinning to the edges and up into the cloud. Unshaded, but it
// takes the scene's fog so far squalls sink into the haze.
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.36, 0.40, 0.45, 1.0);
uniform float strength = 1.0;

float hash(float x) {
	return fract(sin(x * 91.345) * 47453.53);
}

void fragment() {
	// Through the middle of the curtain the eye looks through the most rain.
	float through = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 0.6);
	// Veils: broad sheets of heavier and lighter rain drifting round the squall.
	float veil = 0.55 + 0.45 * sin(UV.x * TAU * 7.0 + sin(UV.x * TAU * 3.0) * 2.0 + TIME * 0.05);
	// Streaks: fine columns of rain falling at different speeds, a little slanted.
	float u = UV.x * 900.0 + UV.y * 10.0;
	float col_id = floor(u);
	float fall = fract(UV.y * (3.0 + hash(col_id) * 4.0) - TIME * (0.25 + hash(col_id + 3.1) * 0.2));
	float streak = mix(0.8, 1.0, smoothstep(0.2, 0.9, fall) * step(0.4, hash(col_id + 7.7)));
	// Fading up into the cloud base.
	float top = smoothstep(0.0, 0.3, UV.y);
	float alpha = strength * (0.6 + 0.4 * through) * mix(0.7, 1.0, veil) * streak * top;
	ALBEDO = color.rgb * mix(0.85, 1.05, streak) * mix(0.9, 1.05, veil);
	ALPHA = clamp(alpha, 0.0, 0.93);
}
