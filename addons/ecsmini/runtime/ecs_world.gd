class_name EcsWorld
extends RefCounted

## World-local generation IDs, committed reads, and FIFO deferred structural writes.
const _SLOT_MASK: int = 0xffffffff
signal entity_destroyed(entity_id: int)
signal cleared
signal disposed
signal validation_failed(entity_id: int, type_key: StringName, message: String)
signal mutation_committed(record: Dictionary)
signal restored(id_map: Dictionary)

var validation_enabled: bool = false
var require_registered_components: bool = false
var profiling_enabled: bool = false
var last_validation_error: String = ""
var component_registry := EcsComponentRegistry.new()
var storage: EcsStorage = EcsSparseStorage.new()
var rng := RandomNumberGenerator.new()
var simulation_tick: int = 0
var simulation_time: float = 0.0
var is_replaying: bool = false
var last_schedule_error: String = ""
var trace_enabled: bool = false
var change_tracking_enabled: bool = false
var trace_capacity: int = 256:
	set(value):
		trace_capacity = maxi(1, value)
		_trace.capacity = trace_capacity
var change_capacity: int = 1024:
	set(value):
		change_capacity = maxi(1, value)
		_journal.capacity = change_capacity
var _journal := EcsChangeJournal.new()
var _trace := EcsChangeJournal.new()
var _scheduler := EcsScheduler.new()
var _relations: EcsRelations
var _events: EcsEventQueue
var _reference_components: Array[StringName] = []
var _entity_uids: Dictionary = {}
var _uid_entities: Dictionary = {}
var _next_uid: int = 1
var _restoring: bool = false
var _current_system: StringName = &""
var _owner_thread: int = OS.get_thread_caller_id()
var _validation_depth: int = 0
var _mutation_sequence: int = 0

var _generations: Array[int] = [0]
var _alive_slots: Array[bool] = [false]
var _alive_entities: Array[int] = []
var _alive_indices: Dictionary = {}
var _free_slots: Array[int] = []
var _queries: Dictionary = {}
var _queries_by_type: Dictionary = {}
var _entity_queries: Array[EcsQuery] = []
var _topology_version: int = 0
var _entity_version: int = 0
var _component_versions: Dictionary = {}
var _systems: Array[EcsSystem] = []
var _system_order: Dictionary = {}
var _started_systems: Dictionary = {}
var _detaching_systems: Dictionary = {}
var _schedule: Array[EcsSystem] = []
var _schedule_orders: Array[int] = []
var _schedule_dirty: bool = true
var _next_system_order: int = 0
var _started: bool = false
var _starting: bool = false
var _stopping: bool = false
var _is_ticking: bool = false
var _iteration_depth: int = 0
var _commands: Array[Dictionary] = []
var _pending_membership: Dictionary = {}
var _pending_destroy: Dictionary = {}
var _is_flushing: bool = false
var _lifecycle_busy: bool = false
var _emitting_cleared: bool = false
var _clear_requested: bool = false
var _dispose_requested: bool = false
var _stop_requested: bool = false
var _disposed: bool = false
var _last_tick_usec: int = 0
var _system_timings: Dictionary = {}

func _init() -> void:
	rng.seed = 1
	_trace.capacity = trace_capacity
	storage._world_instance_id = get_instance_id()

func create_entity(persistent_uid: int = 0) -> int:
	if not _accepts_mutations():
		return -1
	if persistent_uid < 0 or _uid_entities.has(persistent_uid):
		return -1
	var uid := persistent_uid if persistent_uid > 0 else _next_uid
	if uid == 9223372036854775807:
		return -1
	_next_uid = maxi(_next_uid, uid + 1)
	var slot: int
	if _free_slots.is_empty():
		slot = _generations.size()
		_generations.append(1)
		_alive_slots.append(false)
	else:
		slot = _free_slots.pop_back()
		_generations[slot] += 1
	_alive_slots[slot] = true
	var entity_id := (_generations[slot] << 32) | slot
	storage.create_entity(entity_id)
	_entity_uids[entity_id] = uid
	_uid_entities[uid] = entity_id
	_alive_indices[entity_id] = _alive_entities.size()
	_alive_entities.append(entity_id)
	_entity_version += 1
	_topology_version += 1
	_notify_entity_queries(entity_id)
	_record_mutation(&"create", entity_id)
	flush()
	return entity_id

