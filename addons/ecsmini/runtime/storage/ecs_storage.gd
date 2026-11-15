@abstract
class_name EcsStorage
extends RefCounted

## Main-thread storage contract. IDs are opaque keys supplied by EcsWorld.
## Batch exports own their mutable Variant containers; Object identity is retained.
var backend_name: StringName = &""
var _world_instance_id: int = 0

@abstract func create_entity(id: int) -> bool
@abstract func destroy_entity(id: int) -> bool
@abstract func add(id: int, key: StringName, value: Variant = null) -> bool
@abstract func remove(id: int, key: StringName) -> bool
@abstract func has(id: int, key: StringName) -> bool
@abstract func get_value(id: int, key: StringName, default_value: Variant = null) -> Variant
@abstract func set_value(id: int, key: StringName, value: Variant) -> bool
@abstract func component_types() -> Array[StringName]
@abstract func component_count(key: StringName) -> int
@abstract func entities_for(key: StringName) -> Array[int]
@abstract func entity_components(id: int) -> Dictionary
@abstract func export_batches(all: Array[StringName], any: Array[StringName], none: Array[StringName], chunk_size: int = 256) -> Array[Dictionary]
@abstract func clear() -> void
@abstract func diagnostics() -> Dictionary

## Read only membership when callers do not need a deep value snapshot.
func keys_for(id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for key in component_types():
		if has(id, key):
			result.append(key)
	return result

## Internal main-thread fast path. EcsWorld must prevalidate IDs, membership,
## array alignment and schemas before entering this method.
func set_values_unchecked(key: StringName, entities: Variant, values: Variant) -> void:
	for row in range(entities.size()):
		set_value(entities[row], key, values[row])

static func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	if value is Resource:
		return value.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return value.duplicate()
	return value

static func _key_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)

static func _matches_types(types: Dictionary, all: Array[StringName], any: Array[StringName], none: Array[StringName]) -> bool:
	for key in all:
		if not types.has(key):
			return false
	if not any.is_empty():
		var matched := false
		for key in any:
			if types.has(key):
				matched = true
				break
		if not matched:
			return false
	for key in none:
		if types.has(key):
			return false
	return true
