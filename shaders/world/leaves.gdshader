shader_type spatial;
// Alpha-cut leaf / needle / fern cards (procedural atlas, WorldTextures).
// Mesh normals point out of the canopy volume so cards shade as a mass.
// COLOR.rgb tints (1 = atlas colour), COLOR.a = sway weight.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float sway_strength = 1.0;
uniform float wind_speed = 1.1;
uniform float translucency = 0.45;
uniform vec2 lod_band = vec2(0.0, 100000.0);  // draw instances whose distance to view_pos is in [x, y)
uniform vec3 view_pos = vec3(0.0);             // gameplay camera (set by WorldRoot each frame; shadow-pass safe)

varying float v_sway;

void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	float w = COLOR.a;
	v_sway = w;
	float t = TIME * wind_speed + ip.x * 0.045 + ip.z * 0.06;
	float gust = 0.65 + 0.35 * sin(TIME * 0.31 + ip.x * 0.01);
	vec3 off = vec3(sin(t), 0.0, cos(t * 0.83 + 1.3)) * 0.12 * gust;
	off += vec3(sin(t * 3.7 + VERTEX.y * 1.3), sin(t * 4.1 + VERTEX.x) * 0.5, cos(t * 3.3 + VERTEX.z * 1.1)) * 0.05;
	VERTEX += off * w * sway_strength;
	float lod_d = length(MODEL_MATRIX[3].xyz - view_pos);
	if (lod_d < lod_band.x || lod_d >= lod_band.y) {
		VERTEX = vec3(0.0);  // collapse: this instance is drawn by another LOD
	}
}

void fragment() {
	vec4 a = texture(atlas, UV);
	// geometry without atlas UVs (reeds, stems, lily pads) is drawn solid in its vertex colour
	bool solid = UV.x + UV.y < 0.0001;
	if (solid) {
		vec3 s = clamp(COLOR.rgb, vec3(0.0), vec3(1.5));
		a = vec4(s * s * (0.3 * s + 0.7), 1.0);
	}
	// keep coverage in the distance (mip levels thin out alpha)
	vec2 dx = dFdx(UV * 512.0);
	vec2 dy = dFdy(UV * 512.0);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float alpha = a.a * (1.0 + lod * 0.35);
	vec3 tint = solid ? vec3(1.0) : clamp(COLOR.rgb, vec3(0.0), vec3(2.0));
	vec3 c = a.rgb * tint;
	ALBEDO = c;
	ALPHA = alpha * smoothstep(0.9, 2.0, length(VERTEX));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = c * translucency;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;  // keep the canopy-volume normal on both sides
	}
}
