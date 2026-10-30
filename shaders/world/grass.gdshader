shader_type spatial;
// Grass tufts (MultiMesh). COLOR.rgb = per-instance tint * blade grade,
// COLOR.a (vertex) = height along blade (0 root .. 1 tip).
// Blades shrink into the ground with distance so the fade-out is invisible.
render_mode diffuse_lambert_wrap, cull_disabled, specular_disabled, shadows_disabled;

uniform vec3 root_color : source_color = vec3(0.20, 0.42, 0.13);
uniform vec3 tip_color : source_color = vec3(0.55, 0.75, 0.28);
uniform float fade_start = 40.0;
uniform float fade_end = 60.0;
uniform float wind_speed = 1.6;

varying float v_h;
varying vec3 v_tint;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 ip = MODEL_MATRIX[3].xyz;
	float h = COLOR.a;
	v_h = h;
	v_tint = COLOR.rgb;
	float dist = length(ip - CAMERA_POSITION_WORLD);
	float shrink = 1.0 - smoothstep(fade_start, fade_end, dist);
	float t = TIME * wind_speed + ip.x * 0.15 + ip.z * 0.11;
	float gust = 0.6 + 0.4 * sin(TIME * 0.5 + ip.x * 0.03 + ip.z * 0.02);
	VERTEX.xz += vec2(sin(t), cos(t * 0.8)) * 0.12 * h * h * gust;
	VERTEX.y *= shrink;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 tint = v_tint;
	tint = mix(tint / 12.92, pow((tint + 0.055) / 1.055, vec3(2.4)), step(0.04045, tint));
	vec3 c = mix(root_color, tip_color, smoothstep(0.0, 1.0, v_h)) * tint * 1.6;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.3;
}
