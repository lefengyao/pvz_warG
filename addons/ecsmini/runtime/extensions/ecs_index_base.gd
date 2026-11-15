class_name EcsIndexBase
extends RefCounted

## Signal callbacks retain the index, while the index only weakly references its
## world. Call detach to stop updates before world disposal when no longer needed.
var component_key: StringName = &""
var _world_ref: WeakRef

func attach(world: EcsWorld, key: StringName) -> bool:
	if world == null or world.is_disposed() or key.is_empty():
		return false
	detach()
	component_key = key
	_world_ref = weakref(world)
	world.entity_destroyed.connect(_erase_entity)
	world.cleared.connect(_clear_index)
	world.disposed.connect(detach)
	if world.has_signal("mutation_committed"):
		world.connect("mutation_committed", _on_mutation)
	if world.has_signal("restored"):
		world.connect("restored", _on_restored)
	reindex()
	return true

func detach() -> void:
	var world := _world()
	if world != null:
		for connection: Array in [[&"entity_destroyed", _erase_entity], [&"cleared", _clear_index], [&"disposed", detach], [&"mutation_committed", _on_mutation], [&"restored", _on_restored]]:
			if world.has_signal(connection[0]) and world.is_connected(connection[0], connection[1]):
				world.disconnect(connection[0], connection[1])
	_world_ref = null
	_clear_index()

func reindex() -> void:
	_clear_index()
	var world := _world()
	if world != null:
		for entity in world.get_entities():
			_reindex_entity(entity)

func _on_mutation(record: Dictionary) -> void:
	if record.get("key", &"") == component_key:
		_reindex_entity(record.entity)
	elif record.op == &"destroy":
		_erase_entity(record.entity)

func _on_restored(_id_map: Dictionary) -> void:
	reindex()

func _world() -> EcsWorld:
	return null if _world_ref == null else _world_ref.get_ref() as EcsWorld

func _valid(entity: int) -> bool:
	var world := _world()
	return world != null and world.is_entity_alive(entity) and not world.is_entity_pending_destroy(entity)

func _reindex_entity(_entity: int) -> void:
	pass

func _erase_entity(_entity: int) -> void:
	pass

func _clear_index() -> void:
	pass
