shader_type spatial;
// Churning foam patch where the waterfall hits the pool. UV centred radial.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform vec3 foam_color : source_color = vec3(0.96, 0.99, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float n = vnoise(vec2(a * 3.0, r * 6.0 - TIME * 1.2)) * 0.6 + vnoise(c * 5.0 + TIME * 0.3) * 0.4;
	float m = smoothstep(1.0, 0.3, r) * smoothstep(0.25, 0.6, n + (1.0 - r) * 0.4);
	ALBEDO = foam_color;
	ALPHA = m * 0.85;
}
