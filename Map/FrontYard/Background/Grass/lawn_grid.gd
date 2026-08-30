@tool
extends Node3D
class_name LawnGrid

const LAWN_CELL_SCENE: PackedScene = preload("res://Map/FrontYard/Background/Grass/LawnCell.tscn")
const LAWN_RENDER_CHUNK_SCENE: PackedScene = preload("res://Map/FrontYard/Background/Grass/LawnRenderChunk.tscn")
const LAWN_RENDER_CHUNK_SCRIPT: Script = preload("res://Map/FrontYard/Background/Grass/lawn_render_chunk.gd")
const LAWN_GRASS_SHADER: Shader = preload("res://Map/FrontYard/Background/Grass/lawn_cell_grass.gdshader")

@export_group("地图布局")
## 草坪行数；修改后会重建格子节点。
@export var rows: int = 5:
	set(value):
		var normalized := maxi(value, 1)
		if rows == normalized:
			return
		rows = normalized
		_queue_rebuild()
## 草坪列数；修改后会重建格子节点。
@export var columns: int = 9:
	set(value):
		var normalized := maxi(value, 1)
		if columns == normalized:
			return
		columns = normalized
		_queue_rebuild()
## 单个草格的世界尺寸，X 为横向、Y 为纵向。
@export var cell_size: Vector2 = Vector2(2.0, 2.0):
	set(value):
		var normalized := Vector2(maxf(value.x, 0.25), maxf(value.y, 0.25))
		if cell_size == normalized:
			return
		cell_size = normalized
		_queue_rebuild()
## 每个渲染区块包含的草坪行数；数值越大绘制提交越少，但单格修改重建范围更大。
@export_range(1, 16, 1) var render_chunk_rows: int = 3:
	set(value):
		var normalized := maxi(value, 1)
		if render_chunk_rows == normalized:
			return
		render_chunk_rows = normalized
		_queue_rebuild()
## 每个渲染区块包含的草坪列数；数值越大绘制提交越少，但单格修改重建范围更大。
@export_range(1, 16, 1) var render_chunk_columns: int = 3:
	set(value):
		var normalized := maxi(value, 1)
		if render_chunk_columns == normalized:
			return
		render_chunk_columns = normalized
		_queue_rebuild()
## 草坪生成设置资源；包含模型、颜色、材质和噪声参数。
@export var settings: LawnGrassSettings = preload("res://Map/FrontYard/Background/Grass/LawnGrassSettings.tres"):
	set(value):
		if settings == value:
			return
		settings = value
		_queue_rebuild()
## 是否在编辑器视口中自动生成草坪预览。
@export var editor_preview: bool = true:
	set(value):
		if editor_preview == value:
			return
		editor_preview = value
		_queue_rebuild()
## 手动立即重建所有草格的编辑器按钮。
@export_tool_button("Rebuild Lawn Grid") var rebuild_preview_action = rebuild_all_cells

var cells: Dictionary = {}
var render_chunks: Dictionary = {}
var _model_grass_meshes: Array[Mesh] = []
var _model_grass_bounds: Array[AABB] = []
var _grass_materials_by_variant: Array = []
var _model_scene_signature := ""
var _grass_material_signature := ""
var _density_noise: FastNoiseLite
var _height_noise: FastNoiseLite
var _noise_signature := ""
var _last_signature := ""
var _rebuild_queued := false
var _built_once := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not _built_once:
			rebuild_all_cells()
	else:
		call_deferred("_rebuild_if_needed")

func _rebuild_if_needed() -> void:
	if not _built_once:
		rebuild_all_cells()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not editor_preview:
		return
	if _last_signature != _render_signature():
		rebuild_all_cells()

func _queue_rebuild() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_run_queued_rebuild")

func _run_queued_rebuild() -> void:
	_rebuild_queued = false
	if is_inside_tree() and editor_preview:
		rebuild_all_cells()