func destroy_entity(entity_id: int) -> bool:
	if not _accepts_mutations() or not is_entity_alive(entity_id) or is_entity_pending_destroy(entity_id):
		return false
	if _relations != null and not _relations.can_destroy(entity_id):
		return false
	if _must_defer():
		_pending_destroy[entity_id] = true
		_commands.append({"op": &"destroy", "entity": entity_id, "system": _current_system})
		return true
	_begin_iteration()
	_pending_destroy[entity_id] = true
	var result := _destroy_entity_now(entity_id)
	_end_iteration()
	return result

func is_entity_alive(entity_id: int) -> bool:
	var slot := entity_id & _SLOT_MASK
	return not _disposed and slot > 0 and slot < _alive_slots.size() and _alive_slots[slot] and _generations[slot] == (entity_id >> 32)

func is_entity_pending_destroy(entity_id: int) -> bool:
	return _pending_destroy.has(entity_id)

func has_pending_destructions() -> bool:
	return not _pending_destroy.is_empty()

func entity_count() -> int:
	return _alive_entities.size()

func get_entities() -> Array[int]:
	if _pending_destroy.is_empty():
		return _alive_entities.duplicate()
	var result: Array[int] = []
	for entity_id in _alive_entities:
		if not _pending_destroy.has(entity_id):
			result.append(entity_id)
	return result

func add_component(entity_id: int, type_key: StringName, value: Variant = null) -> bool:
	if not _can_write_entity(entity_id) or type_key.is_empty() or _projected_has_component(entity_id, type_key):
		return false
	if not _validate_component(entity_id, type_key, value):
		return false
	if _must_defer():
		_set_pending_membership(entity_id, type_key, true)
		_commands.append({"op": &"add", "entity": entity_id, "type": type_key, "value": value, "system": _current_system})
		return true
	_begin_iteration()
	var result := _add_component_now(entity_id, type_key, value)
	_end_iteration()
	return result

func remove_component(entity_id: int, type_key: StringName) -> bool:
	if not _can_write_entity(entity_id) or not _projected_has_component(entity_id, type_key):
		return false
	if _must_defer():
		_set_pending_membership(entity_id, type_key, false)
		_commands.append({"op": &"remove", "entity": entity_id, "type": type_key, "system": _current_system})
		return true
	_begin_iteration()
	var result := _remove_component_now(entity_id, type_key)
	_end_iteration()
	return result

func has_component(entity_id: int, type_key: StringName) -> bool:
	if not is_entity_alive(entity_id):
		return false
	return storage.has(entity_id, type_key)

func get_component(entity_id: int, type_key: StringName, default_value: Variant = null) -> Variant:
	if not is_entity_alive(entity_id):
		return default_value
	return storage.get_value(entity_id, type_key, default_value)

func set_component(entity_id: int, type_key: StringName, value: Variant) -> bool:
	if not _can_write_entity(entity_id) or not _projected_has_component(entity_id, type_key):
		return false
	if not _validate_component(entity_id, type_key, value):
		return false
	if _pending_membership.has(entity_id) and _pending_membership[entity_id].has(type_key):
		_commands.append({"op": &"set", "entity": entity_id, "type": type_key, "value": value, "system": _current_system})
		return true
	_begin_iteration()
	var result := _set_component_now(entity_id, type_key, value)
	_end_iteration()
	return result

func register_component(type_key: StringName, variant_type: int = -1, validator: Callable = Callable()) -> bool:
	return _accepts_mutations() and component_registry.register_component(type_key, variant_type, validator)

func unregister_component(type_key: StringName) -> bool:
	return _accepts_mutations() and component_registry.unregister_component(type_key)

func _validate_component(entity_id: int, type_key: StringName, value: Variant) -> bool:
	if not validation_enabled:
		return true
	_validation_depth += 1
	var valid := component_registry.validate(type_key, value, require_registered_components)
	if valid:
		_validation_depth -= 1
		last_validation_error = ""
		return true
	last_validation_error = component_registry.last_error
	validation_failed.emit(entity_id, type_key, last_validation_error)
	_validation_depth -= 1
	return false

