class_name EcsTransformSync3DSystem
extends EcsSystem

## Optional 3D presentation adapter. Copies Vector3 components to explicitly bound
## Node3D visuals after simulation. Euler rotations are expressed in radians.
const POSITION: StringName = &"position3d"
const ROTATION: StringName = &"rotation3d"
const SCALE: StringName = &"scale3d"

var sync: EcsNodeSync3D
## False copies local transforms; true copies world position, rotation and scale.
var use_global_transform: bool = false

var _query: EcsQuery
var _update_entity: Callable


func _init(node_sync: EcsNodeSync3D) -> void:
	sync = node_sync
	priority = 1000
	phase = Phase.PRESENTATION
	schedule_key = &"transform3d"
	reads = [POSITION, ROTATION, SCALE]


func configure(world: EcsWorld) -> void:
	_query = world.query({"all": [POSITION]})
	_update_entity = _sync_entity.bind(weakref(world))


func on_detach() -> void:
	_query = null
	_update_entity = Callable()


func on_update(_world: EcsWorld, _delta: float) -> void:
	if _query != null and sync != null:
		_query.for_each(_update_entity)


func _sync_entity(entity_id: int, world_ref: WeakRef) -> void:
	var world := world_ref.get_ref() as EcsWorld
	if world == null:
		return
	var node := sync.get_node(entity_id)
	var position_value: Variant = world.get_component(entity_id, POSITION)
	if node == null or not position_value is Vector3:
		return
	if use_global_transform and not node.is_inside_tree():
		return
	var rotation_value: Variant = world.get_component(entity_id, ROTATION)
	var scale_value: Variant = world.get_component(entity_id, SCALE)
	if use_global_transform:
		var next_transform := node.global_transform
		next_transform.origin = position_value
		if rotation_value is Vector3:
			next_transform.basis = Basis.from_euler(rotation_value) * Basis.from_scale(next_transform.basis.get_scale())
		if scale_value is Vector3:
			next_transform.basis = next_transform.basis.orthonormalized() * Basis.from_scale(scale_value)
		node.global_transform = next_transform
	else:
		node.position = position_value
		if rotation_value is Vector3:
			node.rotation = rotation_value
		if scale_value is Vector3:
			node.scale = scale_value
