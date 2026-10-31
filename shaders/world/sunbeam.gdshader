shader_type spatial;
// Soft additive god-ray card. UV.y: 0 at the sky end, 1 at the ground.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 beam_color : source_color = vec3(1.0, 0.92, 0.70);
uniform float strength = 0.08;

void fragment() {
	float across = max(sin(clamp(UV.x, 0.0, 1.0) * PI), 0.0);
	across = pow(across, 2.5);
	float along = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float shimmer = 0.85 + 0.15 * sin(TIME * 0.7 + UV.x * 6.0);
	// fade when seen edge-on and when very close to the camera
	float facing = abs(dot(NORMAL, VIEW));
	float near_fade = smoothstep(2.0, 8.0, -VERTEX.z);
	ALBEDO = beam_color * across * along * shimmer * strength * facing * near_fade;
}