func _validate_component_schema(type_key: StringName, value: Variant) -> bool:
	if not _on_owner_thread() or _disposed:
		return false
	_validation_depth += 1
	var valid := component_registry.validate(type_key, value, require_registered_components)
	last_validation_error = "" if valid else component_registry.last_error
	_validation_depth -= 1
	return valid

func query(criteria: Dictionary = {}) -> EcsQuery:
	var all := _normalize_types(criteria.get("all", []))
	var any := _normalize_types(criteria.get("any", []))
	var none := _normalize_types(criteria.get("none", []))
	var key := "%s%s%s" % [_encode_types(all), _encode_types(any), _encode_types(none)]
	var cached: EcsQuery = _queries.get(key)
	if cached != null:
		return cached
	var result := EcsQuery.new(self, all, any, none)
	if not _disposed:
		_queries[key] = result
		for type_key in result._watched_types:
			if not _queries_by_type.has(type_key):
				_queries_by_type[type_key] = []
			_queries_by_type[type_key].append(result)
		if all.is_empty() and any.is_empty():
			_entity_queries.append(result)
	return result

func add_system(system: EcsSystem) -> bool:
	if not _accepts_mutations() or system == null or _system_order.has(system) or _detaching_systems.has(system) or system._world_instance_id != 0:
		return false
	system._world_instance_id = get_instance_id()
	_systems.append(system)
	_system_order[system] = _next_system_order
	_next_system_order += 1
	system.schedule_changed.connect(_mark_schedule_dirty)
	_mark_schedule_dirty()
	system.configure(self)
	if not _system_order.has(system):
		return false
	if _started:
		var schedule := _get_schedule()
		if not last_schedule_error.is_empty() or not _started_systems_are_prefix(schedule):
			_rollback_system_registration(system)
			return false
		if not _starting:
			start()
	return true

func _rollback_system_registration(system: EcsSystem) -> void:
	_detaching_systems[system] = true
	_systems.erase(system)
	_system_order.erase(system)
	if system.schedule_changed.is_connected(_mark_schedule_dirty):
		system.schedule_changed.disconnect(_mark_schedule_dirty)
	_mark_schedule_dirty()
	system.on_detach()
	system._world_instance_id = 0
	_detaching_systems.erase(system)

func _started_systems_are_prefix(schedule: Array[EcsSystem]) -> bool:
	if _started_systems.size() > schedule.size():
		return false
	for index in _started_systems.size():
		if not _started_systems.has(schedule[index]):
			return false
	return true

func remove_system(system: EcsSystem) -> bool:
	if not _on_owner_thread() or _validation_depth > 0 or not _system_order.has(system) or _detaching_systems.has(system):
		return false
	_detaching_systems[system] = true
	_systems.erase(system)
	_system_order.erase(system)
	_system_timings.erase(system.get_instance_id())
	if system.schedule_changed.is_connected(_mark_schedule_dirty):
		system.schedule_changed.disconnect(_mark_schedule_dirty)
	_mark_schedule_dirty()
	if _started_systems.erase(system):
		system.on_stop()
	system.on_detach()
	system._world_instance_id = 0
	_detaching_systems.erase(system)
	return true

func set_system_enabled(system: EcsSystem, value: bool) -> bool:
	if not _accepts_mutations() or not _system_order.has(system):
		return false
	system.enabled = value
	return true

func set_system_priority(system: EcsSystem, value: int) -> bool:
	if not _accepts_mutations() or not _system_order.has(system):
		return false
	system.priority = value
	return true

func set_system_phase(system: EcsSystem, value: int) -> bool:
	if not _accepts_mutations() or not _system_order.has(system) or value < EcsSystem.Phase.SIMULATION or value > EcsSystem.Phase.PRESENTATION:
		return false
	system.phase = value
	return true

func resort_systems() -> void:
	if not _on_owner_thread():
		return
	_mark_schedule_dirty()
	_get_schedule()

