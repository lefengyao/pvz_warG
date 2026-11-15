class_name EcsQuery
extends RefCounted

## Incremental membership; snapshots held by nested iterations remain stable.
var _world_reference: WeakRef
var _all: Array[StringName]
var _any: Array[StringName]
var _none: Array[StringName]
var _watched_types: Array[StringName] = []
var _matched_entities: Array[int] = []
var _indices: Dictionary = {}
var _pending: Dictionary = {}
var _compiled: bool = false
var _active_traversals: int = 0
var refresh_count: int = 0
var candidate_checks: int = 0

func _init(world: EcsWorld, all: Array[StringName], any: Array[StringName], none: Array[StringName]) -> void:
	_world_reference = weakref(world)
	_all = all
	_any = any
	_none = none
	for types: Array[StringName] in [all, any, none]:
		for key in types:
			if not _watched_types.has(key):
				_watched_types.append(key)

func get_world() -> EcsWorld:
	var world := _world_reference.get_ref() as EcsWorld
	return world if world != null and not world.is_disposed() else null

func entities() -> Array[int]:
	var world := get_world()
	if world == null:
		return []
	_refresh_if_needed(world)
	if not world.has_pending_destructions():
		return _matched_entities.duplicate()
	var result: Array[int] = []
	for entity in _matched_entities:
		if world.is_entity_alive(entity) and not world.is_entity_pending_destroy(entity):
			result.append(entity)
	return result

func count() -> int:
	var world := get_world()
	if world == null:
		return 0
	_refresh_if_needed(world)
	return entities().size() if world.has_pending_destructions() else _matched_entities.size()

func for_each(callback: Callable) -> void:
	var world := get_world()
	if world == null or not callback.is_valid():
		return
	_refresh_if_needed(world)
	var snapshot := _matched_entities
	_active_traversals += 1
	world._begin_iteration()
	for entity in snapshot:
		if world.is_disposed():
			break
		if world.is_entity_alive(entity) and not world.is_entity_pending_destroy(entity):
			callback.call(entity)
	_active_traversals -= 1
	world._end_iteration()

## Copies aligned component columns for isolated compute work.
func batches(chunk_size: int = 256) -> Array[Dictionary]:
	var world := get_world()
	if world == null:
		return []
	var result := world.storage.export_batches(_all, _any, _none, chunk_size)
	if not world.has_pending_destructions():
		return result
	var filtered: Array[Dictionary] = []
	for batch: Dictionary in result:
		var ids: Array[int] = []
		var columns: Dictionary = {}
		for key: StringName in batch.columns:
			columns[key] = []
		for row in batch.entities.size():
			if world.is_entity_pending_destroy(batch.entities[row]):
				continue
			ids.append(batch.entities[row])
			for key: StringName in columns:
				columns[key].append(batch.columns[key][row])
		if not ids.is_empty():
			filtered.append({"entities": ids, "columns": columns})
	return filtered

func _notify_membership(entity: int) -> void:
	if _compiled:
		_pending[entity] = true

func _invalidate() -> void:
	_compiled = false
	_pending.clear()

func _refresh_if_needed(world: EcsWorld) -> void:
	if not _compiled:
		_matched_entities = []
		_indices = {}
		for entity in world._driver_entities_for(_all, _any):
			candidate_checks += 1
			if world._matches_query(entity, _all, _any, _none):
				_indices[entity] = _matched_entities.size()
				_matched_entities.append(entity)
		_compiled = true
		_pending.clear()
		refresh_count += 1
		return
	if _pending.is_empty():
		return
	if _active_traversals > 0:
		_matched_entities = _matched_entities.duplicate()
		_indices = _indices.duplicate()
	for entity: int in _pending:
		candidate_checks += 1
		var matches := world._matches_query(entity, _all, _any, _none)
		if matches and not _indices.has(entity):
			_indices[entity] = _matched_entities.size()
			_matched_entities.append(entity)
		elif not matches and _indices.has(entity):
			var index: int = _indices[entity]
			var last := _matched_entities.back()
			_matched_entities[index] = last
			_indices[last] = index
			_matched_entities.pop_back()
			_indices.erase(entity)
	_pending.clear()
	refresh_count += 1