func rebuild_all_cells() -> void:
	if settings == null:
		settings = LawnGrassSettings.new()
	settings.normalize()
	rows = maxi(rows, 1)
	columns = maxi(columns, 1)
	cell_size = Vector2(maxf(cell_size.x, 0.25), maxf(cell_size.y, 0.25))
	_prepare_model_resources()
	_prepare_noise_resources()
	_sync_cell_nodes()
	_clear_render_chunks()
	for row in range(rows):
		for column in range(columns):
			var cell := cells.get(Vector2i(row, column)) as LawnCell
			if cell == null:
				continue
			_configure_cell(cell)
			cell.rebuild()
	_rebuild_all_render_chunks()
	_last_signature = _render_signature()
	_built_once = true

func rebuild_cell(row: int, column: int) -> bool:
	var cell := cells.get(Vector2i(row, column)) as LawnCell
	if cell == null:
		if not _is_valid_cell(row, column):
			return false
		rebuild_all_cells()
		cell = cells.get(Vector2i(row, column)) as LawnCell
	if cell == null:
		return false
	_configure_cell(cell)
	cell.rebuild()
	_rebuild_render_chunk(_chunk_key_for_cell(row, column))
	_last_signature = _render_signature()
	return true

func set_cell_grass_density(row: int, column: int, density: int) -> bool:
	var cell := _ensure_cell(row, column)
	if cell == null:
		return false
	cell.set_density_override(maxi(density, 1))
	return rebuild_cell(row, column)

func set_cell_grass_style(row: int, column: int, style_id: int) -> bool:
	var cell := _ensure_cell(row, column)
	if cell == null:
		return false
	cell.set_style_override(clampi(style_id, 0, 1))
	return rebuild_cell(row, column)

func get_cell(row: int, column: int) -> LawnCell:
	return cells.get(Vector2i(row, column)) as LawnCell

func get_board_size() -> Vector2:
	return Vector2(columns * cell_size.x, rows * cell_size.y)

func get_render_chunk_count() -> int:
	return render_chunks.size()

func is_built() -> bool:
	return _built_once

func get_render_instance_count() -> int:
	var total := 0
	for chunk in render_chunks.values():
		if not is_instance_valid(chunk):
			continue
		for child in chunk.get_children():
			if child is MultiMeshInstance3D and child.multimesh != null:
				total += child.multimesh.instance_count
	return total

func get_layout_signature() -> String:
	return "%d|%d|%s|%d|%d" % [rows, columns, str(cell_size), render_chunk_rows, render_chunk_columns]

func get_render_signature() -> String:
	return _render_signature()

func _render_signature() -> String:
	var settings_signature := settings.make_signature() if settings != null else "null"
	var cell_signatures := PackedStringArray()
	for row in range(rows):
		for column in range(columns):
			var cell := cells.get(Vector2i(row, column)) as LawnCell
			cell_signatures.append(cell.get_override_signature() if cell != null else "missing")
	return "%s|%s|%s|%s" % [get_layout_signature(), settings_signature, str(cells.size()), ";".join(cell_signatures)]

func _ensure_cell(row: int, column: int) -> LawnCell:
	var cell := cells.get(Vector2i(row, column)) as LawnCell
	if cell != null:
		return cell
	if not _is_valid_cell(row, column):
		return null
	rebuild_all_cells()
	return cells.get(Vector2i(row, column)) as LawnCell

func _configure_cell(cell: LawnCell) -> void:
	cell.configure(
		self,
		settings,
		_model_grass_meshes,
		_model_grass_bounds,
		_grass_materials_by_variant,
		_density_noise,
		_height_noise,
		cell_size
	)

