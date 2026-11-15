extends Node3D
class_name CardPreviewPlaceholder

# Self-contained inspection behaviour for the primitive card placeholder.
const CARD_WIDTH := 2.0
const CARD_HEIGHT := 3.0
const INSPECTION_TILT := Vector2(-7.0, -16.0)
const NON_INSPECTION_TILT := Vector2.ZERO
const MAX_INSPECT_X_TILT := 7.0
const MAX_INSPECT_Y_TILT := 125.0
const INSPECTION_BOUNDARY_MULTIPLIER := 1.15
const HOVER_TILT_DURATION := 0.1
const RETURN_TILT_DURATION := 0.16
const SPIN_DURATION := 0.35

@onready var presentation_pivot: Node3D = $PresentationPivot
@onready var spin_pivot: Node3D = $PresentationPivot/SpinPivot

var hitbox: Area3D
var tilt_tween: Tween
var spin_tween: Tween
var inspection_camera: Camera3D
var is_inspecting := false
var inspection_enabled := true


func _ready() -> void:
	_create_hitbox()
	_set_presentation_tilt(NON_INSPECTION_TILT)


func _create_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.name = "InspectionArea"
	hitbox.input_ray_pickable = true
	spin_pivot.add_child(hitbox)

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(CARD_WIDTH, CARD_HEIGHT, 0.16)
	collision_shape.shape = box_shape
	hitbox.add_child(collision_shape)

	hitbox.mouse_entered.connect(_on_hitbox_mouse_entered)
	hitbox.mouse_exited.connect(_on_hitbox_mouse_exited)
	hitbox.input_event.connect(_on_hitbox_input_event)


func set_default_tilt() -> void:
	_set_presentation_tilt(INSPECTION_TILT)


func set_inspection_enabled(enabled: bool) -> void:
	inspection_enabled = enabled
	if hitbox != null:
		hitbox.input_ray_pickable = enabled
	if not enabled:
		_end_inspection()


func _process(_delta: float) -> void:
	if not inspection_enabled or not is_inspecting or inspection_camera == null:
		return
	if not visible:
		_end_inspection()
		return

	var pointer_position := get_viewport().get_mouse_position()
	if not _is_pointer_inside_inspection_bounds(pointer_position):
		_end_inspection()
		return
	_update_hover_tilt_from_pointer(pointer_position)


func _on_hitbox_mouse_entered() -> void:
	if not inspection_enabled:
		return
	is_inspecting = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_hitbox_mouse_exited() -> void:
	if not inspection_enabled or inspection_camera != null:
		return
	_end_inspection()


func _on_hitbox_input_event(
	camera: Camera3D,
	event: InputEvent,
	_world_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
) -> void:
	if not inspection_enabled:
		return
	if event is InputEventMouseMotion:
		inspection_camera = camera
		is_inspecting = true
		_update_hover_tilt_from_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_spin_once()


func _update_hover_tilt_from_pointer(pointer_position: Vector2) -> void:
	if inspection_camera == null:
		return

	var card_center := inspection_camera.unproject_position(global_position)
	var card_extent := _get_inspection_screen_extent()
	var normalized_x := clampf((pointer_position.x - card_center.x) / card_extent.x, -1.0, 1.0)
	var normalized_y := clampf((pointer_position.y - card_center.y) / card_extent.y, -1.0, 1.0)
	var target_tilt := Vector2(
		INSPECTION_TILT.x - normalized_y * MAX_INSPECT_X_TILT,
		INSPECTION_TILT.y + normalized_x * MAX_INSPECT_Y_TILT,
	)
	_tween_to_tilt(target_tilt, HOVER_TILT_DURATION)


func _get_inspection_screen_extent() -> Vector2:
	var card_center := inspection_camera.unproject_position(global_position)
	var horizontal_edge := inspection_camera.unproject_position(to_global(Vector3(CARD_WIDTH * 0.5, 0.0, 0.0)))
	var vertical_edge := inspection_camera.unproject_position(to_global(Vector3(0.0, CARD_HEIGHT * 0.5, 0.0)))
	return Vector2(
		maxf(absf(horizontal_edge.x - card_center.x), 1.0),
		maxf(absf(vertical_edge.y - card_center.y), 1.0),
	)


func _is_pointer_inside_inspection_bounds(pointer_position: Vector2) -> bool:
	var card_center := inspection_camera.unproject_position(global_position)
	var card_extent := _get_inspection_screen_extent() * INSPECTION_BOUNDARY_MULTIPLIER
	return absf(pointer_position.x - card_center.x) <= card_extent.x and absf(pointer_position.y - card_center.y) <= card_extent.y


func _end_inspection() -> void:
	is_inspecting = false
	inspection_camera = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var return_tilt := INSPECTION_TILT if inspection_enabled else NON_INSPECTION_TILT
	_tween_to_tilt(return_tilt, RETURN_TILT_DURATION)


func _tween_to_tilt(target_tilt: Vector2, duration: float) -> void:
	if tilt_tween != null:
		tilt_tween.kill()
	tilt_tween = create_tween()
	tilt_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tilt_tween.tween_property(
		presentation_pivot,
		"rotation_degrees",
		Vector3(target_tilt.x, target_tilt.y, 0.0),
		duration,
	)


func _set_presentation_tilt(tilt: Vector2) -> void:
	presentation_pivot.rotation_degrees = Vector3(tilt.x, tilt.y, 0.0)


func _spin_once() -> void:
	if spin_tween != null:
		spin_tween.kill()
	spin_pivot.rotation.y = fmod(spin_pivot.rotation.y, TAU)
	spin_tween = create_tween()
	spin_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	spin_tween.tween_property(spin_pivot, "rotation:y", spin_pivot.rotation.y + TAU, SPIN_DURATION)
