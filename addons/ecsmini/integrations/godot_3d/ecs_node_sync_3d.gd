class_name EcsNodeSync3D
extends RefCounted

## Optional one-to-one entity / [Node3D] bridge. World and visual nodes are weakly
## referenced, and neither is created or freed by this adapter.

var _entity_to_node: Dictionary = {}
var _entity_to_instance: Dictionary = {}
var _entity_to_uid: Dictionary = {}
var _node_to_entity: Dictionary = {}
var _world_ref: WeakRef


func _init(world: EcsWorld = null) -> void:
	attach_world(world)


## Changes worlds and drops old bindings. Passing [code]null[/code] detaches.
func attach_world(world: EcsWorld) -> void:
	var previous := _get_world()
	if previous == world and world != null:
		return
	if previous != null:
		if previous.entity_destroyed.is_connected(_on_entity_destroyed):
			previous.entity_destroyed.disconnect(_on_entity_destroyed)
		if previous.is_connected(&"disposed", _on_world_disposed):
			previous.disconnect(&"disposed", _on_world_disposed)
		if previous.restored.is_connected(_on_world_restored):
			previous.restored.disconnect(_on_world_restored)
	clear()
	_world_ref = null
	if world == null or world.is_disposed():
		return
	_world_ref = weakref(world)
	world.entity_destroyed.connect(_on_entity_destroyed)
	world.connect(&"disposed", _on_world_disposed)
	world.restored.connect(_on_world_restored)


## Replaces either endpoint's previous binding while maintaining one-to-one mapping.
func bind(entity_id: int, node: Node3D) -> bool:
	var world := _get_world()
	if world == null or world.is_disposed() or not world.is_entity_alive(entity_id) or not is_instance_valid(node):
		return false
	unbind(entity_id)
	var instance_id := node.get_instance_id()
	if _node_to_entity.has(instance_id):
		unbind(int(_node_to_entity[instance_id]))
	_entity_to_node[entity_id] = weakref(node)
	_entity_to_instance[entity_id] = instance_id
	_entity_to_uid[entity_id] = world.get_entity_uid(entity_id)
	_node_to_entity[instance_id] = entity_id
	return true


## Removes both directions safely even after the bound node has been freed.
func unbind(entity_id: int) -> void:
	if _entity_to_instance.has(entity_id):
		_node_to_entity.erase(_entity_to_instance[entity_id])
	_entity_to_instance.erase(entity_id)
	_entity_to_uid.erase(entity_id)
	_entity_to_node.erase(entity_id)


func get_node(entity_id: int) -> Node3D:
	var world := _get_world()
	if world == null or world.is_disposed():
		clear()
		return null
	if not world.is_entity_alive(entity_id):
		unbind(entity_id)
		return null
	var node_ref: WeakRef = _entity_to_node.get(entity_id)
	var node: Node3D = node_ref.get_ref() as Node3D if node_ref != null else null
	if node == null:
		unbind(entity_id)
	return node


func get_entity(node: Node3D) -> int:
	if not is_instance_valid(node):
		return -1
	var entity_id := int(_node_to_entity.get(node.get_instance_id(), -1))
	if entity_id != -1 and get_node(entity_id) == node:
		return entity_id
	return -1


## Clears mappings without destroying entities or scene nodes.
func clear() -> void:
	_entity_to_node.clear()
	_entity_to_instance.clear()
	_entity_to_uid.clear()
	_node_to_entity.clear()


func _get_world() -> EcsWorld:
	return _world_ref.get_ref() as EcsWorld if _world_ref != null else null


func _on_entity_destroyed(entity_id: int) -> void:
	unbind(entity_id)


func _on_world_disposed() -> void:
	attach_world(null)

func _on_world_restored(_id_map: Dictionary) -> void:
	var world := _get_world()
	if world == null:
		return
	var nodes := _entity_to_node.duplicate()
	var uids := _entity_to_uid.duplicate()
	clear()
	for old_entity: int in nodes:
		var node := (nodes[old_entity] as WeakRef).get_ref() as Node3D
		var entity := world.get_entity_by_uid(uids[old_entity])
		if node != null and entity > 0:
			bind(entity, node)
