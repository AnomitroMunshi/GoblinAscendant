// Billboarded world-space enemy health bar (Combat agent).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float ratio : hint_range(0.0, 1.0) = 1.0;
uniform float lag : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.92, 0.27, 0.2, 1.0);
uniform vec4 fill_color_top : source_color = vec4(1.0, 0.5, 0.38, 1.0);
uniform vec4 lag_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform vec4 back_color : source_color = vec4(0.07, 0.05, 0.05, 0.8);
uniform vec2 size = vec2(1.0, 0.11);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float border = 0.018;
	vec2 px = UV * size;
	bool edge = px.x < border || px.x > size.x - border || px.y < border || px.y > size.y - border;
	float u = (px.x - border) / max(size.x - 2.0 * border, 0.001);
	vec4 c = back_color;
	if (u < lag) {
		c = lag_color;
	}
	if (u < ratio) {
		c = mix(fill_color_top, fill_color, smoothstep(0.2, 0.9, UV.y));
	}
	if (edge) {
		c = vec4(0.02, 0.02, 0.02, 0.9);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a * alpha;
}
