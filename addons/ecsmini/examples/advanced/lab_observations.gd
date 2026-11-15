class_name EcsLabObservations
extends VBoxContainer

## Small read-only observation module kept separate from controls and rendering.
var controller: Node
var _label: Label

func set_controller(value: Node) -> void:
	controller = value
	if controller != null and controller.has_signal("updated") and not controller.updated.is_connected(_on_updated):
		controller.updated.connect(_on_updated)
	_on_updated()

func _ready() -> void:
	_label = get_node_or_null("ObservationText") as Label

func _on_updated() -> void:
	if _label == null or controller == null:
		return
	var summary: Dictionary = controller.state_summary()
	_label.text = "Rows: %d  Followers: %d  Replay: %d..%d" % [summary.group_count, summary.relation_count, summary.oldest_tick, summary.latest_tick]

func _exit_tree() -> void:
	if controller != null and controller.has_signal("updated") and controller.updated.is_connected(_on_updated):
		controller.updated.disconnect(_on_updated)
