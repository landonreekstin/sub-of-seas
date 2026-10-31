// The painted sky (world/toon_sky.gd): a gradient from the horizon up, chunky toon clouds
// with flat shaded bellies drifting on the wind, a soft sun, and stars on a clear night.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.247, 0.498, 0.749, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.749, 0.847, 0.910, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.749, 0.847, 0.910, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.122, 0.306, 0.475, 1.0);
uniform float cloud_cover = 0.45; // 0 clear .. 1 overcast
uniform vec4 cloud_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.62, 0.70, 0.80, 1.0);
uniform float night = 0.0;

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
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col;
	if (d.y >= 0.0) {
		col = mix(horizon_color.rgb, top_color.rgb, clamp(pow(d.y, 0.55), 0.0, 1.0));
	} else {
		col = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, clamp(pow(-d.y, 0.4), 0.0, 1.0));
	}
	if (!AT_CUBEMAP_PASS && d.y > 0.0) {
		// Stars, on a clear night.
		vec2 sg = floor(d.xz / (d.y + 0.3) * 260.0);
		float star = step(0.9975, hash(sg)) * night * smoothstep(0.05, 0.3, d.y);
		col += vec3(star) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(sg + 3.0) * 30.0));
		// Clouds on a flat ceiling, flattened toward the horizon, drifting.
		vec2 uv = d.xz / (d.y + 0.12) * 1.6 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv);
		float edge = 1.0 - cloud_cover * 0.75;
		float body = smoothstep(edge, edge + 0.04, n);
		// Lit tops, shaded bellies: the same noise a little toward the sun is thinner on top.
		vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
		float lit = smoothstep(edge + 0.02, edge + 0.12, fbm(uv - sun.xz * 0.08));
		vec3 cc = mix(cloud_shade.rgb, cloud_color.rgb, 1.0 - smoothstep(0.3, 0.32, lit) * 0.7);
		float fade = smoothstep(0.0, 0.04, d.y);
		col = mix(col, mix(col, cc, 0.92), body * fade);
	}
	if (!AT_CUBEMAP_PASS && LIGHT0_ENABLED) {
		// A soft round sun (or moon) with a glow.
		float s = dot(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * (smoothstep(0.9993, 0.9995, s) * 1.2 + pow(max(s, 0.0), 300.0) * 0.25) * (1.0 - night * 0.7);
	}
	COLOR = col;
}
