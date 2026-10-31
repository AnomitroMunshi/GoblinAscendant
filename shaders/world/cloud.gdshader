shader_type spatial;
// Distant cumulus: camera-facing quad. Density = several overlapping noise
// puffs with an irregular, wispy edge and a flat-ish base; shading = sun-lit
// cauliflower tops and grey-blue bellies. Unshaded, fog-free (sky layer).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

instance uniform float seed = 0.0;
uniform vec3 top_color : source_color = vec3(1.0, 0.97, 0.93);
uniform vec3 belly_color : source_color = vec3(0.58, 0.63, 0.72);
uniform float opacity = 0.92;

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
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(11.3, 7.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv * 2.0 - 1.0;
	// 4 puffs of different size along the bank
	float puffs = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		vec2 pc = vec2(-0.6 + fi * 0.4 + (hash(vec2(seed, fi)) - 0.5) * 0.3, 0.1 - hash(vec2(fi, seed)) * 0.35);
		float pr = 0.32 + hash(vec2(seed + fi, 3.1)) * 0.3;
		puffs = max(puffs, 1.0 - length((c - pc) * vec2(1.0, 1.6)) / pr);
	}
	float n = fbm(uv * vec2(6.0, 3.0) + seed);
	float n2 = fbm(uv * vec2(14.0, 7.0) + seed * 1.7);
	float den = puffs + (n - 0.5) * 0.9 + (n2 - 0.5) * 0.35;
	den *= smoothstep(0.98, 0.7, uv.y);   // flatter base
	den *= smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x) * smoothstep(0.0, 0.25, uv.y);
	float a = smoothstep(0.05, 0.4, den);
	// shading: brighter towards the top, cauliflower detail from n2
	float lit = clamp(0.25 + (0.6 - uv.y) * 1.1 + (n2 - 0.5) * 0.9, 0.0, 1.0);
	vec3 col = mix(belly_color, top_color, lit);
	ALBEDO = col;
	ALPHA = a * opacity;
}
