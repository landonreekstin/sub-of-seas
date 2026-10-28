shader_type canvas_item;
// Round periscope eyepiece: black outside a circle, soft edge, graticule lines.

uniform vec4 line_color : source_color = vec4(0.05, 0.05, 0.05, 0.85);

void fragment() {
	vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (FRAGCOORD.xy - px * 0.5) / (px.y * 0.5); // -aspect..aspect, -1..1
	float r = length(p);
	float outside = smoothstep(0.86, 0.9, r);
	float line_w = 0.0025;
	float cross_h = step(abs(p.y), line_w) * step(abs(p.x), 0.86);
	float cross_v = step(abs(p.x), line_w) * step(abs(p.y), 0.86) * step(0.06, abs(p.y));
	// Tick marks on the horizontal line every 0.05 (roughly 1 degree in high power).
	float ticks = step(abs(p.y), 0.02) * step(fract(p.x * 20.0 + 0.5), 0.08) * step(abs(p.x), 0.6);
	float lines = max(max(cross_h, cross_v), ticks);
	vec4 c = vec4(0.0);
	c = mix(c, line_color, lines);
	c = mix(c, vec4(0.0, 0.0, 0.0, 1.0), outside);
	// Slight vignette inside the lens.
	c.a = max(c.a, smoothstep(0.5, 0.88, r) * 0.35);
	COLOR = c;
}