func _sync_cell_nodes() -> void:
	var next_cells: Dictionary = {}
	for child in get_children():
		if not child is LawnCell:
			continue
		var cell := child as LawnCell
		var key := Vector2i(cell.row, cell.column)
		if _is_valid_cell(cell.row, cell.column) and not next_cells.has(key):
			next_cells[key] = cell
			cell.position = _cell_position(cell.row, cell.column)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				cell.owner = get_tree().edited_scene_root
		else:
			if cell.get_meta("lawn_generated", false):
				cell.free()

	for row in range(rows):
		for column in range(columns):
			var key := Vector2i(row, column)
			if next_cells.has(key):
				continue
			var cell := LAWN_CELL_SCENE.instantiate() as LawnCell
			if cell == null:
				push_error("LawnCell scene could not be instantiated")
				continue
			cell.name = "LawnCell_%d_%d" % [row, column]
			cell.row = row
			cell.column = column
			cell.position = _cell_position(row, column)
			cell.set_meta("lawn_generated", true)
			add_child(cell)
			if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
				cell.owner = get_tree().edited_scene_root
			next_cells[key] = cell
	cells = next_cells

func _clear_render_chunks() -> void:
	for child in get_children():
		if child is Node3D and child.get_script() == LAWN_RENDER_CHUNK_SCRIPT and child.get_meta("lawn_generated", false):
			child.free()
	render_chunks.clear()

func _rebuild_all_render_chunks() -> void:
	for chunk_row in range(ceili(float(rows) / float(render_chunk_rows))):
		for chunk_column in range(ceili(float(columns) / float(render_chunk_columns))):
			_rebuild_render_chunk(Vector2i(chunk_row, chunk_column))

func _chunk_key_for_cell(row: int, column: int) -> Vector2i:
	return Vector2i(
		int(float(row) / float(render_chunk_rows)),
		int(float(column) / float(render_chunk_columns))
	)

func _rebuild_render_chunk(chunk_key: Vector2i) -> void:
	var merged_transforms: Dictionary = {}
	var merged_custom_data: Dictionary = {}
	for row in range(chunk_key.x * render_chunk_rows, mini((chunk_key.x + 1) * render_chunk_rows, rows)):
		for column in range(chunk_key.y * render_chunk_columns, mini((chunk_key.y + 1) * render_chunk_columns, columns)):
			var cell := cells.get(Vector2i(row, column)) as LawnCell
			if cell == null:
				continue
			var batches := cell.get_model_instance_batches()
			var style_id := int(batches.get("style_id", 0))
			var transforms_by_variant: Array = batches.get("transforms_by_variant", [])
			var custom_data_by_variant: Array = batches.get("custom_data_by_variant", [])
			for variant_index in range(mini(transforms_by_variant.size(), _model_grass_meshes.size())):
				var cell_transforms: Array = transforms_by_variant[variant_index]
				var cell_custom_data: Array = custom_data_by_variant[variant_index] if variant_index < custom_data_by_variant.size() else []
				if cell_transforms.is_empty():
					continue
				var batch_key := Vector2i(style_id, variant_index)
				if not merged_transforms.has(batch_key):
					merged_transforms[batch_key] = []
					merged_custom_data[batch_key] = []
				for instance_index in range(cell_transforms.size()):
					merged_transforms[batch_key].append(cell.transform * cell_transforms[instance_index])
					merged_custom_data[batch_key].append(cell_custom_data[instance_index])
	var chunk := render_chunks.get(chunk_key) as Node3D
	if chunk == null:
		chunk = LAWN_RENDER_CHUNK_SCENE.instantiate() as Node3D
		if chunk == null:
			push_error("LawnRenderChunk scene could not be instantiated")
			return
		chunk.name = "LawnRenderChunk_%d_%d" % [chunk_key.x, chunk_key.y]
		chunk.set_meta("lawn_generated", true)
		add_child(chunk)
		render_chunks[chunk_key] = chunk
	chunk.call("rebuild", merged_transforms, merged_custom_data, _model_grass_meshes, _grass_materials_by_variant, _get_render_chunk_aabb(chunk_key))

