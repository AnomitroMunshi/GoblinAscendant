shader_type spatial;
// Wildflowers (MultiMesh). Vertex COLOR.a = petal mask, UV.y = sway weight.
// INSTANCE_CUSTOM.rgb = petal colour.
render_mode diffuse_lambert_wrap, cull_disabled, specular_disabled, shadows_disabled;

uniform float fade_start = 45.0;
uniform float fade_end = 65.0;

varying vec3 v_petal;
varying float v_mask;

void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	v_petal = INSTANCE_CUSTOM.rgb;
	v_mask = COLOR.a;
	float dist = length(ip - CAMERA_POSITION_WORLD);
	float shrink = 1.0 - smoothstep(fade_start, fade_end, dist);
	float t = TIME * 1.4 + ip.x * 0.2 + ip.z * 0.17;
	VERTEX.xz += vec2(sin(t), cos(t * 0.9)) * 0.06 * UV.y;
	VERTEX *= shrink;
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6);
}

void fragment() {
	vec3 stem = COLOR.rgb;
	stem = mix(stem / 12.92, pow((stem + 0.055) / 1.055, vec3(2.4)), step(0.04045, stem));
	vec3 petal = mix(v_petal / 12.92, pow((v_petal + 0.055) / 1.055, vec3(2.4)), step(0.04045, v_petal));
	vec3 c = mix(stem, petal, v_mask);
	ALBEDO = c;
	ROUGHNESS = 0.8;
	EMISSION = petal * v_mask * 0.08;
	BACKLIGHT = c * 0.3;
}
