shader_type spatial;
// Stylized terrain: vertex COLOR = (dirt, sand, meadow, forest) weights.
// All texture detail is procedural value noise in world space (no assets).
// Mobile-safe: no screen/depth reads.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 grass_a : source_color = vec3(0.33, 0.56, 0.20);
uniform vec3 grass_b : source_color = vec3(0.50, 0.70, 0.26);
uniform vec3 meadow : source_color = vec3(0.70, 0.74, 0.32);
uniform vec3 forest_floor : source_color = vec3(0.20, 0.33, 0.13);
uniform vec3 forest_moss : source_color = vec3(0.30, 0.42, 0.15);
uniform vec3 dirt : source_color = vec3(0.56, 0.42, 0.27);
uniform vec3 dirt_dark : source_color = vec3(0.42, 0.30, 0.19);
uniform vec3 sand : source_color = vec3(0.80, 0.72, 0.52);
uniform vec3 pebble : source_color = vec3(0.58, 0.56, 0.50);
uniform vec3 rock : source_color = vec3(0.56, 0.54, 0.50);
uniform vec3 rock_dark : source_color = vec3(0.36, 0.36, 0.37);
uniform vec3 rock_warm : source_color = vec3(0.60, 0.52, 0.42);

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
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v / 0.875;
}

void fragment() {
	vec2 p = wpos.xz;
	float n_large = fbm(p * 0.012);
	float n_mid = vnoise(p * 0.11);
	float n_small = vnoise(p * 0.8);
	float n_tiny = vnoise(p * 3.1);

	// Grass: large soft patches of two greens + warm meadow patches.
	vec3 g = mix(grass_a, grass_b, smoothstep(0.30, 0.72, n_large));
	float warm = smoothstep(0.58, 0.82, fbm(p * 0.026 + 31.0)) * 0.55 + COLOR.b * 0.55;
	g = mix(g, meadow, clamp(warm, 0.0, 0.85));
	g *= 0.92 + 0.14 * n_small + 0.05 * (n_tiny - 0.5);
	// Forest floor: darker, mossy.
	vec3 ff = mix(forest_floor, forest_moss, n_mid);
	g = mix(g, ff, smoothstep(0.15, 0.95, COLOR.a) * 0.85);

	// Dirt paths / trampled ground with ragged noisy edges.
	float dn = (vnoise(p * 0.45) - 0.5) * 0.35 + (n_tiny - 0.5) * 0.12;
	float dirt_w = smoothstep(0.38, 0.55, COLOR.r + dn);
	vec3 dcol = mix(dirt_dark, dirt, smoothstep(0.2, 0.8, n_small));
	dcol = mix(dcol, pebble, smoothstep(0.82, 0.9, n_tiny) * 0.5);
	vec3 col = mix(g, dcol, dirt_w);

	// Sandy / pebbly river banks.
	float sand_w = smoothstep(0.30, 0.55, COLOR.g + dn * 0.6);
	vec3 scol = mix(sand, pebble, smoothstep(0.55, 0.75, n_small) * 0.7);
	col = mix(col, scol, sand_w);

	// Rock on steep slopes, horizontal strata, moss on gentler ledges.
	vec3 n = normalize(wnrm);
	float slope = 1.0 - n.y;
	float alt_rock = smoothstep(45.0, 110.0, wpos.y);
	float rock_w = smoothstep(0.26 - alt_rock * 0.12, 0.40 - alt_rock * 0.14, slope + (n_mid - 0.5) * 0.12);
	float strata = vnoise(vec2(p.x * 0.05 + p.y * 0.05, wpos.y * 0.35 + n_mid * 1.5));
	vec3 rcol = mix(rock_dark, rock, smoothstep(0.15, 0.85, strata));
	rcol = mix(rcol, rock_warm, smoothstep(0.55, 0.8, n_large) * 0.5);
	rcol *= 0.9 + 0.15 * n_tiny;
	col = mix(col, rcol, rock_w);

	// High mountain tops: paler rock, a hint of snow on the very highest ridges.
	// grass on mountain slopes leans to darker conifer-green
	col = mix(col, col * vec3(0.78, 0.88, 0.85), smoothstep(15.0, 60.0, wpos.y) * (1.0 - rock_w));
	float alt = smoothstep(60.0, 140.0, wpos.y);
	col = mix(col, mix(col, vec3(0.70, 0.71, 0.74), 0.4), alt);
	col = mix(col, vec3(0.92, 0.94, 0.98), smoothstep(150.0, 185.0, wpos.y + n_mid * 12.0) * smoothstep(0.55, 0.85, n.y));

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, sand_w * 0.5);
	SPECULAR = 0.25;
}