func start() -> void:
	if not _on_owner_thread() or _validation_depth > 0 or _restoring or _disposed or _dispose_requested or _stopping or _lifecycle_busy or _starting or not validate_schedule():
		return
	if _started and _started_systems.size() == _systems.size():
		return
	_started = true
	_starting = true
	# Startup callbacks may attach systems or change dependency declarations.
	while true:
		if _stop_requested or _dispose_requested:
			break
		var schedule := _get_schedule()
		if not last_schedule_error.is_empty():
			break
		if not _started_systems_are_prefix(schedule):
			last_schedule_error = "Startup dependencies precede already-started systems; correct declarations or stop and restart."
			break
		var next_system: EcsSystem
		for system in schedule:
			if _system_order.has(system) and not _started_systems.has(system):
				next_system = system
				break
		if next_system == null:
			break
		_start_system(next_system)
	_starting = false
	flush()

func _start_system(system: EcsSystem) -> void:
	if _started_systems.has(system):
		return
	_started_systems[system] = true
	system.on_start()

func tick(delta: float) -> void:
	_tick(delta, -1)

func tick_phase(delta: float, phase_filter: int) -> void:
	if phase_filter == EcsSystem.Phase.SIMULATION or phase_filter == EcsSystem.Phase.PRESENTATION:
		_tick(delta, phase_filter)

func _tick(delta: float, phase_filter: int) -> void:
	if not _on_owner_thread() or _validation_depth > 0 or _restoring or _disposed or _dispose_requested or _is_ticking or _starting or _stopping or _lifecycle_busy or _iteration_depth > 0 or _is_flushing or not is_finite(delta) or delta < 0.0:
		return
	if phase_filter != EcsSystem.Phase.PRESENTATION and (simulation_tick == 9223372036854775807 or not is_finite(simulation_time + delta)):
		return
	if not validate_schedule():
		return
	_is_ticking = true
	start()
	if _stop_requested or _dispose_requested or not validate_schedule() or _started_systems.size() != _systems.size():
		_is_ticking = false
		flush()
		return
	if phase_filter != EcsSystem.Phase.PRESENTATION:
		simulation_tick += 1
		simulation_time += delta
		if _events != null:
			_events.advance()
	var tick_started := Time.get_ticks_usec() if profiling_enabled else 0
	var schedule := _get_schedule()
	var orders := _schedule_orders
	for index in range(schedule.size()):
		if _dispose_requested or _stop_requested:
			break
		var system := schedule[index]
		if _system_order.get(system, -1) != orders[index] or not system.enabled or (phase_filter >= 0 and system.phase != phase_filter):
			continue
		var system_started := Time.get_ticks_usec() if profiling_enabled else 0
		_current_system = system.schedule_key if not system.schedule_key.is_empty() else StringName(system.debug_name)
		system.on_update(self, delta)
		if profiling_enabled and _system_order.has(system):
			_system_timings[system.get_instance_id()] = Time.get_ticks_usec() - system_started
	_current_system = &""
	_is_ticking = false
	if profiling_enabled:
		_last_tick_usec = Time.get_ticks_usec() - tick_started
	flush()

func stop() -> void:
	if not _on_owner_thread() or _restoring or _validation_depth > 0 or _disposed or _stopping:
		return
	_stop_requested = true
	flush()

func _stop_now() -> void:
	_stop_requested = false
	if not _started:
		return
	_stopping = true
	_started = false
	var schedule := _get_schedule()
	if not last_schedule_error.is_empty():
		schedule = _systems.duplicate()
	for index in range(schedule.size() - 1, -1, -1):
		var system := schedule[index]
		if _started_systems.erase(system):
			system.on_stop()
	_stopping = false

## Destroys entities, preserving generations, systems, and component schemas.
func clear() -> void:
	if not _on_owner_thread() or _restoring or _validation_depth > 0 or _disposed or _dispose_requested or _lifecycle_busy or _emitting_cleared:
		return
	_clear_requested = true
	flush()

## Permanently closes the world and releases all registered systems and schemas.
func dispose() -> void:
	if not _on_owner_thread() or _restoring or _validation_depth > 0 or _disposed or _lifecycle_busy:
		return
	_dispose_requested = true
	flush()

func is_disposed() -> bool:
	return _disposed

