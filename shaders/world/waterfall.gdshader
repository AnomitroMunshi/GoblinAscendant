shader_type spatial;
// Scrolling falling water curtain. UV.x across, UV.y top (0) -> bottom (1).
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.55, 0.82, 0.88);
uniform vec3 foam_color : source_color = vec3(0.96, 0.99, 1.0);
uniform float speed = 1.4;

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
	float t = TIME * speed;
	vec2 uv = UV;
	float s1 = vnoise(vec2(uv.x * 14.0, uv.y * 3.0 - t * 2.0));
	float s2 = vnoise(vec2(uv.x * 30.0 + 7.0, uv.y * 6.0 - t * 3.1));
	float streak = s1 * 0.6 + s2 * 0.4;
	float foam = smoothstep(0.45, 0.75, streak) ;
	foam = max(foam, smoothstep(0.75, 1.0, uv.y));       // white water at the bottom
	foam = max(foam, smoothstep(0.08, 0.0, uv.y) * 0.7);  // lip
	vec3 col = mix(water_color, foam_color, foam);
	float edge = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
	float gaps = smoothstep(0.15, 0.35, streak + uv.y * 0.3);
	ALBEDO = col;
	EMISSION = col * 0.25;
	ROUGHNESS = 0.2;
	ALPHA = clamp(edge * gaps * mix(0.7, 1.0, foam), 0.0, 1.0);
}
