class_name EcsArchetypeStorage
extends EcsStorage

## Entities with the exact same component signature share columnar bounded chunks.
## Structural changes migrate rows, and swap removal keeps chunks densely packed.
class StorageChunk extends RefCounted:
	var entities: Array[int] = []
	var columns: Dictionary = {}

class ArchetypeTable extends RefCounted:
	var signature: String
	var types: Array[StringName] = []
	var membership: Dictionary = {}
	var chunks: Array[StorageChunk] = []

var chunk_capacity: int = 256
var _tables: Dictionary = {}
var _locations: Dictionary = {}
var _component_counts: Dictionary = {}

func _init(capacity: int = 256) -> void:
	backend_name = &"archetype"
	chunk_capacity = maxi(1, capacity)

func create_entity(id: int) -> bool:
	if _locations.has(id):
		return false
	_insert_row(id, {})
	return true

func destroy_entity(id: int) -> bool:
	if not _locations.has(id):
		return false
	var table: ArchetypeTable = _locations[id]["table"]
	for key in table.types:
		_decrement_component(key)
	_remove_row(id)
	return true

func add(id: int, key: StringName, value: Variant = null) -> bool:
	if not _locations.has(id) or key.is_empty() or has(id, key):
		return false
	var values := _read_components(id)
	values[key] = value
	_remove_row(id)
	_insert_row(id, values)
	_component_counts[key] = component_count(key) + 1
	return true

func remove(id: int, key: StringName) -> bool:
	if not has(id, key):
		return false
	var values := _read_components(id)
	values.erase(key)
	_remove_row(id)
	_insert_row(id, values)
	_decrement_component(key)
	return true

func has(id: int, key: StringName) -> bool:
	if not _locations.has(id):
		return false
	var table: ArchetypeTable = _locations[id]["table"]
	return table.membership.has(key)

func get_value(id: int, key: StringName, default_value: Variant = null) -> Variant:
	if not has(id, key):
		return default_value
	var location: Dictionary = _locations[id]
	var chunk: StorageChunk = location["chunk"]
	return chunk.columns[key][location["row"]]

func set_value(id: int, key: StringName, value: Variant) -> bool:
	if not has(id, key):
		return false
	var location: Dictionary = _locations[id]
	var chunk: StorageChunk = location["chunk"]
	chunk.columns[key][location["row"]] = value
	return true

func set_values_unchecked(key: StringName, entities: Variant, values: Variant) -> void:
	for row in range(entities.size()):
		var location: Dictionary = _locations[entities[row]]
		var chunk: StorageChunk = location["chunk"]
		chunk.columns[key][location["row"]] = values[row]

func component_types() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_component_counts.keys())
	result.sort_custom(_key_less)
	return result

func component_count(key: StringName) -> int:
	return int(_component_counts.get(key, 0))

func entities_for(key: StringName) -> Array[int]:
	var result: Array[int] = []
	for table: ArchetypeTable in _tables.values():
		if table.membership.has(key):
			for chunk in table.chunks:
				result.append_array(chunk.entities)
	return result

func entity_components(id: int) -> Dictionary:
	var result := _read_components(id)
	for key: StringName in result:
		result[key] = _copy_value(result[key])
	return result

func keys_for(id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if _locations.has(id):
		var table: ArchetypeTable = _locations[id]["table"]
		result = table.types.duplicate()
	return result

func _read_components(id: int) -> Dictionary:
	var result: Dictionary = {}
	if _locations.has(id):
		var location: Dictionary = _locations[id]
		var table: ArchetypeTable = location["table"]
		var chunk: StorageChunk = location["chunk"]
		for key in table.types:
			result[key] = chunk.columns[key][location["row"]]
	return result

func _signature(types: Array[StringName]) -> String:
	var signature := "%d:" % types.size()
	for key in types:
		signature += "%d:%s" % [String(key).length(), key]
	return signature

func _insert_row(id: int, values: Dictionary) -> void:
	var types: Array[StringName] = []
	types.assign(values.keys())
	types.sort_custom(_key_less)
	var signature := _signature(types)
	var table: ArchetypeTable = _tables.get(signature)
	if table == null:
		table = ArchetypeTable.new()
		table.signature = signature
		table.types = types
		for key in types:
			table.membership[key] = true
		_tables[signature] = table
	var chunk: StorageChunk
	if table.chunks.is_empty() or table.chunks.back().entities.size() >= chunk_capacity:
		chunk = StorageChunk.new()
		for key in types:
			chunk.columns[key] = []
		table.chunks.append(chunk)
	else:
		chunk = table.chunks.back()
	_locations[id] = {"table": table, "chunk": chunk, "row": chunk.entities.size()}
	chunk.entities.append(id)
	for key in types:
		chunk.columns[key].append(values[key])

func _remove_row(id: int) -> void:
	var location: Dictionary = _locations[id]
	var table: ArchetypeTable = location["table"]
	var chunk: StorageChunk = location["chunk"]
	var row: int = location["row"]
	var last_chunk: StorageChunk = table.chunks.back()
	var last_row := last_chunk.entities.size() - 1
	var moved_id: int = last_chunk.entities[last_row]
	if moved_id != id:
		chunk.entities[row] = moved_id
		for key in table.types:
			chunk.columns[key][row] = last_chunk.columns[key][last_row]
		_locations[moved_id] = {"table": table, "chunk": chunk, "row": row}
	last_chunk.entities.pop_back()
	for key in table.types:
		last_chunk.columns[key].pop_back()
	if last_chunk.entities.is_empty():
		table.chunks.pop_back()
	if table.chunks.is_empty():
		_tables.erase(table.signature)
	_locations.erase(id)

func _decrement_component(key: StringName) -> void:
	var count := component_count(key) - 1
	if count == 0:
		_component_counts.erase(key)
	else:
		_component_counts[key] = count

func export_batches(all: Array[StringName], any: Array[StringName], none: Array[StringName], chunk_size: int = 256) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if chunk_size <= 0:
		return result
	for table: ArchetypeTable in _tables.values():
		if not _matches_types(table.membership, all, any, none):
			continue
		for chunk in table.chunks:
			for first_row in range(0, chunk.entities.size(), chunk_size):
				var last_row := mini(first_row + chunk_size, chunk.entities.size())
				var ids: Array[int] = chunk.entities.slice(first_row, last_row)
				var columns: Dictionary = {}
				for key in all:
					columns[key] = chunk.columns[key].slice(first_row, last_row)
				result.append({"entities": ids, "columns": columns.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)})
	return result

func clear() -> void:
	_tables.clear()
	_locations.clear()
	_component_counts.clear()

func diagnostics() -> Dictionary:
	var chunk_count := 0
	for table: ArchetypeTable in _tables.values():
		chunk_count += table.chunks.size()
	var value_count := 0
	for count: int in _component_counts.values():
		value_count += count
	return {"backend": backend_name, "entity_count": _locations.size(), "component_count": _component_counts.size(), "value_count": value_count, "table_count": _tables.size(), "chunk_count": chunk_count, "chunk_capacity": chunk_capacity}