func flush() -> void:
	if not _on_owner_thread() or _restoring or _is_ticking or _starting or _stopping or _iteration_depth > 0 or _is_flushing:
		return
	_is_flushing = true
	while true:
		while not _commands.is_empty():
			var batch := _commands
			_commands = []
			for command in batch:
				var entity_id: int = command.get("entity", -1)
				_current_system = command.get("system", &"")
				match command["op"]:
					&"add": _add_component_now(entity_id, command["type"], command["value"])
					&"remove": _remove_component_now(entity_id, command["type"])
					&"set":
						_set_component_now(entity_id, command["type"], command["value"])
					&"destroy": _destroy_entity_now(entity_id)
					&"batch":
						for row in command.entities.size():
							_set_component_now(command.entities[row], command["type"], command.values[row])
				_current_system = &""
		_pending_membership.clear()
		_pending_destroy.clear()
		if _dispose_requested:
			_dispose_now()
			break
		if _clear_requested:
			_clear_now()
			continue
		if _stop_requested:
			_stop_now()
			continue
		break
	_is_flushing = false

func _clear_now() -> void:
	_lifecycle_busy = true
	_clear_requested = false
	if _relations != null:
		_relations.clear()
	if _events != null:
		_events.clear()
	for entity_id in _alive_entities.duplicate():
		_destroy_entity_now(entity_id)
	storage.clear()
	_pending_membership.clear()
	_pending_destroy.clear()
	_commands.clear()
	_lifecycle_busy = false
	_emitting_cleared = true
	cleared.emit()
	_emitting_cleared = false

func _dispose_now() -> void:
	_lifecycle_busy = true
	_stop_now()
	for system in _systems.duplicate():
		remove_system(system)
	_lifecycle_busy = false
	_clear_now()
	component_registry.clear()
	storage._world_instance_id = 0
	if _relations != null:
		_relations.detach()
	_relations = null
	_events = null
	_queries.clear()
	_queries_by_type.clear()
	_entity_queries.clear()
	_schedule.clear()
	_schedule_orders.clear()
	_started_systems.clear()
	_disposed = true
	_dispose_requested = false
	_clear_requested = false
	_stop_requested = false
	disposed.emit()
	# A closed world will emit no more events. Release callbacks which may own it.
	for signal_name: StringName in [&"entity_destroyed", &"cleared", &"disposed", &"validation_failed", &"mutation_committed", &"restored"]:
		for connection: Dictionary in get_signal_connection_list(signal_name):
			disconnect(signal_name, connection["callable"])

func _accepts_mutations() -> bool:
	return _on_owner_thread() and _validation_depth == 0 and not _disposed and not _dispose_requested and not _clear_requested and not _lifecycle_busy

func _can_write_entity(entity_id: int) -> bool:
	return _accepts_mutations() and is_entity_alive(entity_id) and not is_entity_pending_destroy(entity_id)

func _projected_has_component(entity_id: int, type_key: StringName) -> bool:
	if _pending_membership.has(entity_id):
		var pending: Dictionary = _pending_membership[entity_id]
		if pending.has(type_key):
			return bool(pending[type_key])
	return has_component(entity_id, type_key)

func _set_pending_membership(entity_id: int, type_key: StringName, present: bool) -> void:
	if not _pending_membership.has(entity_id):
		_pending_membership[entity_id] = {}
	_pending_membership[entity_id][type_key] = present

func _must_defer() -> bool:
	return _is_ticking or _iteration_depth > 0 or _is_flushing

func _begin_iteration() -> void:
	_iteration_depth += 1

func _end_iteration() -> void:
	_iteration_depth = maxi(0, _iteration_depth - 1)
	flush()

func _destroy_entity_now(entity_id: int) -> bool:
	if not is_entity_alive(entity_id):
		return false
	for type_key in storage.keys_for(entity_id):
		_remove_component_now(entity_id, type_key)
	storage.destroy_entity(entity_id)
	var index: int = _alive_indices[entity_id]
	var last_entity: int = _alive_entities.back()
	_alive_entities[index] = last_entity
	_alive_indices[last_entity] = index
	_alive_entities.pop_back()
	_alive_indices.erase(entity_id)
	var slot := entity_id & _SLOT_MASK
	_alive_slots[slot] = false
	_free_slots.append(slot)
	_entity_version += 1
	_topology_version += 1
	_notify_entity_queries(entity_id)
	_record_mutation(&"destroy", entity_id)
	_uid_entities.erase(get_entity_uid(entity_id))
	_entity_uids.erase(entity_id)
	if not _restoring:
		entity_destroyed.emit(entity_id)
	return true

