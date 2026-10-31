shader_type spatial;
// Realistic terrain blend. Vertex COLOR = (dirt, shore, meadow, forest) weights,
// UV2.x = mud weight. CC0 PBR textures (ambientCG, see docs/ASSETS_WORLD.md) are
// sampled in world space with anti-tiling (two rotated scales mixed by noise),
// rock is triplanar on steep slopes, with macro colour variation on top.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebble_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebble_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float grass_scale = 0.28;
uniform float forest_scale = 0.22;
uniform float dirt_scale = 0.33;
uniform float mud_scale = 0.25;
uniform float rock_scale = 0.06;
uniform float pebble_scale = 0.45;
uniform vec3 grass_tint : source_color = vec3(0.80, 0.94, 0.70);
uniform vec3 meadow_tint : source_color = vec3(1.05, 1.0, 0.78);
uniform float normal_strength = 0.9;

varying vec3 wpos;
varying vec3 wnrm;
varying float v_mud;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_mud = UV2.x;
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v / 0.9375;
}

const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

// anti-tiled albedo + tangent normal (xy), sampled on the ground plane
void ground(sampler2D t, sampler2D nm, vec2 uv, float k, out vec3 col, out vec2 tn) {
	vec2 uv2 = ROT * uv * 0.41 + vec2(0.37, 0.71);
	col = mix(texture(t, uv).rgb, texture(t, uv2).rgb, k);
	vec2 n1 = texture(nm, uv).xy * 2.0 - 1.0;
	vec2 n2 = texture(nm, uv2).xy * 2.0 - 1.0;
	tn = mix(n1, n2, k);
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 N = normalize(wnrm);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float k = smoothstep(0.3, 0.7, vnoise(p * 0.05));           // anti-tiling mix
	float macro = fbm(p * 0.012);
	float macro2 = vnoise(p * 0.11);

	vec3 c_grass; vec2 n_grass;
	ground(grass_tex, grass_nrm, p * grass_scale, k, c_grass, n_grass);
	// far away: lower-frequency sample to kill visible repetition
	vec3 c_grass_far = texture(grass_tex, p * grass_scale * 0.13).rgb;
	c_grass = mix(c_grass, c_grass_far, smoothstep(40.0, 160.0, dist) * 0.6);
	c_grass *= grass_tint;
	float warm = clamp(COLOR.b * 0.6 + smoothstep(0.6, 0.85, fbm(p * 0.02 + 31.0)) * 0.45, 0.0, 1.0);
	c_grass *= mix(vec3(1.0), meadow_tint, warm);
	c_grass *= mix(vec3(0.82, 0.88, 0.80), vec3(1.08, 1.04, 0.92), macro);  // macro hue/brightness drift

	vec3 col = c_grass;
	vec2 tn = n_grass;
	float rough = 0.95;

	// forest floor (leaf litter) under trees
	vec3 c_for; vec2 n_for;
	ground(forest_tex, forest_nrm, p * forest_scale, k, c_for, n_for);
	float fw = smoothstep(0.3, 0.75, COLOR.a + (macro2 - 0.5) * 0.35);
	c_for = mix(c_for, vec3(dot(c_for, vec3(0.3, 0.59, 0.11))), 0.45) * vec3(0.8, 0.78, 0.7);
	col = mix(col, c_for, fw);
	tn = mix(tn, n_for, fw);

	// dirt paths / trampled ground, height-blended edges
	vec3 c_dirt; vec2 n_dirt;
	ground(dirt_tex, dirt_nrm, p * dirt_scale, k, c_dirt, n_dirt);
	float dl = dot(c_dirt, vec3(0.333));
	float dw = smoothstep(0.42, 0.58, COLOR.r + (vnoise(p * 0.5) - 0.5) * 0.3 + (dl - 0.35) * 0.4);
	vec3 c_earth = texture(mud_tex, p * 0.3 + 0.5).rgb * vec3(0.8, 0.72, 0.6);
	col = mix(col, mix(c_dirt * vec3(0.7, 0.6, 0.48), c_earth, 0.45), dw);
	tn = mix(tn, n_dirt, dw);
	rough = mix(rough, 0.9, dw);

	// shore pebbles / sand
	vec3 c_peb; vec2 n_peb;
	ground(pebble_tex, pebble_nrm, p * pebble_scale, k, c_peb, n_peb);
	float sw = smoothstep(0.3, 0.55, COLOR.g + (vnoise(p * 0.7) - 0.5) * 0.3);
	col = mix(col, c_peb, sw);
	tn = mix(tn, n_peb, sw);

	// mud (marsh, wet ground); darker and glossier
	vec3 c_mud; vec2 n_mud;
	ground(mud_tex, mud_nrm, p * mud_scale, k, c_mud, n_mud);
	float mw = smoothstep(0.25, 0.6, v_mud + (vnoise(p * 0.4) - 0.5) * 0.3);
	col = mix(col, c_mud * vec3(0.42, 0.40, 0.32), mw);
	tn = mix(tn, n_mud, mw);
	rough = mix(rough, 0.4, mw);

	// wet band right at the waterline (shore / sand)
	float wet = sw * smoothstep(0.6, 1.0, COLOR.g);
	col *= 1.0 - 0.45 * wet;
	rough = mix(rough, 0.35, wet);

	// ground normal (UDN on the Y plane)
	vec3 n_ground = normalize(vec3(tn.x * normal_strength + N.x, N.y, -tn.y * normal_strength + N.z));

	// triplanar rock on steep slopes and high ground
	float slope = 1.0 - N.y;
	float alt = smoothstep(50.0, 130.0, wpos.y);
	float rw = smoothstep(0.26 - alt * 0.2, 0.40 - alt * 0.22, slope + (macro2 - 0.5) * 0.12);
	rw = max(rw, smoothstep(110.0, 170.0, wpos.y + (macro - 0.5) * 40.0) * 0.85);
	if (rw > 0.001) {
		vec3 bw = pow(abs(N), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 q = wpos * rock_scale;
		vec3 rx = texture(rock_tex, q.zy).rgb;
		vec3 ry = texture(rock_tex, q.xz).rgb;
		vec3 rz = texture(rock_tex, q.xy).rgb;
		vec3 rc = rx * bw.x + ry * bw.y + rz * bw.z;
		rc *= mix(vec3(0.86, 0.84, 0.80), vec3(1.05, 1.0, 0.94), macro) * 2.1;
		vec2 tx = texture(rock_nrm, q.zy).xy * 2.0 - 1.0;
		vec2 ty = texture(rock_nrm, q.xz).xy * 2.0 - 1.0;
		vec2 tz = texture(rock_nrm, q.xy).xy * 2.0 - 1.0;
		vec3 wx = vec3(N.x, tx.y + N.y, tx.x + N.z);
		vec3 wy = vec3(ty.x + N.x, N.y, ty.y + N.z);
		vec3 wz = vec3(tz.x + N.x, tz.y + N.y, N.z);
		vec3 n_rock = normalize(wx * bw.x + wy * bw.y + wz * bw.z);
		col = mix(col, rc, rw);
		n_ground = normalize(mix(n_ground, n_rock, rw));
		rough = mix(rough, 0.85, rw);
	}

	// high peaks: pale rock and a little snow on flat-ish ridges
	col = mix(col, col * vec3(1.1, 1.1, 1.14), alt * 0.5);
	float sline = 200.0 + (macro - 0.5) * 70.0 + (vnoise(p * 0.06) - 0.5) * 25.0;
	float snow = smoothstep(sline, sline + 14.0, wpos.y) * smoothstep(0.5, 0.85, N.y);
	col = mix(col, vec3(0.88, 0.9, 0.94), snow);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_ground, 0.0)).xyz);
}
