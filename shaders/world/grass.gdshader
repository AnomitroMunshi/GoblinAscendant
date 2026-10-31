shader_type spatial;
// Grass tufts (MultiMesh). Blade colour is sampled from the ground grass
// texture under each tuft so blades match the terrain, then graded root->tip.
// Vertex COLOR.a = height along blade. Instance COLOR.rgb = tint (~1).
// Blades shrink into the ground with distance so the fade-out is invisible.
render_mode diffuse_lambert_wrap, cull_disabled, specular_schlick_ggx, shadows_disabled;

uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float ground_scale = 0.28;
uniform vec3 root_shade : source_color = vec3(0.6, 0.66, 0.52);
uniform vec3 tip_tint : source_color = vec3(1.0, 1.08, 0.82);
uniform float fade_start = 40.0;
uniform float fade_end = 60.0;
uniform float wind_speed = 1.6;

varying float v_h;
varying vec3 v_col;

void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	float h = COLOR.a;
	v_h = h;
	vec3 g = textureLod(ground_tex, ip.xz * ground_scale * 0.13, 3.0).rgb;
	v_col = g * clamp(COLOR.rgb, vec3(0.0), vec3(2.0));
	float dist = length(ip - CAMERA_POSITION_WORLD);
	float shrink = 1.0 - smoothstep(fade_start, fade_end, dist);
	float t = TIME * wind_speed + ip.x * 0.15 + ip.z * 0.11;
	float gust = 0.6 + 0.4 * sin(TIME * 0.5 + ip.x * 0.03 + ip.z * 0.02);
	VERTEX.xz += vec2(sin(t), cos(t * 0.8)) * 0.1 * h * h * gust;
	VERTEX.y *= shrink;
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7);
}

void fragment() {
	vec3 c = v_col * mix(root_shade, tip_tint, smoothstep(0.0, 1.0, v_h));
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = c * 0.35;
}
