class_name EcsSparseStorage
extends EcsStorage

## Each component has dense entity/value arrays and an entity -> row sparse index.
## Swap removal is O(1); values are not stored in per-entity dictionaries.
class DenseColumn extends RefCounted:
	var entities: Array[int] = []
	var values: Array = []
	var rows: Dictionary = {}

var _entities: Dictionary = {}
var _columns: Dictionary = {}

func _init() -> void:
	backend_name = &"sparse"

func create_entity(id: int) -> bool:
	if _entities.has(id):
		return false
	_entities[id] = {}
	return true

func destroy_entity(id: int) -> bool:
	if not _entities.has(id):
		return false
	for key: StringName in _entities[id].keys():
		remove(id, key)
	_entities.erase(id)
	return true

func add(id: int, key: StringName, value: Variant = null) -> bool:
	if not _entities.has(id) or key.is_empty() or _entities[id].has(key):
		return false
	var column: DenseColumn = _columns.get(key)
	if column == null:
		column = DenseColumn.new()
		_columns[key] = column
	column.rows[id] = column.entities.size()
	column.entities.append(id)
	column.values.append(value)
	_entities[id][key] = true
	return true

func remove(id: int, key: StringName) -> bool:
	var column: DenseColumn = _columns.get(key)
	if column == null or not column.rows.has(id):
		return false
	var row: int = column.rows[id]
	var last_row := column.entities.size() - 1
	if row != last_row:
		var moved_id: int = column.entities[last_row]
		column.entities[row] = moved_id
		column.values[row] = column.values[last_row]
		column.rows[moved_id] = row
	column.entities.pop_back()
	column.values.pop_back()
	column.rows.erase(id)
	_entities[id].erase(key)
	if column.entities.is_empty():
		_columns.erase(key)
	return true

func has(id: int, key: StringName) -> bool:
	var column: DenseColumn = _columns.get(key)
	return column != null and column.rows.has(id)

func get_value(id: int, key: StringName, default_value: Variant = null) -> Variant:
	var column: DenseColumn = _columns.get(key)
	return default_value if column == null or not column.rows.has(id) else column.values[column.rows[id]]

func set_value(id: int, key: StringName, value: Variant) -> bool:
	var column: DenseColumn = _columns.get(key)
	if column == null or not column.rows.has(id):
		return false
	column.values[column.rows[id]] = value
	return true

func set_values_unchecked(key: StringName, entities: Variant, values: Variant) -> void:
	if entities.is_empty():
		return
	var column: DenseColumn = _columns[key]
	var column_values := column.values
	var rows := column.rows
	for row in range(entities.size()):
		column_values[rows[entities[row]]] = values[row]

func component_types() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_columns.keys())
	result.sort_custom(_key_less)
	return result

func component_count(key: StringName) -> int:
	var column: DenseColumn = _columns.get(key)
	return 0 if column == null else column.entities.size()

func entities_for(key: StringName) -> Array[int]:
	var column: DenseColumn = _columns.get(key)
	var result: Array[int] = []
	if column != null:
		result = column.entities.duplicate()
	return result

func entity_components(id: int) -> Dictionary:
	var result: Dictionary = {}
	if _entities.has(id):
		for key: StringName in _entities[id]:
			result[key] = _copy_value(get_value(id, key))
	return result

func keys_for(id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if _entities.has(id):
		result.assign(_entities[id].keys())
		result.sort_custom(_key_less)
	return result

func _candidates(all: Array[StringName], any: Array[StringName]) -> Array[int]:
	if not all.is_empty():
		var smallest: DenseColumn
		for key in all:
			var column: DenseColumn = _columns.get(key)
			if column == null:
				return []
			if smallest == null or column.entities.size() < smallest.entities.size():
				smallest = column
		return smallest.entities
	var result: Array[int] = []
	if any.is_empty():
		result.assign(_entities.keys())
		return result
	var visited: Dictionary = {}
	for key in any:
		var column: DenseColumn = _columns.get(key)
		if column != null:
			for id in column.entities:
				if not visited.has(id):
					visited[id] = true
					result.append(id)
	return result

func export_batches(all: Array[StringName], any: Array[StringName], none: Array[StringName], chunk_size: int = 256) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if chunk_size <= 0:
		return result
	var ids: Array[int] = []
	var columns: Dictionary = {}
	var selected_columns: Array[DenseColumn] = []
	var selected_types: Array[StringName] = []
	for key in all:
		if columns.has(key):
			continue
		var source: DenseColumn = _columns.get(key)
		if source == null:
			return result
		columns[key] = []
		selected_types.append(key)
		selected_columns.append(source)
	for id in _candidates(all, any):
		if not _matches_types(_entities[id], all, any, none):
			continue
		ids.append(id)
		for index in range(selected_types.size()):
			var source := selected_columns[index]
			columns[selected_types[index]].append(source.values[source.rows[id]])
		if ids.size() == chunk_size:
			result.append({"entities": ids, "columns": columns.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)})
			ids = []
			columns = {}
			for key in selected_types:
				columns[key] = []
	if not ids.is_empty():
		result.append({"entities": ids, "columns": columns.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)})
	return result

func clear() -> void:
	_entities.clear()
	_columns.clear()

func diagnostics() -> Dictionary:
	var value_count := 0
	for column: DenseColumn in _columns.values():
		value_count += column.values.size()
	return {"backend": backend_name, "entity_count": _entities.size(), "component_count": _columns.size(), "value_count": value_count, "table_count": _columns.size(), "chunk_count": 0, "chunk_capacity": 0}
