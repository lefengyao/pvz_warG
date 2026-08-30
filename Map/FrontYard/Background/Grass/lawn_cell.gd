@tool
extends Node3D
class_name LawnCell

const LAWN_GRASS_SHADER: Shader = preload("res://Map/FrontYard/Background/Grass/lawn_cell_grass.gdshader")

## 可复用的单格草坪节点。格子只知道 Grid 提供的共享资源，不依赖 FrontYard 路径。
## 当前格子的行索引，由 LawnGrid 管理。
@export var row: int = 0
## 当前格子的列索引，由 LawnGrid 管理。
@export var column: int = 0
## 单格密度覆盖；-1 表示继承 LawnGrassSettings。
@export_range(-1, 200, 1) var density_override: int = -1:
	set(value):
		density_override = clampi(value, -1, 200)
		_queue_local_rebuild()
## 单格颜色样式覆盖；-1 表示按行列自动交替，0/1 固定深浅样式。
@export_range(-1, 1, 1) var style_override: int = -1:
	set(value):
		style_override = clampi(value, -1, 1)
		_queue_local_rebuild()
## 单格草簇高度倍率，会叠加在全局高度噪声结果上。
@export_range(0.1, 3.0, 0.01) var height_multiplier: float = 1.0:
	set(value):
		height_multiplier = clampf(value, 0.1, 3.0)
		_queue_local_rebuild()

var _grid: Node
var _settings: LawnGrassSettings
var _model_meshes: Array[Mesh] = []
var _model_bounds: Array[AABB] = []
var _grass_materials_by_variant: Array = []
var _density_noise: FastNoiseLite
var _height_noise: FastNoiseLite
var _cell_size := Vector2.ONE
var _grass_renderer: Node3D
var _model_instance_batches: Dictionary = {}
var _suppress_local_rebuild := false

func configure(
	grid: Node,
	settings: LawnGrassSettings,
	model_meshes: Array[Mesh],
	model_bounds: Array[AABB],
	grass_materials_by_variant: Array,
	density_noise: FastNoiseLite,
	height_noise: FastNoiseLite,
	cell_world_size: Vector2
) -> void:
	_grid = grid
	_settings = settings
	_model_meshes = model_meshes
	_model_bounds = model_bounds
	_grass_materials_by_variant = grass_materials_by_variant
	_density_noise = density_noise
	_height_noise = height_noise
	_cell_size = cell_world_size

func set_density_override(value: int) -> void:
	_suppress_local_rebuild = true
	density_override = value
	_suppress_local_rebuild = false

func set_style_override(value: int) -> void:
	_suppress_local_rebuild = true
	style_override = value
	_suppress_local_rebuild = false

func set_height_multiplier(value: float) -> void:
	_suppress_local_rebuild = true
	height_multiplier = value
	_suppress_local_rebuild = false

func get_override_signature() -> String:
	return "%d|%d|%.3f" % [density_override, style_override, height_multiplier]

func get_model_instance_batches() -> Dictionary:
	return _model_instance_batches

func _queue_local_rebuild() -> void:
	if _suppress_local_rebuild or _grid == null or not is_inside_tree() or not Engine.is_editor_hint():
		return
	if _grid.get("editor_preview") == false:
		return
	_grid.call_deferred("rebuild_cell", row, column)

func rebuild() -> void:
	if _settings == null:
		return
	_ensure_grass_renderer()
	_clear_generated_renderers()
	_model_instance_batches.clear()
	if _model_meshes.is_empty():
		push_warning("LawnCell has no model meshes; no grass generated")
		return
	_build_model_grass()

func _ensure_grass_renderer() -> void:
	if is_instance_valid(_grass_renderer):
		return
	_grass_renderer = get_node_or_null("GrassRenderer") as Node3D
	if _grass_renderer == null:
		_grass_renderer = Node3D.new()
		_grass_renderer.name = "GrassRenderer"
		_grass_renderer.set_meta("lawn_generated", true)
		add_child(_grass_renderer)

func _clear_generated_renderers() -> void:
	if not is_instance_valid(_grass_renderer):
		return
	for child in _grass_renderer.get_children():
		if child.get_meta("lawn_generated", false):
			child.free()

func _effective_style() -> int:
	if style_override >= 0:
		return clampi(style_override, 0, 1)
	return (row + column) % 2

func _effective_model_density() -> int:
	var base_density := density_override if density_override >= 0 else _settings.model_clumps_per_cell
	base_density = maxi(base_density, 1)
	var world_center := to_global(Vector3.ZERO)
	var noise_value := 0.0
	if _density_noise != null:
		noise_value = _density_noise.get_noise_2d(world_center.x, world_center.z)
	var varied_density := roundi(float(base_density) * (1.0 + noise_value * _settings.density_noise_strength))
	return maxi(varied_density, _settings.min_clumps_per_cell)

