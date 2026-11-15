class_name EcsTransformSyncSystem
extends EcsSystem

## Optional Godot 2D presentation adapter. Copies ECS transform components to the
## [Node2D] instances explicitly bound through [EcsNodeSync]. ECS remains authoritative.[br][br]
## [codeblock]
## var sync := EcsNodeSync.new(world)
## sync.bind(entity, $Player)
## world.add_system(EcsTransformSyncSystem.new(sync))
## [/codeblock]
##
## @tutorial(Node2D): https://docs.godotengine.org/en/stable/classes/class_node2d.html

## Component key for the [Vector2] copied to [member Node2D.position].
const POSITION: StringName = &"position"
## Optional component key for the [float] copied to [member Node2D.rotation].
const ROTATION: StringName = &"rotation"
## Optional component key for the [Vector2] copied to [member Node2D.scale].
const SCALE: StringName = &"scale"

## Binding table used to find the visual [Node2D] for an ECS entity.
var sync: EcsNodeSync

## Uses global position, rotation and scale when enabled. Local space is the default.
var use_global_transform: bool = false

var _query: EcsQuery
var _update_entity: Callable


## Creates the adapter for [param node_sync] and schedules it late at priority 1000,
## after gameplay systems have finished updating ECS state.
func _init(node_sync: EcsNodeSync) -> void:
	sync = node_sync
	priority = 1000
	phase = Phase.PRESENTATION
	schedule_key = &"transform2d"
	reads = [POSITION, ROTATION, SCALE]


func configure(world: EcsWorld) -> void:
	_query = world.query({"all": [POSITION]})
	_update_entity = _sync_entity.bind(weakref(world))


func on_detach() -> void:
	_query = null
	_update_entity = Callable()


## Copies [code]position[/code] for every bound entity; also copies [code]rotation[/code]
## and [code]scale[/code] when those optional components exist. Unbound entities are skipped.
func on_update(_world: EcsWorld, _delta: float) -> void:
	if _query != null and sync != null:
		_query.for_each(_update_entity)


func _sync_entity(entity_id: int, world_ref: WeakRef) -> void:
	var world := world_ref.get_ref() as EcsWorld
	if world == null:
		return
	var node := sync.get_node(entity_id)
	var position_value: Variant = world.get_component(entity_id, POSITION)
	if node == null or not position_value is Vector2:
		return
	if use_global_transform and not node.is_inside_tree():
		return
	var rotation_value: Variant = world.get_component(entity_id, ROTATION)
	var scale_value: Variant = world.get_component(entity_id, SCALE)
	if use_global_transform:
		node.global_position = position_value
		if rotation_value is float or rotation_value is int:
			node.global_rotation = float(rotation_value)
		if scale_value is Vector2:
			node.global_scale = scale_value
	else:
		node.position = position_value
		if rotation_value is float or rotation_value is int:
			node.rotation = float(rotation_value)
		if scale_value is Vector2:
			node.scale = scale_value
