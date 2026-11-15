shader_type canvas_item;

// 圆形收放转场。
//
// 遮罩是「圆外面不透明、圆里面透明」，透出来的部分就是旧/新画面：
//   1. 收拢：hole 1 → 0，看得见的圆越来越小，画面像被吸进一个点
//   2. 散开：hole 0 → 1，圆从那个点长大，把新场景放出来
//
// 边缘用 fwidth 做屏幕空间抗锯齿：
//   过渡宽度锁死在 edge_width 像素左右，不随圆的大小变化，
//   也不会出现「宽渐变 + 8 位色阶」导致的同心圆带纹。

uniform float hole : hint_range(0.0, 1.0) = 1.0;

// 圆心（UV），由脚本按点击位置换算
uniform vec2 focus_uv = vec2(0.5, 0.5);

// 屏幕宽高比与最大半径（由脚本按视口大小写入）
uniform float screen_ratio = 1.7777;
uniform float max_radius = 2.0;

// 抗锯齿宽度（像素）。2.0 左右即可，太大会糊，太小学会出锯齿
uniform float edge_width : hint_range(0.5, 6.0) = 2.0;

// 遮罩本身（圆外面）的颜色
uniform vec4 mask_color : source_color = vec4(0.06, 0.05, 0.04, 1.0);

void fragment() {
	vec2 p = (UV - focus_uv) * vec2(screen_ratio, 1.0);
	float d = length(p) / max_radius;

	// 给两端留一点余量，保证 hole=0 全遮住、hole=1 全透明
	float margin = 0.02;
	float r = mix(-margin, 1.0 + margin, clamp(hole, 0.0, 1.0));

	// fwidth 是 d 在屏幕上的变化率，乘上想要的分辨率就是恒定的抗锯齿宽度
	float aa = max(fwidth(d) * edge_width, 0.0002);

	// 圆内 = 1
	float inside = 1.0 - smoothstep(r - aa, r + aa, d);

	// 圆内透明（露出画面），圆外不透明（遮住）
	float a = 1.0 - inside;
	COLOR = vec4(mask_color.rgb, mask_color.a * a);
}
