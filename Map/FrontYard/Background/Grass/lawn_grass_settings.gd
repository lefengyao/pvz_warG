@tool
extends Resource
class_name LawnGrassSettings

@export_group("模型草生成")
## 草模型场景；LawnGrid 会从其中收集 MeshInstance3D 网格。
@export var model_scene: PackedScene = preload("res://Assets/Textures/Grass/stylized_lawn_demo.glb")
## 为空时收集 GLB 中的全部 MeshInstance3D；填写文本可按节点名筛选。
@export var model_mesh_name_filter: String = ""
## 按收集顺序给每个模型分配比例；缺少的项默认按 1.0 参与计算。
@export var model_variant_weights: PackedFloat32Array = PackedFloat32Array([0.50, 0.30, 0.20])
## 每个格子的基础草簇数量；实际数量还会受到密度噪声影响。
@export_range(1, 200, 1) var model_clumps_per_cell: int = 25
## 模型草簇的基础世界缩放。
@export_range(0.1, 1.5, 0.01) var model_grass_scale: float = 0.68
## 模型草是否投射阴影；关闭后可降低草地的阴影渲染开销。
@export var grass_cast_shadow: bool = true
## 样式 0 使用的深色草基础颜色。
@export var dark_color: Color = Color("#182e0a")
## 样式 1 使用的浅色草基础颜色。
@export var light_color: Color = Color("#3c8826")
## 草簇中心的采样跨度；越界片段仍会被每格裁剪，不会侵入相邻格子。
@export_range(1.0, 1.35, 0.01) var cell_coverage: float = 1.04
## 允许草簇越过格子边界的范围；单位为格子半宽比例。
@export_range(0.0, 0.45, 0.01) var grass_cell_overflow: float = 0.20

@export_group("草材质")
## 背光时保留的基础亮度，避免草面完全发黑。
@export_range(0.0, 0.8, 0.01) var grass_light_wrap: float = 0.22
## 草尖亮边的颜色。
@export var grass_highlight_color: Color = Color("#b4ed72")
## 草尖亮边对基础色的混合强度。
@export_range(0.0, 2.0, 0.01) var grass_highlight_strength: float = 0.38
## 草尖亮边开始出现的高度比例。
@export_range(0.0, 1.0, 0.01) var grass_highlight_threshold: float = 0.62
## 草尖亮边的分段硬度；值越高越接近像素块。
@export_range(1.0, 16.0, 0.1) var grass_highlight_hardness: float = 5.0
## 亮边的低强度自发光，仅用于配合场景 Glow。
@export_range(0.0, 0.5, 0.01) var grass_emission_strength: float = 0.06
## 将模型法线朝上混合的强度；0 保留原始法线，1 完全按草坪朝上受光。
@export_range(0.0, 1.0, 0.01) var grass_normal_up_strength: float = 0.72
## 叶片根部颜色；通常比基础草色更深。
@export var grass_root_color: Color = Color("#244d12")
## 叶片顶端颜色；通常比基础草色更亮。
@export var grass_tip_color: Color = Color("#78bd4b")
## 根部到顶端渐变与基础草色的混合强度。
@export_range(0.0, 1.0, 0.01) var grass_gradient_strength: float = 0.75
## 渐变曲线指数；大于 1 会让亮色更靠近叶尖。
@export_range(0.25, 4.0, 0.01) var grass_gradient_exponent: float = 1.15
## 风摆最大位移；设为 0 可完全关闭风摆。
@export_range(0.0, 0.2, 0.001) var grass_wind_strength: float = 0.035
## 是否随时间动态摆动；关闭后保留每簇不同的静态姿态。
@export var grass_wind_animated: bool = true
## 风摆动画速度；值越大摆动越快。
@export_range(0.0, 4.0, 0.01) var grass_wind_speed: float = 1.1
## 风摆空间频率；值越大相邻草簇的相位差越明显。
@export_range(0.0, 4.0, 0.01) var grass_wind_frequency: float = 1.4
## 风摆在 XZ 平面内的方向向量。
@export var grass_wind_direction: Vector2 = Vector2(1.0, 0.25)

