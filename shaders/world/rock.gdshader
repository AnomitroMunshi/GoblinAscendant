shader_type spatial;
// Triplanar stone (boulders, cliffs, ruins, cave shell, castle) with moss on
// upward faces. Vertex/instance COLOR tints the texture (tint_strength).
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.35;
uniform float moss_amount = 0.6;
uniform float tint_strength = 0.5;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

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
	vec3 N = normalize(wnrm);
	if (!FRONT_FACING) {
		N = -N;
	}
	vec3 bw = pow(abs(N), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 q = wpos * tex_scale;
	vec3 c = texture(albedo_tex, q.zy).rgb * bw.x + texture(albedo_tex, q.xz).rgb * bw.y + texture(albedo_tex, q.xy).rgb * bw.z;
	vec2 tx = texture(normal_tex, q.zy).xy * 2.0 - 1.0;
	vec2 ty = texture(normal_tex, q.xz).xy * 2.0 - 1.0;
	vec2 tz = texture(normal_tex, q.xy).xy * 2.0 - 1.0;
	vec3 n = normalize(vec3(N.x, tx.y + N.y, tx.x + N.z) * bw.x + vec3(ty.x + N.x, N.y, ty.y + N.z) * bw.y + vec3(tz.x + N.x, tz.y + N.y, N.z) * bw.z);
	// tint from vertex colour (authored in sRGB; ~0.5 grey = neutral)
	vec3 vc = clamp(COLOR.rgb, vec3(0.0), vec3(2.0));
	vc = vc * vc * (0.3 * vc + 0.7);
	vec3 tint = clamp(vc / 0.2, vec3(0.0), vec3(2.0));
	c *= mix(vec3(1.0), tint, tint_strength);
	// moss on top faces, broken up by noise
	float mn = vnoise(wpos.xz * 0.6 + wpos.y * 0.3);
	float big = texture(moss_tex, wpos.xz * 0.07 + wpos.y * 0.05).g;
	float m = smoothstep(0.45, 0.95, N.y + (big - 0.35) * 1.2 + (mn - 0.5) * 0.3) * moss_amount * 0.85;
	if (m > 0.001) {
		vec3 mc = texture(moss_tex, wpos.xz * 0.5).rgb;
		mc = mix(mc, vec3(dot(mc, vec3(0.3, 0.59, 0.11))), 0.35) * vec3(0.62, 0.66, 0.5);
		vec2 mt = texture(moss_nrm, wpos.xz * 0.5).xy * 2.0 - 1.0;
		c = mix(c, mc, m);
		n = normalize(mix(n, normalize(vec3(mt.x + N.x, N.y, mt.y + N.z)), m));
	}
	ALBEDO = c;
	ROUGHNESS = mix(0.82, 0.95, m);
	SPECULAR = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