func _get_render_chunk_aabb(chunk_key: Vector2i) -> AABB:
	var first_row := chunk_key.x * render_chunk_rows
	var first_column := chunk_key.y * render_chunk_columns
	var last_row := mini((chunk_key.x + 1) * render_chunk_rows, rows) - 1
	var last_column := mini((chunk_key.y + 1) * render_chunk_columns, columns) - 1
	var first_center := _cell_position(first_row, first_column)
	var last_center := _cell_position(last_row, last_column)
	var wind_margin := maxf(settings.grass_wind_strength, 0.0) * 1.25
	var half_size := cell_size * (0.5 + settings.grass_cell_overflow) + Vector2(wind_margin, wind_margin)
	var tallest_model := _get_tallest_model_height()
	var height_scale := settings.model_grass_scale * 1.12 * 3.0 * (1.0 + settings.height_noise_strength)
	var clipped_height := maxf(tallest_model * height_scale + 0.05, 0.05)
	return AABB(
		Vector3(first_center.x - half_size.x, 0.0, first_center.z - half_size.y),
		Vector3(last_center.x - first_center.x + half_size.x * 2.0, clipped_height, last_center.z - first_center.z + half_size.y * 2.0)
	)

func _cell_position(row: int, column: int) -> Vector3:
	var board_size := get_board_size()
	return Vector3(
		(column + 0.5) * cell_size.x - board_size.x * 0.5,
		0.0,
		(row + 0.5) * cell_size.y - board_size.y * 0.5
	)

func _prepare_model_resources() -> void:
	var scene := settings.model_scene if settings != null else null
	var filter := settings.model_mesh_name_filter if settings != null else ""
	var signature := "%s|%s" % [str(scene), filter]
	if signature == _model_scene_signature:
		return
	_model_scene_signature = signature
	_model_grass_meshes.clear()
	_model_grass_bounds.clear()
	if scene == null:
		return
	var source_root := scene.instantiate()
	if source_root == null:
		push_warning("Model grass scene could not be instantiated")
		return
	_collect_model_meshes(source_root, filter)
	source_root.free()
	if _model_grass_meshes.is_empty():
		push_warning("Model grass scene contains no matching MeshInstance3D meshes")

func _collect_model_meshes(node: Node, filter: String) -> void:
	if node is MeshInstance3D and node.mesh != null and (filter.is_empty() or node.name.to_lower().contains(filter.to_lower())):
		var mesh: Mesh = node.mesh
		_model_grass_meshes.append(mesh)
		_model_grass_bounds.append(mesh.get_aabb())
	for child in node.get_children():
		_collect_model_meshes(child, filter)

func _prepare_noise_resources() -> void:
	if _grass_material_signature != _get_grass_material_signature() or not _grass_material_cache_is_valid():
		_prepare_grass_materials()
	if _density_noise == null:
		_density_noise = FastNoiseLite.new()
	if _height_noise == null:
		_height_noise = FastNoiseLite.new()
	var noise_signature := "%d|%d|%.4f|%.4f" % [settings.noise_seed, settings.noise_seed + 104729, settings.density_noise_frequency, settings.height_noise_frequency]
	if noise_signature == _noise_signature:
		return
	_density_noise.seed = settings.noise_seed
	_density_noise.frequency = settings.density_noise_frequency
	_density_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.seed = settings.noise_seed + 104729
	_height_noise.frequency = settings.height_noise_frequency
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_signature = noise_signature

func _get_grass_material_signature() -> String:
	return "%s|%s|%s|%.3f|%.3f|%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%s|%s|%.3f|%.3f|%.3f|%s|%.3f|%.3f|%s" % [
		str(settings.dark_color), str(settings.light_color), str(cell_size), settings.grass_cell_overflow, settings.grass_light_wrap,
		str(settings.grass_highlight_color), settings.grass_highlight_strength, settings.grass_highlight_threshold,
		settings.grass_highlight_hardness, settings.grass_emission_strength, _get_tallest_model_height(),
		settings.grass_normal_up_strength, str(settings.grass_root_color), str(settings.grass_tip_color),
		settings.grass_gradient_strength, settings.grass_gradient_exponent,
		settings.grass_wind_strength, str(settings.grass_wind_animated), settings.grass_wind_speed, settings.grass_wind_frequency,
		str(settings.grass_wind_direction)
	]

