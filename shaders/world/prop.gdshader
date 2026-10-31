shader_type spatial;
// Merged prop geometry (ruins, camps, bridge, cave, castle, rocks in props).
// Vertex colours are authored in sRGB; the material class is inferred from the
// colour so one draw call can hold stone, wood, moss and cloth:
//   low saturation  -> stone (triplanar rock texture, tinted)
//   brown hue       -> wood  (triplanar bark texture, tinted)
//   green dominant  -> moss  (moss texture)
//   anything else   -> painted / cloth / bone (colour + fine weave noise)
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_scale = 0.3;
uniform float wood_scale = 0.8;

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

vec3 tri_tex(sampler2D t, vec3 q, vec3 bw) {
	return texture(t, q.zy).rgb * bw.x + texture(t, q.xz).rgb * bw.y + texture(t, q.xy).rgb * bw.z;
}

vec3 tri_nrm(sampler2D t, vec3 q, vec3 bw, vec3 N) {
	vec2 tx = texture(t, q.zy).xy * 2.0 - 1.0;
	vec2 ty = texture(t, q.xz).xy * 2.0 - 1.0;
	vec2 tz = texture(t, q.xy).xy * 2.0 - 1.0;
	return normalize(vec3(N.x, tx.y + N.y, tx.x + N.z) * bw.x + vec3(ty.x + N.x, N.y, ty.y + N.z) * bw.y + vec3(tz.x + N.x, tz.y + N.y, N.z) * bw.z);
}

void fragment() {
	vec3 N = normalize(wnrm);
	if (!FRONT_FACING) {
		N = -N;
	}
	vec3 s = clamp(COLOR.rgb, vec3(0.0), vec3(1.5));
	vec3 lin = s * s * (0.3 * s + 0.7);
	float mx = max(s.r, max(s.g, s.b));
	float mn = min(s.r, min(s.g, s.b));
	float sat = (mx - mn) / max(mx, 0.001);
	vec3 bw = pow(abs(N), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 col = lin;
	vec3 n = N;
	float rough = 0.85;
	bool green = s.g > s.r * 1.08 && s.g > s.b * 1.2 && sat > 0.2;
	bool brown = s.r > s.g && s.g > s.b && sat > 0.22 && mx < 0.75;
	if (green) {
		vec3 m = texture(moss_tex, wpos.xz * 0.6 + wpos.y * 0.2).rgb;
		col = m * 0.75;
		rough = 0.95;
	} else if (brown) {
		vec3 q = wpos * wood_scale;
		vec3 w = tri_tex(wood_tex, q, bw);
		// texture as detail around the authored colour (bark_oak mean lum ~0.18)
		vec3 wl = mix(w, vec3(dot(w, vec3(0.3, 0.59, 0.11))), 0.45) * vec3(0.95, 0.88, 0.8);
		float vlum = dot(lin, vec3(0.3, 0.59, 0.11));
		col = wl * clamp(vlum / 0.1, 0.35, 1.6) * 0.75;
		// moss patches on the upper side of logs / beams
		float wm = smoothstep(0.55, 0.95, N.y) * smoothstep(0.45, 0.75, texture(moss_tex, wpos.xz * 0.15).g);
		col = mix(col, texture(moss_tex, wpos.xz * 0.6).rgb * vec3(0.6, 0.64, 0.5), wm * 0.8);
		n = tri_nrm(wood_nrm, q, bw, N);
		rough = 0.88;
	} else if (sat < 0.2 && mx < 0.8) {
		vec3 q = wpos * rock_scale;
		vec3 r = tri_tex(rock_tex, q, bw);
		// texture as detail around the authored colour (rock_mossy mean lum ~0.15)
		r = mix(r, vec3(dot(r, vec3(0.3, 0.59, 0.11))), 0.6);
		col = lin * clamp(r / 0.11, vec3(0.0), vec3(3.0));
		n = tri_nrm(rock_nrm, q, bw, N);
		rough = 0.88;
		// a little moss on top surfaces of stone
		float mn = texture(moss_tex, wpos.xz * 0.07 + wpos.y * 0.05).g;
		float mm = smoothstep(0.5, 0.92, N.y + (mn - 0.35) * 1.2) * 0.75;
		vec3 mc = texture(moss_tex, wpos.xz * 0.6).rgb;
		mc = mix(mc, vec3(dot(mc, vec3(0.3, 0.59, 0.11))), 0.35) * vec3(0.62, 0.66, 0.5);
		col = mix(col, mc, mm);
	} else {
		// cloth / bone / painted: fine weave + gentle variation
		float weave = hash(floor(wpos.xz * 40.0) + floor(wpos.y * 40.0)) * 0.08;
		col = lin * (0.94 + weave);
		rough = 0.9;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