func _add_component_now(entity_id: int, type_key: StringName, value: Variant) -> bool:
	if not is_entity_alive(entity_id):
		return false
	if not storage.add(entity_id, type_key, value):
		return false
	_mark_component_changed(type_key, entity_id)
	_record_mutation(&"add", entity_id, type_key)
	return true

func _remove_component_now(entity_id: int, type_key: StringName) -> bool:
	if not storage.remove(entity_id, type_key):
		return false
	_mark_component_changed(type_key, entity_id)
	_record_mutation(&"remove", entity_id, type_key)
	return true

func _set_component_now(entity_id: int, type_key: StringName, value: Variant) -> bool:
	if not is_entity_alive(entity_id) or not storage.set_value(entity_id, type_key, value):
		return false
	_record_mutation(&"set", entity_id, type_key)
	return true

func _mark_component_changed(type_key: StringName, entity_id: int) -> void:
	_component_versions[type_key] = get_component_version(type_key) + 1
	_topology_version += 1
	for cached: EcsQuery in _queries_by_type.get(type_key, []):
		cached._notify_membership(entity_id)

func _notify_entity_queries(entity_id: int) -> void:
	for cached in _entity_queries:
		cached._notify_membership(entity_id)

func get_component_version(type_key: StringName) -> int:
	return int(_component_versions.get(type_key, 0))

func get_entity_version() -> int:
	return _entity_version

func _driver_entities_for(all: Array[StringName], any: Array[StringName]) -> Array[int]:
	if all.is_empty() and any.is_empty():
		return _alive_entities.duplicate()
	if all.is_empty():
		var candidates: Dictionary = {}
		for type_key in any:
			for entity_id in storage.entities_for(type_key):
				candidates[entity_id] = true
		var result: Array[int] = []
		for entity_id in candidates:
			result.append(int(entity_id))
		return result
	var driver_key: StringName = &""
	var driver_count: int = 9223372036854775807
	for type_key in all:
		var count := storage.component_count(type_key)
		if count == 0:
			return []
		if count < driver_count:
			driver_key = type_key
			driver_count = count
	return storage.entities_for(driver_key)

func _matches_query(entity_id: int, all: Array[StringName], any: Array[StringName], none: Array[StringName]) -> bool:
	if not is_entity_alive(entity_id):
		return false
	for type_key in all:
		if not has_component(entity_id, type_key):
			return false
	if not any.is_empty():
		var matches_any := false
		for type_key in any:
			if has_component(entity_id, type_key):
				matches_any = true
				break
		if not matches_any:
			return false
	for type_key in none:
		if has_component(entity_id, type_key):
			return false
	return true