func _grass_material_cache_is_valid() -> bool:
	if _grass_materials_by_variant.size() != 2:
		return false
	for style_materials in _grass_materials_by_variant:
		if not style_materials is Array or style_materials.size() != _model_grass_meshes.size():
			return false
	return true

func _prepare_grass_materials() -> void:
	_grass_material_signature = _get_grass_material_signature()
	_grass_materials_by_variant.clear()
	var reference_base_color := settings.dark_color.lerp(settings.light_color, 0.5)
	for color in [settings.dark_color, settings.light_color]:
		var style_materials: Array = []
		var style_root_color := _scale_gradient_color(color, settings.grass_root_color, reference_base_color)
		var style_tip_color := _scale_gradient_color(color, settings.grass_tip_color, reference_base_color)
		for variant_index in range(_model_grass_meshes.size()):
			var material := ShaderMaterial.new()
			material.shader = LAWN_GRASS_SHADER
			material.set_shader_parameter("grass_color", color)
			material.set_shader_parameter("cell_size", cell_size)
			material.set_shader_parameter("grass_cell_overflow", settings.grass_cell_overflow)
			material.set_shader_parameter("grass_light_wrap", settings.grass_light_wrap)
			material.set_shader_parameter("grass_highlight_color", settings.grass_highlight_color)
			material.set_shader_parameter("grass_highlight_strength", settings.grass_highlight_strength)
			material.set_shader_parameter("grass_highlight_threshold", settings.grass_highlight_threshold)
			material.set_shader_parameter("grass_highlight_hardness", settings.grass_highlight_hardness)
			material.set_shader_parameter("grass_emission_strength", settings.grass_emission_strength)
			material.set_shader_parameter("grass_normal_up_strength", settings.grass_normal_up_strength)
			material.set_shader_parameter("grass_root_color", style_root_color)
			material.set_shader_parameter("grass_tip_color", style_tip_color)
			material.set_shader_parameter("grass_gradient_strength", settings.grass_gradient_strength)
			material.set_shader_parameter("grass_gradient_exponent", settings.grass_gradient_exponent)
			material.set_shader_parameter("grass_wind_strength", settings.grass_wind_strength)
			material.set_shader_parameter("grass_wind_animated", settings.grass_wind_animated)
			material.set_shader_parameter("grass_wind_speed", settings.grass_wind_speed)
			material.set_shader_parameter("grass_wind_frequency", settings.grass_wind_frequency)
			material.set_shader_parameter("grass_wind_direction", settings.grass_wind_direction)
			var variant_height := maxf(_model_grass_bounds[variant_index].size.y, 0.001)
			material.set_shader_parameter("grass_variant_height", variant_height)
			style_materials.append(material)
		_grass_materials_by_variant.append(style_materials)

func _scale_gradient_color(base_color: Color, reference_color: Color, reference_base_color: Color) -> Color:
	var reference_luminance := _color_luminance(reference_base_color)
	var scale_factor := _color_luminance(base_color) / maxf(reference_luminance, 0.001)
	return Color(
		clampf(reference_color.r * scale_factor, 0.0, 1.0),
		clampf(reference_color.g * scale_factor, 0.0, 1.0),
		clampf(reference_color.b * scale_factor, 0.0, 1.0),
		reference_color.a
	)

func _color_luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _get_tallest_model_height() -> float:
	var tallest := 0.0
	for bounds in _model_grass_bounds:
		tallest = maxf(tallest, bounds.size.y)
	return maxf(tallest, 0.001)

func _is_valid_cell(row: int, column: int) -> bool:
	return row >= 0 and row < rows and column >= 0 and column < columns