func _build_variant_schedule(total_density: int, rng: RandomNumberGenerator) -> Array[int]:
	var variant_count := _model_meshes.size()
	var weights: Array[float] = []
	var active_indices: Array[int] = []
	var weight_sum := 0.0
	for variant_index in range(variant_count):
		var weight := 1.0
		if variant_index < _settings.model_variant_weights.size():
			weight = maxf(_settings.model_variant_weights[variant_index], 0.0)
		weights.append(weight)
		if weight > 0.0:
			active_indices.append(variant_index)
			weight_sum += weight
	if active_indices.is_empty():
		for variant_index in range(variant_count):
			weights[variant_index] = 1.0
			active_indices.append(variant_index)
		weight_sum = float(variant_count)

	var counts: Array[int] = []
	counts.resize(variant_count)
	for variant_index in range(variant_count):
		counts[variant_index] = 0
	if total_density < active_indices.size():
		# 密度不足以覆盖全部变体时，优先保留权重较高的模型。
		var remaining_indices: Array[int] = active_indices.duplicate()
		for _slot in range(total_density):
			var best_index := remaining_indices[0]
			for candidate in remaining_indices:
				if weights[candidate] > weights[best_index]:
					best_index = candidate
			counts[best_index] = 1
			remaining_indices.erase(best_index)
	else:
		# 每个正权重变体先保底一个，再按最大余数法分配剩余名额。
		for variant_index in active_indices:
			counts[variant_index] = 1
		var remaining_density := total_density - active_indices.size()
		var used_density := 0
		var fractions: Array[float] = []
		fractions.resize(variant_count)
		for variant_index in range(variant_count):
			fractions[variant_index] = 0.0
		for variant_index in active_indices:
			var target := float(remaining_density) * weights[variant_index] / weight_sum
			var whole := floori(target)
			counts[variant_index] += whole
			used_density += whole
			fractions[variant_index] = target - float(whole)
		while used_density < remaining_density:
			var best_index := active_indices[0]
			for candidate in active_indices:
				if fractions[candidate] > fractions[best_index]:
					best_index = candidate
			counts[best_index] += 1
			fractions[best_index] = -1.0
			used_density += 1

	var schedule: Array[int] = []
	for variant_index in range(variant_count):
		for _instance_index in range(counts[variant_index]):
			schedule.append(variant_index)
	for index in range(schedule.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swapped := schedule[index]
		schedule[index] = schedule[swap_index]
		schedule[swap_index] = swapped
	return schedule

func _build_model_grass() -> void:
	var density := _effective_model_density()
	var grid_side := maxi(ceili(sqrt(float(density))), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = _settings.random_seed + row * 1009 + column * 9176
	var style_id := _effective_style()
	var variant_schedule := _build_variant_schedule(density, rng)
	var transforms_by_variant: Array[Array] = []
	var custom_data_by_variant: Array[Array] = []
	for _variant in _model_meshes:
		transforms_by_variant.append([])
		custom_data_by_variant.append([])
	var cell_center_world := to_global(Vector3.ZERO)

	for clump_index in range(density):
		var grid_x := clump_index % grid_side
		var grid_z := int(float(clump_index) / float(grid_side))
		var jitter_x := rng.randf_range(-0.18, 0.18)
		var jitter_z := rng.randf_range(-0.18, 0.18)
		var local_position := Vector3(
			((float(grid_x) + 0.5 + jitter_x) / float(grid_side) - 0.5) * _cell_size.x * _settings.cell_coverage,
			0.0,
			((float(grid_z) + 0.5 + jitter_z) / float(grid_side) - 0.5) * _cell_size.y * _settings.cell_coverage
		)
		var world_position := to_global(local_position)
		var variant_index: int = variant_schedule[clump_index]
		var base_scale := _settings.model_grass_scale * rng.randf_range(0.88, 1.12)
		var height_noise_value := 0.0
		if _height_noise != null:
			height_noise_value = _height_noise.get_noise_2d(world_position.x, world_position.z)
		var vertical_noise_scale := 1.0 + height_noise_value * _settings.height_noise_strength
		var overall_noise_scale := 1.0 + height_noise_value * _settings.grass_scale_noise_strength
		var height_scale := base_scale * maxf(height_multiplier, 0.1) * vertical_noise_scale * overall_noise_scale
		var width_scale := base_scale * rng.randf_range(0.94, 1.06) * overall_noise_scale
		var yaw := rng.randf_range(0.0, TAU)
		var instance_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, width_scale))
		var bounds := _model_bounds[variant_index]
		var mesh_origin := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var instance_transform := Transform3D(instance_basis, local_position - instance_basis * mesh_origin)
		transforms_by_variant[variant_index].append(instance_transform)
		custom_data_by_variant[variant_index].append(Color(cell_center_world.x, cell_center_world.z, yaw, width_scale))

	_model_instance_batches = {
		"style_id": style_id,
		"transforms_by_variant": transforms_by_variant,
		"custom_data_by_variant": custom_data_by_variant,
	}

func _get_cell_clip_aabb() -> AABB:
	var tallest_model := 0.0
	for bounds in _model_bounds:
		tallest_model = maxf(tallest_model, bounds.size.y)
	var height_scale := _settings.model_grass_scale * 1.12 * height_multiplier * (1.0 + _settings.height_noise_strength)
	var clipped_height := maxf(tallest_model * height_scale + 0.05, 0.05)
	# 顶点风摆会把叶尖水平推出原始包围盒，预留余量避免边缘实例被提前裁掉。
	var wind_margin := maxf(_settings.grass_wind_strength, 0.0) * 1.25
	var clip_half_size := _cell_size * (0.5 + _settings.grass_cell_overflow) + Vector2(wind_margin, wind_margin)
	return AABB(
		Vector3(-clip_half_size.x, 0.0, -clip_half_size.y),
		Vector3(clip_half_size.x * 2.0, clipped_height, clip_half_size.y * 2.0)
	)
