@tool
extends Node3D

## FrontYard 只负责场景编排；草坪生命周期由 LawnGrid 管理。

@export_group("相机快捷控制")
## 修改后将 Camera3D 摆放为沿 Z 轴俯视草坪的对应角度。
@export_range(15.0, 75.0, 0.5) var camera_down_angle: float = 30.0:
	set(value):
		camera_down_angle = clampf(value, 15.0, 75.0)
		_queue_camera_control_apply()
## 修改后同步 Camera3D 与草坪中心的水平距离（Z 轴），单位为世界单位。
@export_range(1.0, 60.0, 0.1) var camera_distance: float = 15.0:
	set(value):
		camera_distance = maxf(value, 1.0)
		_queue_camera_control_apply()
## 修改后同步 Camera3D 的垂直距离（Y 轴），与水平距离独立调整。
@export_range(0.5, 60.0, 0.1) var camera_height: float = 10.0:
	set(value):
		camera_height = maxf(value, 0.5)
		_queue_camera_control_apply()
## 修改后同步 Camera3D 的垂直 FOV；Projection、Current 和裁剪面仍由 Camera3D Inspector 管理。
@export_range(20.0, 75.0, 0.5) var camera_fov: float = 42.0:
	set(value):
		camera_fov = clampf(value, 20.0, 75.0)
		_queue_camera_control_apply()

@export_group("编辑器预览")
## 是否在编辑器中生成并显示草坪预览。
@export var editor_preview: bool = true:
	set(value):
		editor_preview = value
		if lawn_grid != null:
			lawn_grid.editor_preview = value
## 手动立即重建编辑器中的草坪预览。
@export_tool_button("Rebuild Preview") var rebuild_preview_action = _editor_rebuild_preview

var camera: Camera3D
var lawn_grid: LawnGrid

var _preview_ready := false

func _ready() -> void:
	_resolve_scene_nodes()
	_apply_camera_controls()
	_initialize_preview()
	if Engine.is_editor_hint():
		call_deferred("_initialize_preview")

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not is_instance_valid(camera) or not is_instance_valid(lawn_grid):
		_resolve_scene_nodes()
	if not _preview_ready:
		_initialize_preview()

func _editor_rebuild_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_preview_ready = false
	_initialize_preview()

func _resolve_scene_nodes() -> void:
	camera = _find_scene_node("Camera3D") as Camera3D
	lawn_grid = _find_scene_node("LawnGrid") as LawnGrid

func _find_scene_node(node_name: String) -> Node:
	var direct := get_node_or_null(node_name)
	if direct != null:
		return direct
	return find_child(node_name, true, false)

func _queue_camera_control_apply() -> void:
	if not is_inside_tree():
		return
	call_deferred("_apply_camera_controls")

func _apply_camera_controls() -> void:
	_resolve_scene_nodes()
	if not is_instance_valid(camera):
		return
	var horizontal_distance := maxf(camera_distance, 1.0)
	var vertical_distance := maxf(camera_height, 0.5)
	camera.position = Vector3(0.0, vertical_distance, horizontal_distance)
	camera.rotation_degrees = Vector3(-camera_down_angle, 0.0, 0.0)
	camera.fov = camera_fov

func _initialize_preview() -> void:
	if _preview_ready or not is_inside_tree():
		return
	_resolve_scene_nodes()
	if not is_instance_valid(lawn_grid):
		return
	_ensure_world_environment()
	lawn_grid.editor_preview = editor_preview
	if not lawn_grid.is_built():
		lawn_grid.rebuild_all_cells()
	_preview_ready = true

func _ensure_world_environment() -> void:
	var world_environment := _find_scene_node("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment == null:
		world_environment.environment = Environment.new()

## 公开转发 API；单格属性由 LawnGrid/LawnCell 保存。
func set_cell_grass_style(row: int, column: int, style_id: int) -> bool:
	if not is_instance_valid(lawn_grid):
		_resolve_scene_nodes()
	if not is_instance_valid(lawn_grid):
		return false
	return lawn_grid.set_cell_grass_style(row, column, style_id)

## 公开转发 API；单格密度由 LawnGrid/LawnCell 保存。
func set_cell_grass_density(row: int, column: int, density: int) -> bool:
	if not is_instance_valid(lawn_grid):
		_resolve_scene_nodes()
	if not is_instance_valid(lawn_grid):
		return false
	return lawn_grid.set_cell_grass_density(row, column, density)
