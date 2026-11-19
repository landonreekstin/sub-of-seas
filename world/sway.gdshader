// Kelp and sea grass: blades that lean and sway in the swell, more the higher up the blade,
// each plant on its own beat (from where it stands). Instance colour times vertex colour, lit
// in two soft toon bands, both sides of a blade. All the movement is here, so the plants cost
// the CPU nothing once they're placed.
shader_type spatial;
render_mode cull_disabled;

uniform float sway = 0.35; // metres of sway per metre up the blade
uniform float speed = 0.9;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = root.x * 0.13 + root.z * 0.17;
	float h = max(VERTEX.y, 0.0);
	float bend = h * h / (1.0 + h) * sway;
	VERTEX.x += sin(TIME * speed + phase) * bend;
	VERTEX.z += cos(TIME * speed * 0.7 + phase * 1.3) * bend * 0.6;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
}

void light() {
	float n = abs(dot(NORMAL, LIGHT));
	float lit = smoothstep(0.15, 0.35, n) * 0.6 + 0.4;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit * ALBEDO / PI;
}