@export_group("模型草噪声")
## 密度噪声对每格草簇数量的影响强度。
@export_range(0.0, 0.8, 0.01) var density_noise_strength: float = 0.35
## 密度噪声的世界采样频率；值越大变化越快。
@export_range(0.01, 2.0, 0.01) var density_noise_frequency: float = 0.22
## 噪声降低密度时仍保留的最小草簇数量。
@export_range(1, 200, 1) var min_clumps_per_cell: int = 9
## 高度噪声对单个草簇垂直缩放的影响强度。
@export_range(0.0, 0.8, 0.01) var height_noise_strength: float = 0.20
## 高度噪声的世界采样频率；值越大高低变化越密集。
@export_range(0.01, 2.0, 0.01) var height_noise_frequency: float = 0.45
## 让连续世界噪声同时改变草簇的整体宽高。
@export_range(0.0, 0.8, 0.01) var grass_scale_noise_strength: float = 0.35
## 密度和高度噪声使用的种子；相同种子会生成相同分布。
@export var noise_seed: int = 912431

@export_group("随机分布")
## 草簇位置、旋转和模型比例随机化使用的种子。
@export var random_seed: int = 284731

func normalize() -> void:
	model_clumps_per_cell = maxi(model_clumps_per_cell, 1)
	model_grass_scale = clampf(model_grass_scale, 0.1, 1.5)
	for index in range(model_variant_weights.size()):
		model_variant_weights[index] = maxf(model_variant_weights[index], 0.0)
	cell_coverage = clampf(cell_coverage, 1.0, 1.35)
	grass_cell_overflow = clampf(grass_cell_overflow, 0.0, 0.45)
	grass_light_wrap = clampf(grass_light_wrap, 0.0, 0.8)
	grass_highlight_strength = clampf(grass_highlight_strength, 0.0, 2.0)
	grass_highlight_threshold = clampf(grass_highlight_threshold, 0.0, 1.0)
	grass_highlight_hardness = clampf(grass_highlight_hardness, 1.0, 16.0)
	grass_emission_strength = clampf(grass_emission_strength, 0.0, 0.5)
	grass_normal_up_strength = clampf(grass_normal_up_strength, 0.0, 1.0)
	grass_gradient_strength = clampf(grass_gradient_strength, 0.0, 1.0)
	grass_gradient_exponent = clampf(grass_gradient_exponent, 0.25, 4.0)
	grass_wind_strength = clampf(grass_wind_strength, 0.0, 0.2)
	grass_wind_speed = clampf(grass_wind_speed, 0.0, 4.0)
	grass_wind_frequency = clampf(grass_wind_frequency, 0.0, 4.0)
	if grass_wind_direction.length_squared() < 0.0001:
		grass_wind_direction = Vector2.RIGHT
	density_noise_strength = clampf(density_noise_strength, 0.0, 0.8)
	density_noise_frequency = clampf(density_noise_frequency, 0.01, 2.0)
	min_clumps_per_cell = maxi(min_clumps_per_cell, 1)
	height_noise_strength = clampf(height_noise_strength, 0.0, 0.8)
	height_noise_frequency = clampf(height_noise_frequency, 0.01, 2.0)
	grass_scale_noise_strength = clampf(grass_scale_noise_strength, 0.0, 0.8)

func make_signature() -> String:
	normalize()
	return "|".join([
		str(model_scene), model_mesh_name_filter + ":" + str(model_variant_weights), str(model_clumps_per_cell), str(model_grass_scale),
		str(grass_cast_shadow), str(dark_color), str(light_color), str(cell_coverage), str(grass_cell_overflow), str(grass_light_wrap), str(grass_highlight_color),
		str(grass_highlight_strength), str(grass_highlight_threshold), str(grass_highlight_hardness), str(grass_emission_strength),
		str(grass_normal_up_strength),
		str(grass_root_color), str(grass_tip_color), str(grass_gradient_strength), str(grass_gradient_exponent),
		str(grass_wind_strength), str(grass_wind_animated), str(grass_wind_speed), str(grass_wind_frequency), str(grass_wind_direction),
		str(density_noise_strength), str(density_noise_frequency), str(min_clumps_per_cell), str(height_noise_strength),
		str(height_noise_frequency), str(grass_scale_noise_strength), str(noise_seed), str(random_seed)
	])
