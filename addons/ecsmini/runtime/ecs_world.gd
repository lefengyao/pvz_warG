class_name EcsWorld
extends RefCounted

## ECS runtime root. Owns entity lifetime, component stores, cached queries, and system
## execution. Component types are application-defined [StringName] keys.[br][br]
## [codeblock]
## var world := EcsWorld.new()
## var entity := world.create_entity()
## world.add_component(entity, &"position", Vector2.ZERO)
## world.add_component(entity, &"health", 100)
## world.tick(1.0 / 60.0)
## [/codeblock]
## Structural changes requested during [method tick] or [method EcsQuery.for_each] are
## queued and applied at a safe boundary. Setting an existing component value is immediate.
##
## @tutorial(ECS design pattern): https://en.wikipedia.org/wiki/Entity_component_system

const _SLOT_MASK: int = 0xffffffff

var _generations: Array[int] = [0]
var _alive_slots: Array[bool] = [false]
var _alive_entities: Array[int] = []
var _alive_indices: Dictionary = {}
var _free_slots: Array[int] = []

var _stores: Dictionary = {}
var _queries: Dictionary = {}
var _topology_version: int = 0

## Emitted after an entity is destroyed and its components have been removed.
## [code]world.entity_destroyed.connect(func(entity_id): print(entity_id))[/code]
signal entity_destroyed(entity_id: int)

var _systems: Array[EcsSystem] = []
var _system_order: Dictionary = {}
var _next_system_order: int = 0
var _started: bool = false
var _is_ticking: bool = false
var _iteration_depth: int = 0
var _commands: Array[Dictionary] = []
var _is_flushing: bool = false


## Creates and returns a live entity ID. IDs include a generation, so an old ID remains
## invalid after its storage slot is reused. Example: [code]var player := world.create_entity()[/code].
func create_entity() -> int:
	var slot: int
	if _free_slots.is_empty():
		slot = _generations.size()
		_generations.append(1)
		_alive_slots.append(false)
	else:
		slot = _free_slots.pop_back()
		_generations[slot] += 1
	if _generations[slot] <= 0:
		_generations[slot] = 1
	_alive_slots[slot] = true
	var entity_id := _encode_entity(slot, _generations[slot])
	_alive_indices[entity_id] = _alive_entities.size()
	_alive_entities.append(entity_id)
	_mark_topology_changed()
	return entity_id


## Destroys [param entity_id] and removes all of its components. Returns [code]false[/code]
## for an invalid ID. During iteration, the command is queued; a [code]true[/code] result then
## means the command was accepted, not that destruction has already happened.
## [code]world.destroy_entity(enemy_id)[/code]
func destroy_entity(entity_id: int) -> bool:
	if not is_entity_alive(entity_id):
		return false
	if _must_defer():
		_queue_command({"op": &"destroy", "entity": entity_id})
		return true
	return _destroy_entity_now(entity_id)


## Returns [code]true[/code] only when [param entity_id] is a currently live ID from this world.
## Use it before retaining an ID across frames: [code]if world.is_entity_alive(target): pass[/code].
func is_entity_alive(entity_id: int) -> bool:
	var slot := _slot_from(entity_id)
	return slot > 0 and slot < _alive_slots.size() and _alive_slots[slot] and _generations[slot] == _generation_from(entity_id)


## Returns the number of live entities, regardless of their components.
## [code]print(world.entity_count())[/code]
func entity_count() -> int:
	return _alive_entities.size()


## Adds a component identified by [param type_key] to a live entity. Returns [code]false[/code]
## when the ID or key is invalid, or the component already exists. Use [method set_component]
## to replace an existing value.
## [code]world.add_component(player, &"health", 100)[/code]
func add_component(entity_id: int, type_key: StringName, value: Variant = null) -> bool:
	if not is_entity_alive(entity_id) or type_key.is_empty() or has_component(entity_id, type_key):
		return false
	if _must_defer():
		_queue_command({"op": &"add", "entity": entity_id, "type": type_key, "value": value})
		return true
	return _add_component_now(entity_id, type_key, value)


## Removes the component identified by [param type_key]. Returns [code]false[/code] when it
## is absent or the entity is invalid. The removal is deferred during a tick or query callback.
## [code]world.remove_component(player, &"stunned")[/code]
func remove_component(entity_id: int, type_key: StringName) -> bool:
	if not is_entity_alive(entity_id) or not has_component(entity_id, type_key):
		return false
	if _must_defer():
		_queue_command({"op": &"remove", "entity": entity_id, "type": type_key})
		return true
	return _remove_component_now(entity_id, type_key)


## Returns whether a live entity currently owns [param type_key].
## [code]if world.has_component(player, &"player"): pass[/code]
func has_component(entity_id: int, type_key: StringName) -> bool:
	if not is_entity_alive(entity_id):
		return false
	var store: EcsComponentStore = _stores.get(type_key)
	return store != null and store.has(entity_id)


