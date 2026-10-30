shader_type canvas_item;
// Screen-edge vignette for damage / low health (UI agent).
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.03, 0.02, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.25;
	float d = length(uv) * 1.6;
	float v = smoothstep(0.42, 1.05, d);
	COLOR = vec4(tint.rgb, clamp(v * intensity * 1.15, 0.0, 0.9));
}
