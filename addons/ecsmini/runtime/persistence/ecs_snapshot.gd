class_name EcsSnapshot
extends RefCounted

const VERSION := 1
const CODEC = preload("res://addons/ecsmini/runtime/persistence/ecs_variant_codec.gd")
const RELATIONS_PATH := "res://addons/ecsmini/runtime/extensions/ecs_relations.gd"
const EVENTS_PATH := "res://addons/ecsmini/runtime/extensions/ecs_event_queue.gd"

static func capture(world: EcsWorld) -> Dictionary:
	if world == null or world.is_disposed():
		return _error("World is unavailable.")
	if not world.is_at_safe_boundary():
		return _error("Capture requires committed state outside mutation barriers.")
	var entities: Array = []
	for entity: int in world.get_entities():
		var components: Dictionary = {}
		for key: StringName in world.storage.keys_for(entity):
			components[key] = world.get_component(entity, key)
		entities.append({"id": entity, "uid": world.get_entity_uid(entity), "components": components})
	entities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.uid < b.uid)
	var snapshot := {"version": VERSION, "entities": entities, "reference_keys": world.get_reference_components(),
		"metadata": world.export_metadata(), "relations": world.get_relations().capture(), "events": world.get_events().capture()}
	return validate(snapshot, world)

static func validate(snapshot: Variant, world: EcsWorld = null) -> Dictionary:
	var copied := CODEC.copy(snapshot)
	if not copied.ok:
		return _error(copied.error)
	if copied.value is not Dictionary:
		return _error("Snapshot must be a dictionary.")
	var data: Dictionary = copied.value
	if data.size() != 6 or data.get("version") is not int or data.version != VERSION:
		return _error("Unknown or malformed snapshot schema version.")
	if data.get("entities") is not Array or data.get("reference_keys") is not Array or data.get("metadata") is not Dictionary or data.get("relations") is not Dictionary or data.get("events") is not Dictionary:
		return _error("Malformed snapshot sections.")
	var references: Array[StringName] = []
	for key: Variant in data.reference_keys:
		if key is not StringName or key.is_empty() or references.has(key):
			return _error("Malformed reference component schema.")
		references.append(key)
	references.sort()
	data.reference_keys = references
	if world != null:
		if world.is_disposed():
			return _error("World is disposed.")
		var registered: Array[StringName] = world.get_reference_components()
		registered.sort()
		if registered != references:
			return _error("Reference schema differs from application's registered schema.")
	var ids: Dictionary = {}
	var uids: Array[int] = []
	var maximum_uid := 0
	for entity: Variant in data.entities:
		if entity is not Dictionary or entity.size() != 3 or entity.get("id") is not int or entity.get("uid") is not int or entity.get("components") is not Dictionary:
			return _error("Malformed entity record.")
		if entity.id <= 0 or entity.uid <= 0 or ids.has(entity.id) or uids.has(entity.uid):
			return _error("Duplicate or invalid entity handle/UID.")
		ids[entity.id] = entity.uid
		uids.append(entity.uid)
		maximum_uid = maxi(maximum_uid, entity.uid)
		for key: Variant in entity.components:
			if key is not StringName or key.is_empty():
				return _error("Component keys must be nonempty StringNames.")
			if world != null and not world._validate_component_schema(key, entity.components[key]):
				return _error(world.last_validation_error)
	for entity: Dictionary in data.entities:
		for key: StringName in references:
			if entity.components.has(key) and not _valid_reference(entity.components[key], ids):
				return _error("Invalid entity reference in component: " + String(key))
	if not _valid_metadata(data.metadata, maximum_uid):
		return _error("Malformed simulation/RNG metadata.")
	if not ResourceLoader.exists(RELATIONS_PATH) or not ResourceLoader.exists(EVENTS_PATH):
		return _error("Persistence extension modules are unavailable.")
	var relations: Script = load(RELATIONS_PATH)
	var events: Script = load(EVENTS_PATH)
	if not relations.validate_snapshot(data.relations, uids) or not events.validate_snapshot(data.events):
		return _error("Malformed relation or event snapshot.")
	if uids.is_empty() and not data.relations.links.is_empty():
		return _error("Relations reference entities missing from an empty snapshot.")
	return {"ok": true, "error": "", "snapshot": data}

static func restore(world: EcsWorld, snapshot: Variant) -> Dictionary:
	if world == null:
		return _error("World is unavailable.")
	var checked := validate(snapshot, world)
	if not checked.ok:
		return checked
	var data: Dictionary = checked.snapshot
	if not world.begin_restore():
		return _error("World cannot restore while ticking, iterating, closing or holding pending commands.")
	var id_map: Dictionary = {}
	var validation_was_enabled := world.validation_enabled
	world.validation_enabled = false
	for entity: Dictionary in data.entities:
		id_map[entity.id] = world.create_entity(entity.uid)
	for entity: Dictionary in data.entities:
		for key: StringName in entity.components:
			var value: Variant = entity.components[key]
			if data.reference_keys.has(key):
				value = _remap_reference(value, id_map)
			world.add_component(id_map[entity.id], key, value)
	world.validation_enabled = validation_was_enabled
	world.restore_metadata(data.metadata)
	world.get_relations().restore(data.relations, id_map)
	world.get_events().restore(data.events)
	world.end_restore(id_map)
	return {"ok": true, "error": "", "id_map": id_map}

## Handle-independent digest for controlled replay on one engine/platform.
static func digest(world: EcsWorld) -> Dictionary:
	var captured := capture(world)
	if not captured.ok:
		return captured
	var data: Dictionary = captured.snapshot
	var handle_uids: Dictionary = {}
	for entity: Dictionary in data.entities:
		handle_uids[entity.id] = entity.uid
	for entity: Dictionary in data.entities:
		entity.erase("id")
		for key: StringName in data.reference_keys:
			if entity.components.has(key):
				entity.components[key] = _remap_reference(entity.components[key], handle_uids)
	# Reader reset epochs describe external observation, rather than simulation state.
	data.events.erase("reset_epoch")
	data.events.erase("readers")
	var encoded := CODEC.encode(data)
	return {"ok": true, "error": "", "digest": JSON.stringify(encoded.value).sha256_text()}

static func _valid_reference(value: Variant, ids: Dictionary) -> bool:
	if value is int:
		return value <= 0 or ids.has(value)
	if value is Array:
		for item: Variant in value:
			if item is not int or (item > 0 and not ids.has(item)):
				return false
		return true
	return false

static func _remap_reference(value: Variant, ids: Dictionary) -> Variant:
	if value is int:
		return ids.get(value, value)
	var result: Array[int] = []
	for item: int in value:
		result.append(ids.get(item, item))
	return result

static func _valid_metadata(data: Dictionary, maximum_uid: int) -> bool:
	if data.size() != 5:
		return false
	for key in ["next_uid", "simulation_tick", "rng_seed", "rng_state"]:
		if data.get(key) is not int:
			return false
	return data.get("simulation_time") is float and is_finite(data.simulation_time) and data.simulation_time >= 0.0 and data.simulation_tick >= 0 and data.next_uid > maximum_uid

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "snapshot": {}, "id_map": {}}
