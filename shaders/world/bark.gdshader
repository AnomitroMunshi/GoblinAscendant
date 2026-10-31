shader_type spatial;
// Triplanar bark / wood. COLOR.rgb tints (sRGB, ~0.5 neutral), COLOR.a = wind sway weight.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.6;
uniform float moss_amount = 0.15;
uniform float sway_strength = 1.0;
uniform float wind_speed = 1.1;
uniform vec2 lod_band = vec2(0.0, 100000.0);  // draw instances whose distance to view_pos is in [x, y)
uniform vec3 view_pos = vec3(0.0);             // gameplay camera (set by WorldRoot each frame; shadow-pass safe)

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ip = MODEL_MATRIX[3].xyz;
	float t = TIME * wind_speed + ip.x * 0.045 + ip.z * 0.06;
	float gust = 0.65 + 0.35 * sin(TIME * 0.31 + ip.x * 0.01);
	VERTEX += vec3(sin(t), 0.0, cos(t * 0.83 + 1.3)) * 0.12 * gust * COLOR.a * sway_strength;
	float lod_d = length(MODEL_MATRIX[3].xyz - view_pos);
	if (lod_d < lod_band.x || lod_d >= lod_band.y) {
		VERTEX = vec3(0.0);  // collapse: this instance is drawn by another LOD
	}
}

void fragment() {
	vec3 N = normalize(wnrm);
	vec3 bw = pow(abs(N), vec3(3.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 q = wpos * tex_scale;
	vec3 c = texture(albedo_tex, q.zy).rgb * bw.x + texture(albedo_tex, q.xz).rgb * bw.y + texture(albedo_tex, q.xy).rgb * bw.z;
	vec2 tx = texture(normal_tex, q.zy).xy * 2.0 - 1.0;
	vec2 ty = texture(normal_tex, q.xz).xy * 2.0 - 1.0;
	vec2 tz = texture(normal_tex, q.xy).xy * 2.0 - 1.0;
	vec3 n = normalize(vec3(N.x, tx.y + N.y, tx.x + N.z) * bw.x + vec3(ty.x + N.x, N.y, ty.y + N.z) * bw.y + vec3(tz.x + N.x, tz.y + N.y, N.z) * bw.z);
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.35) * 0.62;
	vec3 vc = clamp(COLOR.rgb, vec3(0.0), vec3(2.0));
	vc = vc * vc * (0.3 * vc + 0.7);
	c *= clamp(vc / 0.2, vec3(0.0), vec3(2.5));
	// moss on the upper side of branches / logs
	float m = smoothstep(0.3, 0.9, N.y) * moss_amount;
	c = mix(c, texture(moss_tex, wpos.xz * 0.6).rgb * 0.85, m);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