func _normalize_types(input: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if input is Array or input is PackedStringArray:
		for item: Variant in input:
			if item is not String and item is not StringName:
				continue
			var type_key := StringName(item)
			if not type_key.is_empty() and not result.has(type_key):
				result.append(type_key)
	result.sort()
	return result

func _encode_types(types: Array[StringName]) -> String:
	var result := "%d:" % types.size()
	for type_key in types:
		result += "%d:%s" % [String(type_key).length(), type_key]
	return result

func _mark_schedule_dirty() -> void:
	_schedule_dirty = true
	_schedule = []
	_schedule_orders = []
	_scheduler.clear_cache()

func _get_schedule() -> Array[EcsSystem]:
	if not _schedule_dirty and _scheduler.declarations_changed(_systems):
		_schedule_dirty = true
	if _schedule_dirty:
		_scheduler.build(_systems, _system_order)
		_schedule = _scheduler.order.duplicate()
		last_schedule_error = _scheduler.last_error
		_schedule_orders = []
		for system in _schedule:
			_schedule_orders.append(_system_order[system])
		_schedule_dirty = false
	return _schedule

func get_entity_components(entity_id: int) -> Dictionary:
	if not is_entity_alive(entity_id):
		return {}
	return storage.entity_components(entity_id)

func get_debug_snapshot(max_entities: int = 100) -> Dictionary:
	var counts: Dictionary = {}
	for type_key in storage.component_types():
		counts[type_key] = storage.component_count(type_key)
	var ids := get_entities()
	ids.sort()
	var entities: Array[Dictionary] = []
	for index in range(mini(ids.size(), maxi(max_entities, 0))):
		entities.append({"id": ids[index], "components": get_entity_components(ids[index])})
	var systems: Array[Dictionary] = []
	for system in _get_schedule():
		var system_name := system.debug_name
		if system_name.is_empty():
			var script := system.get_script() as Script
			system_name = String(script.get_global_name()) if script != null else "EcsSystem"
			if system_name.is_empty():
				system_name = "System %d" % system.get_instance_id()
		systems.append({"name": system_name, "enabled": system.enabled, "priority": system.priority, "phase": system.phase, "last_update_usec": int(_system_timings.get(system.get_instance_id(), 0))})
	return {"entity_count": entity_count(), "component_counts": counts, "entities": entities, "systems": systems, "query_count": _queries.size(), "pending_command_count": _commands.size(), "last_tick_usec": _last_tick_usec, "disposed": _disposed, "profiling_enabled": profiling_enabled, "validation_enabled": validation_enabled, "last_validation_error": last_validation_error, "schedule_error": last_schedule_error, "simulation_tick": simulation_tick, "simulation_time": simulation_time, "storage": storage.diagnostics(), "trace": get_trace()}

func set_storage_backend(backend: EcsStorage) -> bool:
	if not _accepts_mutations() or _restoring or _must_defer() or entity_count() != 0 or backend == null or backend._world_instance_id != 0 or int(backend.diagnostics().get("entity_count", 0)) != 0:
		return false
	storage._world_instance_id = 0
	storage = backend
	storage._world_instance_id = get_instance_id()
	return true

func get_entity_uid(entity_id: int) -> int:
	return int(_entity_uids.get(entity_id, 0))

func get_entity_by_uid(uid: int) -> int:
	var entity_id: int = _uid_entities.get(uid, -1)
	return entity_id if is_entity_alive(entity_id) and not is_entity_pending_destroy(entity_id) else -1

func create_change_reader(types: Array = []) -> EcsChangeReader:
	if _on_owner_thread():
		change_tracking_enabled = true
	return EcsChangeReader.new(self, _normalize_types(types))

func mark_component_changed(entity_id: int, type_key: StringName) -> bool:
	if not _can_write_entity(entity_id) or not has_component(entity_id, type_key):
		return false
	_begin_iteration()
	_record_mutation(&"touch", entity_id, type_key)
	_end_iteration()
	return true

## Prevalidate every row; no partial updates if any ID, membership or schema fails.
func write_batch(type_key: StringName, entities: Variant, values: Variant) -> bool:
	if not _accepts_mutations() or not _is_sequence(entities) or not _is_sequence(values) or entities.size() != values.size() or type_key.is_empty():
		return false
	var seen: Dictionary = {}
	var pending := false
	for row in entities.size():
		if typeof(entities[row]) != TYPE_INT:
			return false
		var entity: int = entities[row]
		if seen.has(entity) or not is_entity_alive(entity) or _pending_destroy.has(entity):
			return false
		var has_queued_membership: bool = _pending_membership.has(entity) and _pending_membership[entity].has(type_key)
		if has_queued_membership:
			if not _pending_membership[entity][type_key]:
				return false
			pending = true
		elif not storage.has(entity, type_key):
			return false
		if validation_enabled and not _validate_component(entity, type_key, values[row]):
			return false
		seen[entity] = true
	if pending:
		_commands.append({"op": &"batch", "type": type_key, "entities": entities.duplicate(), "values": values.duplicate(), "system": _current_system})
		return true
	_begin_iteration()
	storage.set_values_unchecked(type_key, entities, values)
	if change_tracking_enabled or trace_enabled or mutation_committed.has_connections():
		for entity: int in entities:
			_record_mutation(&"set", entity, type_key)
	elif not _restoring:
		_mutation_sequence += entities.size()
	_end_iteration()
	return true

func _is_sequence(value: Variant) -> bool:
	return value is Array or (typeof(value) >= TYPE_PACKED_BYTE_ARRAY and typeof(value) <= TYPE_PACKED_VECTOR4_ARRAY)

func validate_schedule() -> bool:
	_get_schedule()
	return last_schedule_error.is_empty()

func get_execution_batches() -> Array[Array]:
	_get_schedule()
	return _scheduler.batches.duplicate(true)

func _record_mutation(op: StringName, entity: int, key: StringName = &"") -> void:
	if _restoring:
		return
	_mutation_sequence += 1
	if not change_tracking_enabled and not trace_enabled and not mutation_committed.has_connections():
		return
	var record := {"op": op, "entity": entity, "uid": get_entity_uid(entity), "key": key, "system": _current_system, "tick": simulation_tick, "sequence": _mutation_sequence}
	if change_tracking_enabled:
		_journal.append(record)
	if trace_enabled:
		_trace.append(record)
	if mutation_committed.has_connections():
		_begin_iteration()
		mutation_committed.emit(record.duplicate(true))
		_end_iteration()

func get_trace() -> Array[Dictionary]:
	return _trace.records_since(-1, _trace.epoch).changes

func clear_trace() -> void:
	if _on_owner_thread():
		_trace.reset()

func get_relations() -> EcsRelations:
	if not _on_owner_thread():
		return null
	if _relations == null and not _disposed:
		_relations = EcsRelations.new(self)
	return _relations

func get_events() -> EcsEventQueue:
	if not _on_owner_thread():
		return null
	if _events == null and not _disposed:
		_events = EcsEventQueue.new()
	return _events

func register_reference_component(key: StringName) -> bool:
	if not _accepts_mutations() or key.is_empty():
		return false
	if not _reference_components.has(key):
		_reference_components.append(key)
	return true

func get_reference_components() -> Array[StringName]:
	return _reference_components.duplicate()

func export_metadata() -> Dictionary:
	return {"next_uid": _next_uid, "simulation_tick": simulation_tick, "simulation_time": simulation_time, "rng_seed": rng.seed, "rng_state": rng.state}

func restore_metadata(meta: Dictionary) -> bool:
	for key: String in ["next_uid", "simulation_tick", "rng_seed", "rng_state"]:
		if not meta.has(key) or typeof(meta[key]) != TYPE_INT:
			return false
	if not meta.has("simulation_time") or (typeof(meta.simulation_time) != TYPE_FLOAT and typeof(meta.simulation_time) != TYPE_INT) or not is_finite(float(meta.simulation_time)) or float(meta.simulation_time) < 0.0 or meta.next_uid < _next_uid or meta.simulation_tick < 0 or not _accepts_mutations():
		return false
	_next_uid = meta.next_uid
	simulation_tick = meta.simulation_tick
	simulation_time = float(meta.simulation_time)
	rng.seed = meta.rng_seed
	rng.state = meta.rng_state
	return true

func begin_restore() -> bool:
	if not _accepts_mutations() or _restoring or _must_defer() or _starting or _stopping or not _commands.is_empty():
		return false
	_restoring = true
	if _relations != null:
		_relations.clear()
	if _events != null:
		_events.clear()
	for entity in _alive_entities.duplicate():
		_destroy_entity_now(entity)
	storage.clear()
	_next_uid = 1
	return true

func end_restore(id_map: Dictionary) -> void:
	if not _on_owner_thread() or not _restoring:
		return
	_restoring = false
	_journal.reset()
	clear_trace()
	for cached: EcsQuery in _queries.values():
		cached._invalidate()
	_begin_iteration()
	restored.emit(id_map.duplicate())
	_end_iteration()

func _on_owner_thread() -> bool:
	return OS.get_thread_caller_id() == _owner_thread

func is_at_safe_boundary() -> bool:
	return _accepts_mutations() and not _restoring and not _must_defer() and not _starting and not _stopping and _commands.is_empty()
