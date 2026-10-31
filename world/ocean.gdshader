shader_type spatial;
render_mode cull_disabled;
// Stylised open ocean: five Gerstner waves in world space, faded out with distance, small
// ripples bending the light, deep-to-turquoise colour by facing angle with the crests glowing
// turquoise where the light comes through them, lacy cellular foam on the crests, a hard
// sun glint in toon steps, and the white
// wakes and bow waves of up to 16 ships, and the bubble tracks of up to 8 torpedoes. Seen from
// below it is a bright, rippling ceiling of light.

uniform vec4 deep_color : source_color = vec4(0.03, 0.17, 0.30, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.05, 0.44, 0.50, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.55, 0.70, 0.82, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform vec4 crest_color : source_color = vec4(0.25, 0.85, 0.80, 1.0);
uniform float amplitude = 0.5;
uniform float fade_start = 300.0;
uniform float fade_end = 1800.0;
// Ships for wakes: (x, z, heading in radians, speed m/s), and their lengths.
uniform vec4 ships[16];
uniform float ship_len[16];
uniform int ship_count = 0;
// Torpedo tracks: (launch x, z, head x, z), and (seconds since it hit or ran out, speed m/s).
uniform vec4 torps[8];
uniform vec2 torp_life[8];
uniform int torp_count = 0;
// Rain squalls: (x, z, radius, strength) in world space. Rain dulls and roughens the sea under
// them and pocks it with drops.
uniform vec4 squalls[8];
uniform int squall_count = 0;

varying float v_crest;
varying float v_foam;
varying float v_fade;

vec3 gerstner(vec4 wave, vec2 p, inout vec3 tangent, inout vec3 binormal) {
	float steep = wave.z * amplitude;
	float k = 2.0 * PI / wave.w;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(wave.xy);
	float f = k * (dot(d, p) - c * TIME);
	float a = steep / k;
	tangent += vec3(-d.x * d.x * steep * sin(f), d.x * steep * cos(f), -d.x * d.y * steep * sin(f));
	binormal += vec3(-d.x * d.y * steep * sin(f), d.y * steep * cos(f), -d.y * d.y * steep * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	v_fade = 1.0 - smoothstep(fade_start, fade_end, distance(world.xz, cam.xz));
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 offset = vec3(0.0);
	offset += gerstner(vec4(1.0, 0.35, 0.20, 46.0), world.xz, tangent, binormal);
	offset += gerstner(vec4(0.6, -0.8, 0.16, 23.0), world.xz, tangent, binormal);
	offset += gerstner(vec4(-0.3, 1.0, 0.12, 11.0), world.xz, tangent, binormal);
	offset += gerstner(vec4(0.9, 0.6, 0.08, 6.3), world.xz, tangent, binormal);
	offset += gerstner(vec4(-0.7, -0.4, 0.06, 3.7), world.xz, tangent, binormal);
	VERTEX += offset * v_fade;
	v_crest = offset.y * v_fade;
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(cross(binormal, tangent)), v_fade));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Cellular foam: thin bright lines along the edges between moving cells (F2 - F1 small).
float lace(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.5 * sin(TIME * 0.6 + 6.2831 * o);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return 1.0 - smoothstep(0.03, 0.12, f2 - f1);
}

// White water behind and around a ship: a narrow churned trail astern that widens and fades,
// and a bow wave curling off the stem. 0..1.
float wake(vec2 p) {
	float w = 0.0;
	for (int i = 0; i < ship_count; i++) {
		vec4 s = ships[i];
		if (s.w < 0.5) {
			continue;
		}
		vec2 fwd = vec2(sin(s.z), -cos(s.z)); // heading 0 = north = -z
		vec2 rel = p - s.xy;
		float along = dot(rel, fwd);
		float across = abs(dot(rel, vec2(-fwd.y, fwd.x)));
		float half_len = ship_len[i] * 0.5;
		float astern = -along - half_len;
		float trail_len = 60.0 * s.w;
		if (astern > -half_len && astern < trail_len) {
			float width = 4.0 + max(astern, 0.0) * 0.12;
			float t = clamp(astern / trail_len, 0.0, 1.0);
			w = max(w, (1.0 - smoothstep(width * 0.6, width, across)) * (1.0 - t) * min(1.0, s.w / 4.0));
		}
		float bow = along - half_len * 0.8;
		if (bow > -half_len * 0.4 && bow < 6.0) {
			w = max(w, (1.0 - smoothstep(4.0, 9.0, across + bow * 0.5)) * min(1.0, s.w / 5.0) * 0.8);
		}
	}
	return w;
}

// A torpedo's bubble track, launch to head: a tight bright line at the head that spreads
// and breaks up as it ages, gone about a minute after the fish passed. 0..1.
float torp_track(vec2 p, float n) {
	float w = 0.0;
	for (int i = 0; i < torp_count; i++) {
		vec2 a = torps[i].xy;
		vec2 b = torps[i].zw;
		vec2 seg = b - a;
		float len = max(length(seg), 0.001);
		vec2 dir = seg / len;
		float along = clamp(dot(p - a, dir), 0.0, len);
		float across = distance(p, a + dir * along);
		float age = (len - along) / max(torp_life[i].y, 1.0) + torp_life[i].x;
		float width = 0.7 + age * 0.035;
		float line = 1.0 - smoothstep(width * 0.3, width, across);
		float fresh = mix(0.95, 0.35, smoothstep(0.0, 12.0, age)) * (1.0 - smoothstep(30.0, 70.0, age));
		float broken = mix(1.0, smoothstep(0.35, 0.75, n), clamp(age / 8.0, 0.0, 1.0));
		w = max(w, line * fresh * broken);
	}
	return w;
}

void fragment() {
	// Looking down into the water shows turquoise; at grazing angles it reads deep blue.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, pow(facing, 1.5));
	float fresnel = pow(1.0 - facing, 5.0);
	col = mix(col, horizon_color.rgb, fresnel * 0.45);
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = vnoise(world.xz * 0.35 + TIME * 0.2) * 0.6 + vnoise(world.xz * 1.3 - TIME * 0.3) * 0.4;
	// Small ripples bend the light: the slope of two drifting noise layers.
	float e = 0.15;
	vec2 rp = world.xz * 0.45;
	float r0 = vnoise(rp + TIME * 0.35) + vnoise(rp * 2.3 - TIME * 0.5) * 0.5;
	float rx = vnoise(rp + vec2(e, 0.0) + TIME * 0.35) + vnoise((rp + vec2(e, 0.0)) * 2.3 - TIME * 0.5) * 0.5;
	float rz = vnoise(rp + vec2(0.0, e) + TIME * 0.35) + vnoise((rp + vec2(0.0, e)) * 2.3 - TIME * 0.5) * 0.5;
	float rain = 0.0;
	for (int i = 0; i < squall_count; i++) {
		float d = distance(world.xz, squalls[i].xy);
		rain = max(rain, squalls[i].w * smoothstep(squalls[i].z, squalls[i].z * 0.55, d));
	}
	vec3 slope = vec3(rx - r0, 0.0, rz - r0) * (0.9 + rain * 1.4) * v_fade;
	NORMAL = normalize(NORMAL - (VIEW_MATRIX * vec4(slope, 0.0)).xyz);
	// The light through the crests: a glowing turquoise near the tops of the waves.
	col = mix(col, crest_color.rgb, smoothstep(0.1 * amplitude, 1.6 * amplitude, v_crest) * 0.55 * (0.4 + 0.6 * facing));
	float foam = smoothstep(1.4 * amplitude, 2.3 * amplitude, v_crest + n * 0.5 * amplitude);
	// Lace: foam lines spreading down the faces of the bigger waves, and faint on the flats.
	float lc = lace(world.xz * 0.28 + vec2(TIME * 0.05, 0.0));
	foam = max(foam, lc * smoothstep(0.6 * amplitude, 1.8 * amplitude, v_crest + n * 0.6 * amplitude) * 0.9);
	foam = max(foam, lc * 0.35 * smoothstep(0.55, 0.85, vnoise(world.xz * 0.04 + TIME * 0.02)) * v_fade);
	foam = max(foam, wake(world.xz) * smoothstep(0.25, 0.6, n));
	foam = max(foam, torp_track(world.xz, n));
	// Under a squall: a dull grey-green sea, pocked white by the drops close up.
	col = mix(col, mix(deep_color.rgb, vec3(0.33, 0.38, 0.41), 0.6), rain * 0.75);
	col = mix(col, foam_color.rgb, foam * 0.85);
	vec2 cell = floor(world.xz * 3.0);
	float drop = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float pock = step(0.92, fract(drop * 7.0 + TIME * (0.6 + drop))) * smoothstep(0.35, 0.1, length(fract(world.xz * 3.0) - 0.5));
	col = mix(col, foam_color.rgb, pock * rain * v_fade * 0.7);
	if (!FRONT_FACING) {
		// The surface from underneath: bright and rippling, the daylight coming through it,
		// with wakes and torpedo tracks showing as white water.
		float ripple = vnoise(world.xz * 0.6 + TIME * 0.5) * 0.5 + vnoise(world.xz * 2.1 - TIME * 0.7) * 0.5;
		col = mix(vec3(0.42, 0.80, 0.86), vec3(0.85, 0.98, 1.0), smoothstep(0.45, 0.8, ripple));
		col = mix(col, vec3(1.0), foam * 0.6);
		EMISSION = col * 0.5;
		foam = 0.0;
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.7, foam);
	SPECULAR = 0.3;
	v_foam = foam;
}

void light() {
	// Soft toon bands on the water, and the sun's glint as hard bright flecks.
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.55 + smoothstep(0.0, 0.25, ndl) * 0.3 + smoothstep(0.5, 0.7, ndl) * 0.15;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float glint = smoothstep(0.86, 0.9, pow(max(dot(NORMAL, h), 0.0), 220.0)) * (1.0 - v_foam);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (glint * 3.0 + pow(max(dot(NORMAL, h), 0.0), 60.0) * 0.25);
}
