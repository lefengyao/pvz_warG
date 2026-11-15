class_name EcsDataCopy
extends RefCounted

## Value data may contain nested containers and Resources, never live Objects.
static func is_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value is Array:
		for item: Variant in value:
			if not is_data(item, depth + 1):
				return false
	elif value is Dictionary:
		for key: Variant in value:
			if not is_data(key, depth + 1) or not is_data(value[key], depth + 1):
				return false
	elif value is Object:
		return value is Resource and is_instance_valid(value)
	elif typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return false
	return true

static func copy(value: Variant) -> Variant:
	if value is Array:
		var result: Array = value.duplicate()
		for index in range(result.size()):
			result[index] = copy(value[index])
		return result
	if value is Dictionary:
		var result: Dictionary = value.duplicate()
		result.clear()
		for key: Variant in value:
			result[copy(key)] = copy(value[key])
		return result
	if value is Resource:
		return value.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	if value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray or value is PackedVector2Array or value is PackedVector3Array or value is PackedColorArray or value is PackedVector4Array:
		return value.duplicate()
	return value

static func is_group_key(value: Variant, depth: int = 0) -> bool:
	if depth > 64 or value is Object or typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return false
	if value is Array:
		for item: Variant in value:
			if not is_group_key(item, depth + 1):
				return false
	if value is Dictionary:
		for key: Variant in value:
			if not is_group_key(key, depth + 1) or not is_group_key(value[key], depth + 1):
				return false
	return true
