shader_type spatial;
// Trees / bushes: sRGB vertex colours (soft baked gradients), wind sway
// weighted by COLOR.a (0 trunk base .. 1 canopy). Instance colour tints.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform float sway_strength = 1.0;
uniform float wind_speed = 1.1;
uniform float translucency = 0.35;

varying float v_sway;

void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	float w = COLOR.a;
	v_sway = w;
	float t = TIME * wind_speed + ip.x * 0.045 + ip.z * 0.06;
	float gust = 0.65 + 0.35 * sin(TIME * 0.31 + ip.x * 0.01);
	vec3 off = vec3(sin(t), 0.0, cos(t * 0.83 + 1.3)) * 0.14 * gust;
	off += vec3(sin(t * 3.7 + VERTEX.y * 1.3), sin(t * 4.1 + VERTEX.x) * 0.4, cos(t * 3.3 + VERTEX.z * 1.1)) * 0.035;
	VERTEX += off * w * sway_strength;
}

void fragment() {
	vec3 c = COLOR.rgb;
	// vertex colours are authored in sRGB
	c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	ALBEDO = c;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
	BACKLIGHT = c * translucency * v_sway;
}
