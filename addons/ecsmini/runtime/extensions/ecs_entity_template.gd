class_name EcsEntityTemplate
extends Resource

@export var base_template: EcsEntityTemplate
@export var components: Dictionary = {}
var last_error: String = ""

## Derived component values replace base values; overrides replace derived values.
func resolve(overrides: Dictionary = {}) -> Dictionary:
	last_error = ""
	var chain: Array[EcsEntityTemplate] = []
	var current: EcsEntityTemplate = self
	while current != null:
		if chain.has(current):
			last_error = "Template inheritance contains a cycle"
			return {}
		chain.append(current)
		current = current.base_template
	var result: Dictionary = {}
	for index in range(chain.size() - 1, -1, -1):
		if not _merge_values(result, chain[index].components):
			return {}
	if not _merge_values(result, overrides):
		return {}
	return result

func spawn(world: EcsWorld, overrides: Dictionary = {}) -> int:
	var resolved := resolve(overrides)
	if not last_error.is_empty() or not _validate(world, resolved):
		return -1
	return _spawn_resolved(world, resolved)

## All overrides are validated before creating any entity. Unexpected write
## rejection destroys every newly-created entity (at the current commit boundary).
func spawn_many(world: EcsWorld, count: int, per_instance_overrides: Array = []) -> Array[int]:
	last_error = ""
	if count < 0 or (not per_instance_overrides.is_empty() and per_instance_overrides.size() != count):
		last_error = "Batch count and overrides do not match"
		return []
	var resolved: Array[Dictionary] = []
	for index in range(count):
		var overrides: Variant = {} if per_instance_overrides.is_empty() else per_instance_overrides[index]
		if overrides is not Dictionary:
			last_error = "Each batch override must be a Dictionary"
			return []
		var values := resolve(overrides)
		if not last_error.is_empty() or not _validate(world, values):
			return []
		resolved.append(values)
	var entities: Array[int] = []
	for values in resolved:
		var entity := _spawn_resolved(world, values)
		if entity < 0:
			for created in entities:
				world.destroy_entity(created)
			return []
		entities.append(entity)
	return entities

func _merge_values(target: Dictionary, values: Dictionary) -> bool:
	for key: Variant in values:
		if (key is not String and key is not StringName) or String(key).is_empty():
			last_error = "Component keys must be nonempty strings"
			return false
		if not EcsDataCopy.is_data(values[key]):
			last_error = "Component values must be copyable data"
			return false
		target[StringName(key)] = EcsDataCopy.copy(values[key])
	return true

func _validate(world: EcsWorld, values: Dictionary) -> bool:
	if world == null or world.is_disposed():
		last_error = "A live world is required"
		return false
	if world.validation_enabled:
		for key: StringName in values:
			if not world._validate_component(-1, key, values[key]):
				last_error = world.last_validation_error
				return false
	return true

func _spawn_resolved(world: EcsWorld, values: Dictionary) -> int:
	var entity := world.create_entity()
	if entity < 0:
		last_error = "World rejected entity creation"
		return -1
	for key: StringName in values:
		if not world.add_component(entity, key, values[key]):
			last_error = "World rejected component: %s" % key
			world.destroy_entity(entity)
			return -1
	return entity