## Returns a component value, or [param default_value] when the entity is invalid or the
## component is absent. Use a typed local variable when reading structured data.
## [code]var health: int = world.get_component(player, &"health", 0)[/code]
func get_component(entity_id: int, type_key: StringName, default_value: Variant = null) -> Variant:
	if not is_entity_alive(entity_id):
		return default_value
	var store: EcsComponentStore = _stores.get(type_key)
	if store == null:
		return default_value
	return store.get_value(entity_id, default_value)


## Replaces an existing component value without changing query membership. This operation is
## immediate and safe during [method tick]. Returns [code]false[/code] if the component is absent.
## [code]world.set_component(player, &"health", 75)[/code]
func set_component(entity_id: int, type_key: StringName, value: Variant) -> bool:
	if not is_entity_alive(entity_id):
		return false
	var store: EcsComponentStore = _stores.get(type_key)
	if store == null or not store.has(entity_id):
		return false
	# Value replacement does not change query membership and is safe during a tick.
	return store.set_value(entity_id, value)


## Returns a cached [EcsQuery] for component criteria. [code]all[/code] requires every key,
## [code]any[/code] requires at least one key, and [code]none[/code] excludes every key.
## [code]var movers := world.query({"all": [&"position", &"velocity"], "none": [&"dead"]})[/code]
func query(criteria: Dictionary = {}) -> EcsQuery:
	var all := _normalize_types(criteria.get("all", []))
	var any := _normalize_types(criteria.get("any", []))
	var none := _normalize_types(criteria.get("none", []))
	var key := _query_key(all, any, none)
	var cached: EcsQuery = _queries.get(key)
	if cached != null:
		return cached
	var result := EcsQuery.new(self, all, any, none)
	_queries[key] = result
	return result


## Registers [param system], calls [method EcsSystem.configure], and sorts it by priority.
## If the world has started, [method EcsSystem.on_start] runs immediately. Returns [code]false[/code]
## for [code]null[/code] or a system already registered.
## [code]world.add_system(EcsMovementSystem.new())[/code]
func add_system(system: EcsSystem) -> bool:
	if system == null or _systems.has(system):
		return false
	_systems.append(system)
	_system_order[system] = _next_system_order
	_next_system_order += 1
	_sort_systems()
	system.configure(self)
	if _started:
		system.on_start()
	return true


## Unregisters [param system]. A running world calls [method EcsSystem.on_stop] first.
## [code]world.remove_system(movement_system)[/code]
func remove_system(system: EcsSystem) -> bool:
	var index := _systems.find(system)
	if index < 0:
		return false
	if _started:
		system.on_stop()
	_systems.remove_at(index)
	_system_order.erase(system)
	return true


## Starts the world and calls [method EcsSystem.on_start] on registered systems in schedule order.
## Calling it again has no effect. [code]world.start()[/code]
func start() -> void:
	if _started:
		return
	_started = true
	for system in _systems:
		system.on_start()


## Advances the simulation by [param delta] seconds. Starts the world automatically if necessary,
## updates a stable system snapshot, then applies queued structural commands.
## [code]world.tick(get_process_delta_time())[/code]
func tick(delta: float) -> void:
	if _is_ticking:
		return
	if not _started:
		start()
	_is_ticking = true
	for system in _systems.duplicate():
		system.on_update(self, delta)
	_is_ticking = false
	_flush_commands()


## Stops the world and calls [method EcsSystem.on_stop] in reverse schedule order.
## Calling it on a stopped world has no effect. [code]world.stop()[/code]
func stop() -> void:
	if not _started:
		return
	var systems := _systems.duplicate()
	systems.reverse()
	for system in systems:
		system.on_stop()
	_started = false
	_flush_commands()


## Immediately applies queued structural commands when the world is not ticking or iterating.
## Usually this is automatic; call [code]world.flush()[/code] only at an explicit safe boundary.
func flush() -> void:
	if _is_ticking or _iteration_depth > 0:
		return
	_flush_commands()


## Internal iteration guard entered by [method EcsQuery.for_each]. It defers structural changes.
func _begin_iteration() -> void:
	_iteration_depth += 1


## Internal iteration guard exit. Flushes queued commands after the outermost query callback ends.
func _end_iteration() -> void:
	_iteration_depth = maxi(0, _iteration_depth - 1)
	if _iteration_depth == 0 and not _is_ticking:
		_flush_commands()


## Internal query optimizer. Selects the smallest required store or unions [param any] stores
## to produce candidate entities before full criteria matching.
func _driver_entities_for(all: Array[StringName], any: Array[StringName]) -> Array[int]:
	if all.is_empty() and any.is_empty():
		return _alive_entities.duplicate()
	if all.is_empty():
		var candidates: Dictionary = {}
		for type_key in any:
			var store: EcsComponentStore = _stores.get(type_key)
			if store == null:
				continue
			for entity_id in store.entities():
				candidates[entity_id] = true
		var result: Array[int] = []
		for entity_id in candidates.keys():
			result.append(int(entity_id))
		return result
	var driver: EcsComponentStore
	for type_key in all:
		var store: EcsComponentStore = _stores.get(type_key)
		if store == null or store.size() == 0:
			return []
		if driver == null or store.size() < driver.size():
			driver = store
	return driver.entities()


