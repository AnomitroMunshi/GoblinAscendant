shader_type sky;
// Stylized afternoon sky: soft vertical gradient, warm horizon glow toward
// the sun, sun disc + halo and soft painted clouds (skipped in the radiance
// cubemap pass so ambient light stays smooth). No TIME: the radiance map
// does not need per-frame updates.

uniform vec3 top_color : source_color = vec3(0.30, 0.52, 0.86);
uniform vec3 mid_color : source_color = vec3(0.55, 0.74, 0.94);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.90, 0.92);
uniform vec3 warm_color : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 ground_color : source_color = vec3(0.46, 0.55, 0.60);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.70, 0.76, 0.86);
uniform float cloud_cover = 0.45;
uniform bool clouds_enabled = true;

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun_dot = max(dot(d, sun_dir), 0.0);

	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.25, h));
	col = mix(col, top_color, smoothstep(0.22, 0.85, h));
	// warm glow around the sun near the horizon
	float az = pow(sun_dot, 3.0);
	col = mix(col, warm_color, az * (1.0 - smoothstep(0.0, 0.5, h)) * 0.55);
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.3, h));
	}

	// clouds
	if (clouds_enabled && !AT_CUBEMAP_PASS && h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.6;
		float n = fbm(uv * 0.9 + vec2(4.0, 1.0));
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n);
		float shade = fbm(uv * 0.9 + vec2(4.0, 1.0) + sun_dir.xz * 0.15);
		vec3 cc = mix(cloud_color, cloud_shade, smoothstep(0.35, 0.8, shade) * 0.8);
		cc = mix(cc, warm_color, az * 0.4);
		c *= smoothstep(0.0, 0.12, h);
		col = mix(col, cc, c * 0.9);
	}

	// sun disc + halo
	if (LIGHT0_ENABLED) {
		float disc = smoothstep(0.9994, 0.99975, sun_dot);
		col += LIGHT0_COLOR * (disc * 6.0 + pow(sun_dot, 64.0) * 0.6 + pow(sun_dot, 8.0) * 0.12);
	}
	COLOR = col;
}
