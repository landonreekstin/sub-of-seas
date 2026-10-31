// The painted toon look every opaque primitive shares (Build.mat): the palette colour,
// broken up by hand-painted blotches and a slight per-piece shade so no two plates match,
// times the grey detail map (triplanar, in the piece's own space so it rides along on a
// moving ship), bumped by its height map (seams sink, rivets and tread stand up, the hollows
// hold grime), lit in soft-edged toon bands with a warm rim on the lit side.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_detail = false;
uniform float detail_scale = 1.0; // repeats per metre
uniform sampler2D height_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float bump = 0.0; // how hard the height map bends the light
uniform float cavity = 0.0; // how dark the low places of the height map get
uniform float roughness = 0.75;
uniform float paint = 1.0; // how strong the painted variation is
uniform bool vertex_color = false; // multiply in the mesh's vertex colours (terrain)
uniform float paint_scale = 1.0; // blotches per metre (big plating gets big, soft ones)

varying vec3 local_pos;
varying vec3 local_norm;
varying vec3 seed;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_norm = NORMAL;
	seed = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (vertex_color) {
		col *= COLOR.rgb;
	}
	// Hand-painted: big soft blotches of lighter and darker paint, a warm/cool drift
	// between them, and each piece a touch different from its neighbour.
	vec3 p = (local_pos + seed * 0.37) * paint_scale;
	float blot = noise(p * 1.3) * 0.65 + noise(p * 3.7) * 0.35;
	float piece = hash(floor(seed * 4.0) + 0.5) - 0.5;
	col *= 1.0 + ((blot - 0.5) * 0.34 + piece * 0.12) * paint;
	col = mix(col, col * vec3(1.05, 1.0, 0.92), clamp((blot - 0.45) * 2.0, 0.0, 1.0) * 0.5 * paint);
	col = mix(col, col * vec3(0.94, 0.98, 1.06), clamp((0.45 - blot) * 2.0, 0.0, 1.0) * 0.5 * paint);
	if (use_detail) {
		vec3 w = pow(abs(local_norm), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 q = local_pos * detail_scale;
		vec2 ux = vec2(q.z, -q.y);
		vec2 uy = q.xz;
		vec2 uz = vec2(q.x, -q.y);
		vec3 d = texture(detail, ux).rgb * w.x + texture(detail, uy).rgb * w.y + texture(detail, uz).rgb * w.z;
		col *= d;
		if (bump > 0.0 || cavity > 0.0) {
			// Height, and its slope one texel across, in each of the three projections.
			float e = 1.5 / 512.0;
			float hx = texture(height_map, ux).r;
			float hy = texture(height_map, uy).r;
			float hz = texture(height_map, uz).r;
			vec2 gx = vec2(texture(height_map, ux + vec2(e, 0.0)).r - hx, texture(height_map, ux + vec2(0.0, e)).r - hx);
			vec2 gy = vec2(texture(height_map, uy + vec2(e, 0.0)).r - hy, texture(height_map, uy + vec2(0.0, e)).r - hy);
			vec2 gz = vec2(texture(height_map, uz + vec2(e, 0.0)).r - hz, texture(height_map, uz + vec2(0.0, e)).r - hz);
			float h = hx * w.x + hy * w.y + hz * w.z;
			col *= mix(1.0, smoothstep(0.1, 0.5, h) * 0.45 + 0.55, cavity);
			// The slope as a local-space vector (u, v axes of each projection), off the normal.
			vec3 g = vec3(0.0, -gx.y, gx.x) * w.x + vec3(gy.x, 0.0, gy.y) * w.y + vec3(gz.x, -gz.y, 0.0) * w.z;
			g -= dot(g, local_norm) * local_norm;
			vec3 dv = (VIEW_MATRIX * (MODEL_MATRIX * vec4(-g * bump, 0.0))).xyz;
			NORMAL = normalize(NORMAL + dv);
		}
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}

void light() {
	// Soft toon bands: shadow, mid, lit (wrapped so the dark side isn't black).
	float ndl = dot(NORMAL, LIGHT);
	float wrap = (ndl + 0.35) / 1.35;
	float band = 0.18 + smoothstep(0.12, 0.2, wrap) * 0.37 + smoothstep(0.55, 0.62, wrap) * 0.45;
	// The lamp's falloff in soft steps too, so light lies in painted pools.
	float a = ATTENUATION;
	float pooled = 0.12 * a + 0.88 * (smoothstep(0.04, 0.1, a) * 0.3 + smoothstep(0.22, 0.3, a) * 0.3 + smoothstep(0.5, 0.6, a) * 0.4);
	float lit = band * pooled * 0.72;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	// A warm rim on the lit side picks the chunky shapes out.
	float rim = smoothstep(0.62, 0.72, 1.0 - max(dot(NORMAL, VIEW), 0.0));
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * lit * 0.18 / PI;
	// A small hard-edged highlight on the shinier things (brass, wet steel).
	vec3 h = normalize(LIGHT + VIEW);
	float shine = 1.0 - roughness;
	float spec = smoothstep(0.5, 0.56, pow(max(dot(NORMAL, h), 0.0), mix(8.0, 64.0, shine)));
	SPECULAR_LIGHT += LIGHT_COLOR * spec * shine * ATTENUATION * 0.5 / PI;
}
