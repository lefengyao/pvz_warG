extends Node
class_name PlantLogic

# 点击草坪格子后发出的信号，参数为格子的二维索引（x: 行, y: 列）
signal cell_clicked(index: Vector2i)

# 渲染 3D 场景的相机，用于将屏幕坐标反投影为射线
@onready var camera: Camera3D = get_node("../../Camera3D")
# 草坪网格节点，负责格子坐标与世界坐标的相互转换
@onready var lawn_grid: LawnGrid = get_node("../../Background/Grass/LawnGrid")


func _unhandled_input(event: InputEvent) -> void:
	# 编辑器中不响应输入，避免影响编辑器操作
	if Engine.is_editor_hint():
		return
	# 只处理鼠标事件
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	# 只响应鼠标左键按下（忽略右键/中键以及松开事件）
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var click_started_usec := Time.get_ticks_usec()
	# 节点尚未就绪或已被销毁时，跳过处理
	if not is_instance_valid(camera) or not is_instance_valid(lawn_grid):
		return

	# 由鼠标屏幕位置构造一条穿过相机的射线（起点 + 方向）
	var ray_origin := camera.project_ray_origin(mouse_event.position)
	var ray_direction := camera.project_ray_normal(mouse_event.position)

	# 取草坪网格的局部 Y 轴作为平面法线，构造草坪所在的无限大平面
	# Plane 的构造方式：法线 n 与平面上任意一点 p 满足 n·p = d，这里用草坪原点求 d
	var plane_normal := lawn_grid.global_transform.basis.y.normalized()
	var lawn_plane := Plane(plane_normal, plane_normal.dot(lawn_grid.global_position))

	# 求射线与草坪平面的交点（无交点时返回 null，例如视线与平面平行）
	var hit: Variant = lawn_plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return

	# 将交点从射线（Variant）安全地转为 Vector3 世界坐标
	var world_position: Vector3 = hit

	# 把世界坐标转换为格子索引；x < 0 表示点击位置落在草坪网格之外
	var index := lawn_grid.get_cell_index_from_world(world_position)
	if index.x < 0:
		return

	# 调试输出被点击格子的行列信息
	var logic_time_ms := float(Time.get_ticks_usec() - click_started_usec) / 1000.0
	print("[PlantLogic] clicked lawn cell: row=%d, column=%d, index=%s, logic=%.3f ms, fps=%.1f" % [index.x, index.y, str(index), logic_time_ms, Engine.get_frames_per_second()])

	# 广播信号，通知外部（如种植管理器）在对应格子种植植物
	cell_clicked.emit(index)

	# 标记输入已处理，防止事件继续传播导致其他节点重复响应
	get_viewport().set_input_as_handled()
