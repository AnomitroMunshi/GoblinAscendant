// Shared stylized water. Define USE_DEPTH before including to enable
// depth-based tint/foam (Forward+/desktop). Without it, foam and tint come
// from UV2.x (0 = channel centre, 1 = bank) so no depth/screen reads happen.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.22, 0.36, 0.30);
uniform vec3 deep_color : source_color = vec3(0.03, 0.10, 0.12);
uniform vec3 foam_color : source_color = vec3(0.82, 0.86, 0.84);
uniform float flow_speed = 0.6;
uniform float still = 0.0;   // 1 = pond / pool (no directional flow)
uniform float depth_scale = 1.8;  // depth (m) at which the deep colour is reached
uniform float min_alpha = 0.45;
uniform float roughness = 0.06;
uniform float scum = 0.0;   // marsh: patches of floating algae / duckweed
uniform vec3 scum_color : source_color = vec3(0.24, 0.30, 0.12);
#ifdef USE_DEPTH
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
#endif

varying vec3 wpos;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// flowing height field used for normals and streaks
float wave(vec2 p, float t) {
	return vnoise(p * vec2(0.35, 0.9) + vec2(-t * 1.0, 0.0)) * 0.6 + vnoise(p * vec2(0.9, 1.6) + vec2(-t * 1.7, 3.0)) * 0.4;
}

void fragment() {
	float t = TIME * flow_speed;
	// flow space: x along the river (UV.x metres), y across (UV.y metres)
	vec2 fp = mix(UV, wpos.xz * 0.6, still);
	float tt = mix(t, t * 0.15, still);
	float w0 = wave(fp, tt);
	float e = 0.15;
	float wx = wave(fp + vec2(e, 0.0), tt) - w0;
	float wy = wave(fp + vec2(0.0, e), tt) - w0;
	float ripple = mix(3.0, 0.9, still);
	vec3 nrm_w = normalize(vec3(-wx * ripple, 1.0, -wy * ripple));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm_w, 0.0)).xyz);

	float bank = clamp(UV2.x, 0.0, 1.0);
	float depth = mix(2.0, 0.0, smoothstep(0.35, 1.0, bank));
#ifdef USE_DEPTH
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vec4 vpos = INV_PROJECTION_MATRIX * ndc;
	vpos.xyz /= vpos.w;
	vec3 scene_w = (INV_VIEW_MATRIX * vec4(vpos.xyz, 1.0)).xyz;
	depth = clamp(wpos.y - scene_w.y, 0.0, 6.0);
#endif
	float dt = smoothstep(0.0, depth_scale, depth);
	vec3 col = mix(shallow_color, deep_color, dt);
	// flow streaks
	float streak = smoothstep(0.62, 0.9, vnoise(fp * vec2(0.18, 1.4) + vec2(-t * 1.3, 0.0)));
	col = mix(col, foam_color, streak * 0.18 * (1.0 - still));
	// foam lines along the banks / around rocks
	float fn = vnoise(fp * 1.6 + vec2(-t * 1.5, 0.0));
	float foam = smoothstep(0.42, 0.05, depth + (fn - 0.5) * 0.35);
	foam *= 1.0 - still * 0.85;  // ponds and lakes: no bright rim
	col = mix(col, foam_color, foam * 0.55);
	// sparkles: tiny bright glints, stronger at grazing angles
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float sp = vnoise(fp * 6.0 + vec2(-t * 2.2, t * 0.7)) * vnoise(fp * 7.3 - vec2(t * 1.1, 0.0));
	float sparkle = smoothstep(0.70, 0.80, sp) * 0.6;
	float sc = 0.0;
	if (scum > 0.0) {
		float sn = vnoise(wpos.xz * 0.35) * 0.65 + vnoise(wpos.xz * 1.7) * 0.35;
		sc = smoothstep(0.62 - scum * 0.3, 0.72 - scum * 0.3, sn) * smoothstep(0.0, 0.25, depth + 0.1);
		col = mix(col, scum_color * (0.8 + 0.4 * vnoise(wpos.xz * 6.0)), sc);
		sparkle *= 1.0 - sc;
	}
	// fresnel: darker looking straight down, sky reflection at grazing angles
	col *= mix(0.65, 1.0, fres);
	ALBEDO = col;
	EMISSION = foam_color * sparkle * 0.6;
	ROUGHNESS = mix(roughness, 0.95, sc);
	METALLIC = 0.0;
	SPECULAR = mix(mix(0.55, 0.35, still), 0.05, sc);
	ALPHA = clamp(mix(min_alpha, 0.95, dt) + foam * 0.2 + fres * 0.25 + sc, 0.0, 1.0);
}
