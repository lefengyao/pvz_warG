class_name EcsLabPresentation
extends Node2D

## Presentation owns visual nodes and stable-UID bindings. It never advances the
## world; the controller calls refresh after a replay operation completes.
var controller: Node
var highlighted_entities: Array[int] = []
var _uid_to_entity: Dictionary = {}
var _uid_to_visual: Dictionary = {}
var _visual_root: Node2D
var _spatial: EcsSpatialIndex
var _spatial_world: EcsWorld

func _ready() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "EntityVisuals"
	add_child(_visual_root)

func set_controller(value: Node) -> void:
	if controller != null and controller.has_signal("updated") and controller.updated.is_connected(_on_controller_updated):
		controller.updated.disconnect(_on_controller_updated)
	controller = value
	if controller != null and controller.has_signal("updated"):
		controller.updated.connect(_on_controller_updated)
	refresh()

func refresh() -> void:
	if not is_inside_tree() or controller == null or not is_instance_valid(controller):
		return
	var world: EcsWorld = controller.world
	if world == null or world.is_disposed():
		_clear_visuals()
		return
	if _spatial == null or _spatial_world != world:
		if _spatial != null:
			_spatial.detach()
		_spatial = EcsSpatialIndex.new(world, &"position", 96.0)
		_spatial_world = world
	_clear_visuals()
	for entity: int in world.get_entities():
		var uid := world.get_entity_uid(entity)
		var position: Variant = world.get_component(entity, &"position", Vector2.ZERO)
		if not position is Vector2:
			continue
		var visual := Polygon2D.new()
		visual.name = "Entity_%d" % uid
		visual.polygon = PackedVector2Array([Vector2(0, -8), Vector2(8, 7), Vector2(-8, 7)])
		visual.color = Color("#8ad5c2")
		visual.position = position
		_visual_root.add_child(visual)
		_uid_to_entity[uid] = entity
		_uid_to_visual[uid] = visual
	var center := Vector2(480.0, 360.0)
	highlighted_entities = _spatial.nearest(center, 4, INF) if _spatial != null else []
	for entity in highlighted_entities:
		var entity_uid := world.get_entity_uid(entity)
		var marker: Polygon2D = _uid_to_visual.get(entity_uid)
		if marker != null:
			marker.color = Color("#f5c76b")

func get_bound_entity(uid: int) -> int:
	return int(_uid_to_entity.get(uid, -1))

func _on_controller_updated() -> void:
	refresh()

func _clear_visuals() -> void:
	_uid_to_entity.clear()
	_uid_to_visual.clear()
	highlighted_entities.clear()
	if _visual_root == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()

func _exit_tree() -> void:
	if controller != null and controller.has_signal("updated") and controller.updated.is_connected(_on_controller_updated):
		controller.updated.disconnect(_on_controller_updated)
	if _spatial != null:
		_spatial.detach()
	_spatial_world = null
