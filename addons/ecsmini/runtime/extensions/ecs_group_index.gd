class_name EcsGroupIndex
extends EcsIndexBase

var _groups: Dictionary = {}
var _entity_values: Dictionary = {}

func _init(world: EcsWorld = null, key: StringName = &"group") -> void:
	if world != null:
		attach(world, key)

func entities(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if EcsDataCopy.is_group_key(value) and _groups.has(value):
		for entity: int in _groups[value]:
			if _valid(entity):
				result.append(entity)
	result.sort()
	return result

func values() -> Array:
	var result: Array = []
	for value: Variant in _groups:
		if not entities(value).is_empty():
			result.append(EcsDataCopy.copy(value))
	return result

func _reindex_entity(entity: int) -> void:
	_erase_entity(entity)
	var world := _world()
	if not _valid(entity) or not world.has_component(entity, component_key):
		return
	var value: Variant = world.get_component(entity, component_key)
	if not EcsDataCopy.is_group_key(value):
		return
	var copied_value: Variant = EcsDataCopy.copy(value)
	_entity_values[entity] = copied_value
	if not _groups.has(copied_value):
		_groups[copied_value] = {}
	_groups[copied_value][entity] = true

func _erase_entity(entity: int) -> void:
	if not _entity_values.has(entity):
		return
	var value: Variant = _entity_values[entity]
	_groups[value].erase(entity)
	if _groups[value].is_empty():
		_groups.erase(value)
	_entity_values.erase(entity)

func _clear_index() -> void:
	_groups.clear()
	_entity_values.clear()
