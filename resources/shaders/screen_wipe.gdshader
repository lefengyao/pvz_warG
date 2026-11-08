shader_type canvas_item;

// 全屏转场遮罩。
// progress = 0 全透明（看得见游戏），progress = 1 全遮住（fade_color 不透明）。
// 渐变方向是从左上到右下，软边由 softness 控制。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness : hint_range(0.01, 0.5) = 0.18;

void fragment() {
	// 对角线渐变：左上 0 → 右下 1
	float g = clamp((UV.x + UV.y) * 0.5, 0.0, 1.0);

	// 把 progress 映射到 [-softness, 1+softness]，保证两端完全透明 / 完全不透明
	float p = progress * (1.0 + softness * 2.0) - softness;

	// 软边过渡
	float a = clamp((p - g) / softness, 0.0, 1.0);

	COLOR = vec4(fade_color.rgb, fade_color.a * a);
}
