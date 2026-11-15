class_name EcsLabControls
extends VBoxContainer

## UI-only controls for the lab. Gameplay/global input remains outside the lab.
var controller: Node
var _status_label: Label

func set_controller(value: Node) -> void:
	controller = value
	if controller != null and controller.has_signal("updated") and not controller.updated.is_connected(_on_updated):
		controller.updated.connect(_on_updated)
	_on_updated()

func _ready() -> void:
	_status_label = get_node_or_null("Status") as Label

func _on_step_pressed() -> void:
	if controller != null:
		controller.step_lab()

func _on_run_pressed() -> void:
	if controller != null:
		controller.run_lab()

func _on_pause_pressed() -> void:
	if controller != null:
		controller.pause_lab()

func _on_reset_pressed() -> void:
	if controller != null:
		controller.reset_lab()

func _on_updated() -> void:
	if _status_label == null or controller == null:
		return
	var summary: Dictionary = controller.state_summary()
	_status_label.text = "Tick %d  |  %s  |  %s  |  %d entities" % [summary.tick, summary.backend, summary.compute_mode, summary.entity_count]

func _exit_tree() -> void:
	if controller != null and controller.has_signal("updated") and controller.updated.is_connected(_on_updated):
		controller.updated.disconnect(_on_updated)
