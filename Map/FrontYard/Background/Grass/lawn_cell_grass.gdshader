shader_type spatial;

render_mode cull_disabled, diffuse_burley;

uniform vec4 grass_color : source_color = vec4(0.30, 0.56, 0.20, 1.0);
uniform vec4 grass_highlight_color : source_color = vec4(0.71, 0.93, 0.45, 1.0);
uniform vec2 cell_size = vec2(2.0);
uniform float grass_cell_overflow = 0.20;
uniform float grass_light_wrap = 0.22;
uniform float grass_highlight_strength = 0.38;
uniform float grass_highlight_threshold = 0.62;
uniform float grass_highlight_hardness = 5.0;
uniform float grass_emission_strength = 0.06;
// 将不规则草叶法线向上混合，改善 Fine/Broad 模型的直射光响应。
uniform float grass_normal_up_strength = 0.72;
uniform vec4 grass_root_color : source_color = vec4(0.14, 0.30, 0.07, 1.0);
uniform vec4 grass_tip_color : source_color = vec4(0.47, 0.74, 0.29, 1.0);
uniform float grass_gradient_strength = 0.75;
uniform float grass_gradient_exponent = 1.15;
uniform float grass_variant_height = 1.0;
// 风摆最大位移；设为 0 可关闭动画。
uniform float grass_wind_strength = 0.035;
// 是否使用 TIME 驱动动态摆动；关闭时保留静态姿态。
uniform bool grass_wind_animated = true;
// 风摆动画速度。
uniform float grass_wind_speed = 1.1;
// 相邻草簇的空间相位差。
uniform float grass_wind_frequency = 1.4;
// XZ 平面内的风向，材质由 LawnGrassSettings 同步。
uniform vec2 grass_wind_direction = vec2(1.0, 0.25);

varying vec2 grass_cell_position;
varying float grass_height01;
varying float grass_highlight;
varying vec3 grass_vertex_tint;

void vertex() {
	float yaw = INSTANCE_CUSTOM.b;
	float grass_height_value = clamp(VERTEX.y / max(grass_variant_height, 0.001), 0.0, 1.0);
	float wind_mask = smoothstep(0.05, 1.0, grass_height_value);
	vec2 wind_direction = grass_wind_direction;
	float wind_time = 0.0;
	if (grass_wind_animated) {
		wind_time = TIME * grass_wind_speed;
	}
	float phase = wind_time
		+ dot(INSTANCE_CUSTOM.rg, wind_direction) * grass_wind_frequency
		+ yaw * 0.7;
	float wave = sin(phase + grass_height_value * 2.1) * 0.65
		+ sin(phase * 0.73 + grass_height_value * 3.7 + 1.2) * 0.35;
	float width_scale = max(INSTANCE_CUSTOM.a, 0.001);
	vec2 local_wind_direction = vec2(
		cos(yaw) * wind_direction.x + sin(yaw) * wind_direction.y,
		-sin(yaw) * wind_direction.x + cos(yaw) * wind_direction.y
	);
	vec2 wind_offset = local_wind_direction * wave * grass_wind_strength * wind_mask / width_scale;
	VERTEX.xz += wind_offset;

	float normal_mix = grass_normal_up_strength;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), normal_mix));
	// 让摆动后的叶片产生轻微倾斜，保留原有朝上法线控制。
	vec3 wind_normal = normalize(vec3(-local_wind_direction.x * wave * 0.22, 1.0, -local_wind_direction.y * wave * 0.22));
	NORMAL = normalize(mix(NORMAL, wind_normal, wind_mask * 0.28));

	// 合批后同一 MultiMesh 包含多个格子，用实例变换后的世界坐标进行逐实例裁剪。
	vec3 world_vertex_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grass_cell_position = world_vertex_position.xz - INSTANCE_CUSTOM.rg;
	grass_height01 = pow(grass_height_value, grass_gradient_exponent);
	float tip = smoothstep(grass_highlight_threshold, 1.0, grass_height_value);
	grass_highlight = floor(pow(tip, grass_highlight_hardness) * 4.0 + 0.5) / 4.0;
	grass_vertex_tint = COLOR.rgb;
}

void fragment() {
	vec2 clip_half_size = cell_size * (0.5 + grass_cell_overflow);
	vec2 cell_position = abs(grass_cell_position);
	if (cell_position.x > clip_half_size.x || cell_position.y > clip_half_size.y) {
		discard;
	}

	vec3 vertex_tint = mix(vec3(0.78), vec3(1.12), clamp(grass_vertex_tint * 1.35, 0.0, 1.0));
	if (dot(grass_vertex_tint, vec3(1.0)) < 0.001) {
		vertex_tint = vec3(1.0);
	}
	vec3 base_color = grass_color.rgb * vertex_tint;
	vec3 gradient_color = mix(grass_root_color.rgb, grass_tip_color.rgb, grass_height01);
	base_color = mix(base_color, gradient_color, grass_gradient_strength);
	ALBEDO = mix(base_color, grass_highlight_color.rgb, clamp(grass_highlight * grass_highlight_strength, 0.0, 1.0));
	EMISSION = grass_highlight_color.rgb * grass_highlight * grass_emission_strength;
	ROUGHNESS = 0.9;
}

void light() {
	float direct = abs(dot(normalize(NORMAL), normalize(LIGHT)));
	float wrapped = clamp((direct + grass_light_wrap) / (1.0 + grass_light_wrap), 0.0, 1.0);
	float light_band = floor(pow(wrapped, 1.1) * 4.0 + 0.5) / 4.0;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * light_band * ATTENUATION;
	SPECULAR_LIGHT = vec3(0.0);
}
