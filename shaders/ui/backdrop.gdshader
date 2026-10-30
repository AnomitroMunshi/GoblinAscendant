shader_type canvas_item;
// Soft dark gradient behind menus / title (UI agent).
// strength 0..1; mode 0 = uniform dim with soft edges, 1 = title (dark bottom/left, open top-right).
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform int mode = 0;

void fragment() {
	vec2 uv = UV;
	float a;
	if (mode == 1) {
		float bottom = smoothstep(0.25, 1.0, uv.y);
		float left = smoothstep(0.75, 0.0, uv.x) * 0.55;
		float vig = smoothstep(0.35, 0.95, length((uv - vec2(0.5)) * vec2(1.2, 1.0)) * 1.2);
		a = clamp(0.18 + bottom * 0.55 + left * 0.45 + vig * 0.35, 0.0, 0.92);
	} else {
		float vig = smoothstep(0.2, 0.9, length(uv - vec2(0.5)) * 1.4);
		a = 0.5 + vig * 0.3;
	}
	COLOR = vec4(0.03, 0.02, 0.015, a * strength);
}