## Internal predicate that evaluates normalized [code]all[/code], [code]any[/code], and
## [code]none[/code] criteria for one entity.
func _matches_query(entity_id: int, all: Array[StringName], any: Array[StringName], none: Array[StringName]) -> bool:
	if not is_entity_alive(entity_id):
		return false
	for type_key in all:
		if not has_component(entity_id, type_key):
			return false
	if not any.is_empty():
		var has_any := false
		for type_key in any:
			if has_component(entity_id, type_key):
				has_any = true
				break
		if not has_any:
			return false
	for type_key in none:
		if has_component(entity_id, type_key):
			return false
	return true


## Internal immediate destruction path used outside protected iteration and while flushing.
## Removes components, releases the slot, changes topology, then emits [signal entity_destroyed].
func _destroy_entity_now(entity_id: int) -> bool:
	if not is_entity_alive(entity_id):
		return false
	for store in _stores.values():
		(store as EcsComponentStore).remove(entity_id)
	var alive_index: int = _alive_indices[entity_id]
	var last_index := _alive_entities.size() - 1
	var last_entity := _alive_entities[last_index]
	if alive_index != last_index:
		_alive_entities[alive_index] = last_entity
		_alive_indices[last_entity] = alive_index
	_alive_entities.pop_back()
	_alive_indices.erase(entity_id)
	var slot := _slot_from(entity_id)
	_alive_slots[slot] = false
	_free_slots.append(slot)
	_mark_topology_changed()
	entity_destroyed.emit(entity_id)
	return true


## Internal immediate add path. Creates a component store on first use and invalidates queries.
func _add_component_now(entity_id: int, type_key: StringName, value: Variant) -> bool:
	if not is_entity_alive(entity_id):
		return false
	var store: EcsComponentStore = _stores.get(type_key)
	if store == null:
		store = EcsComponentStore.new()
		_stores[type_key] = store
	if not store.add(entity_id, value):
		return false
	_mark_topology_changed()
	return true


## Internal immediate removal path. Deletes empty stores and invalidates query caches.
func _remove_component_now(entity_id: int, type_key: StringName) -> bool:
	var store: EcsComponentStore = _stores.get(type_key)
	if store == null or not store.remove(entity_id):
		return false
	if store.size() == 0:
		_stores.erase(type_key)
	_mark_topology_changed()
	return true


## Internal guard that reports whether structural commands must be queued for safety.
func _must_defer() -> bool:
	return _is_ticking or _iteration_depth > 0 or _is_flushing


## Internal FIFO enqueue for deferred add, remove, and destroy commands.
func _queue_command(command: Dictionary) -> void:
	_commands.append(command)


## Internal FIFO command drain. Commands queued while flushing are processed in a later batch.
func _flush_commands() -> void:
	if _commands.is_empty() or _is_flushing:
		return
	_is_flushing = true
	while not _commands.is_empty():
		var batch := _commands
		_commands = []
		for command in batch:
			var entity_id: int = command["entity"]
			match command["op"]:
				&"add":
					_add_component_now(entity_id, command["type"], command["value"])
				&"remove":
					_remove_component_now(entity_id, command["type"])
				&"destroy":
					_destroy_entity_now(entity_id)
	_is_flushing = false


## Internal criteria normalizer. Removes empty and duplicate keys, then sorts for stable cache keys.
func _normalize_types(input: Variant) -> Array[StringName]:
	var unique: Dictionary = {}
	if input is Array:
		for item in input:
			var type_key := StringName(item)
			if not type_key.is_empty():
				unique[type_key] = true
	var result: Array[StringName] = []
	for type_key in unique.keys():
		result.append(type_key)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result


## Internal cache-key builder for a normalized query definition.
func _query_key(all: Array[StringName], any: Array[StringName], none: Array[StringName]) -> String:
	return "%s%s%s" % [_encode_types(all), _encode_types(any), _encode_types(none)]


## Internal length-prefixed component-key encoder. Length prefixes avoid separator collisions.
func _encode_types(types: Array[StringName]) -> String:
	var encoded := "%d:" % types.size()
	for type_key in types:
		var text := String(type_key)
		encoded += "%d:%s" % [text.length(), text]
	return encoded


## Internal stable scheduler sort: priority first, original registration order second.
func _sort_systems() -> void:
	_systems.sort_custom(func(left: EcsSystem, right: EcsSystem) -> bool:
		if left.priority != right.priority:
			return left.priority < right.priority
		return _system_order[left] < _system_order[right]
	)


## Internal cache invalidator called after entity or component membership changes.
func _mark_topology_changed() -> void:
	_topology_version += 1


## Internal entity-ID encoder that packs a slot and generation into one integer.
func _encode_entity(slot: int, generation: int) -> int:
	return (generation << 32) | slot


## Internal entity-ID decoder for the storage slot portion.
func _slot_from(entity_id: int) -> int:
	return entity_id & _SLOT_MASK


## Internal entity-ID decoder for the generation portion.
func _generation_from(entity_id: int) -> int:
	return entity_id >> 32
