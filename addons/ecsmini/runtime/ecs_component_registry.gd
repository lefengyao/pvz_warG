class_name EcsComponentRegistry
extends RefCounted

## Optional schemas. -1 accepts any Variant type; TYPE_NIL defines a tag.
var _definitions: Dictionary = {}
var last_error := ""

func register_component(type_key: StringName, variant_type: int = -1, validator: Callable = Callable()) -> bool:
	if type_key.is_empty() or _definitions.has(type_key) or variant_type < -1 or variant_type >= TYPE_MAX:
		return false
	_definitions[type_key] = {"type": variant_type, "validator": validator}
	return true

func unregister_component(type_key: StringName) -> bool:
	return _definitions.erase(type_key)

func has_component(type_key: StringName) -> bool:
	return _definitions.has(type_key)

func validate(type_key: StringName, value: Variant, require_registered: bool = false) -> bool:
	last_error = ""
	if not _definitions.has(type_key):
		if require_registered:
			last_error = "Component is not registered: %s" % type_key
		return not require_registered
	var definition: Dictionary = _definitions[type_key]
	var expected_type: int = definition["type"]
	if expected_type >= 0 and typeof(value) != expected_type:
		last_error = "Component %s expects %s, received %s" % [type_key, type_string(expected_type), type_string(typeof(value))]
		return false
	var validator: Callable = definition["validator"]
	if validator.is_valid():
		var result: Variant = validator.call(value)
		if result is not bool or not result:
			last_error = "Component validator rejected: %s" % type_key
			return false
	return true

func clear() -> void:
	_definitions.clear()
	last_error = ""

func definitions() -> Dictionary:
	var result: Dictionary = {}
	for type_key: StringName in _definitions:
		result[type_key] = _definitions[type_key]["type"]
	return result
