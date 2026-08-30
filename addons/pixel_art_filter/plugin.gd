@tool
extends EditorPlugin

const MENU_ITEM := "Pixel Art: Set Nearest Texture Filter"
var _auto_scan_pending := false

func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _apply_nearest_filter)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	if not get_tree().node_added.is_connected(_on_editor_node_added):
		get_tree().node_added.connect(_on_editor_node_added)
	call_deferred("_schedule_auto_scan")


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if get_tree().node_added.is_connected(_on_editor_node_added):
		get_tree().node_added.disconnect(_on_editor_node_added)
	remove_tool_menu_item(MENU_ITEM)
	_auto_scan_pending = false


func _on_scene_changed(_scene_root: Node) -> void:
	_schedule_auto_scan()


func _on_editor_node_added(node: Node) -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null or node == scene_root:
		return
	if not scene_root.is_ancestor_of(node):
		return
	_schedule_auto_scan()


func _schedule_auto_scan() -> void:
	if _auto_scan_pending:
		return
	_auto_scan_pending = true
	call_deferred("_run_auto_scan")


func _run_auto_scan() -> void:
	_auto_scan_pending = false
	if get_editor_interface().get_edited_scene_root() == null:
		return
	_apply_nearest_filter()


func _apply_nearest_filter() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		push_warning("Pixel Art Filter: no edited scene is open.")
		return

	var changes: Array[Dictionary] = []
	var seen: Dictionary = {}
	_collect_scene(scene_root, changes, seen)
	if changes.is_empty():
		print("Pixel Art Filter: no Sprite3D or BaseMaterial3D properties found.")
		return

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Set pixel art texture filtering to Nearest")
	for change in changes:
		var target: Object = change.target
		undo_redo.add_do_property(target, &"texture_filter", BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		undo_redo.add_undo_property(target, &"texture_filter", change.old_value)
	undo_redo.commit_action()
	print("Pixel Art Filter: set Nearest on %d resource(s)." % changes.size())


func _collect_scene(node: Node, changes: Array[Dictionary], seen: Dictionary) -> void:
	if node is Sprite3D:
		_record_target(node, changes, seen)

	if node is GeometryInstance3D:
		_record_material(node.material_override, changes, seen)

	if node is MeshInstance3D and node.mesh != null:
		var surface_count: int = node.mesh.get_surface_count()
		for surface_index in range(surface_count):
			_record_material(node.mesh.surface_get_material(surface_index), changes, seen)

	for child in node.get_children():
		_collect_scene(child, changes, seen)


func _record_material(material: Material, changes: Array[Dictionary], seen: Dictionary) -> void:
	if material is BaseMaterial3D:
		_record_target(material, changes, seen)


func _record_target(target: Object, changes: Array[Dictionary], seen: Dictionary) -> void:
	if not _has_property(target, &"texture_filter"):
		return
	var instance_id := target.get_instance_id()
	if seen.has(instance_id):
		return
	seen[instance_id] = true
	var old_value = target.get(&"texture_filter")
	if old_value == BaseMaterial3D.TEXTURE_FILTER_NEAREST:
		return
	changes.append({"target": target, "old_value": old_value})


func _has_property(target: Object, property_name: StringName) -> bool:
	for property_info in target.get_property_list():
		if property_info.name == property_name:
			return true
	return false
