shader_type spatial;
// Stylised open ocean: three Gerstner waves in world space, faded out with distance,
// deep-to-turquoise colour by facing angle and white foam on the crests.

uniform vec4 deep_color : source_color = vec4(0.03, 0.12, 0.24, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.06, 0.30, 0.38, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.55, 0.70, 0.82, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float amplitude = 0.5;
uniform float fade_start = 300.0;
uniform float fade_end = 1800.0;

varying float v_crest;
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
	VERTEX += offset * v_fade;
	v_crest = offset.y * v_fade;
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(cross(binormal, tangent)), v_fade));
}

void fragment() {
	// Looking down into the water shows turquoise; at grazing angles it reads deep blue.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, pow(facing, 1.5));
	float fresnel = pow(1.0 - facing, 5.0);
	col = mix(col, horizon_color.rgb, fresnel * 0.45);
	float foam = smoothstep(1.6 * amplitude, 2.4 * amplitude, v_crest);
	col = mix(col, foam_color.rgb, foam * 0.8);
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.7, foam);
	SPECULAR = 0.3;
}
