class_name EcsRelations
extends RefCounted

## A link's policy applies when its target is destroyed.
enum DestructionPolicy { REMOVE_LINK, DESTROY_SOURCE, RESTRICT }
const REMOVE_LINK := DestructionPolicy.REMOVE_LINK
const DESTROY_SOURCE := DestructionPolicy.DESTROY_SOURCE
const RESTRICT := DestructionPolicy.RESTRICT
var last_error: String = ""
var _world_ref: WeakRef
var _links: Dictionary = {}
var _inverse: Dictionary = {}

func _init(world: EcsWorld = null) -> void:
	if world != null:
		attach(world)

func attach(world: EcsWorld) -> bool:
	if world == null or world.is_disposed():
		return false
	detach()
	_world_ref = weakref(world)
	world.entity_destroyed.connect(_on_entity_destroyed)
	world.cleared.connect(clear)
	world.disposed.connect(detach)
	return true

func detach() -> void:
	var world := _world()
	if world != null:
		for connection: Array in [[&"entity_destroyed", _on_entity_destroyed], [&"cleared", clear], [&"disposed", detach]]:
			if world.is_connected(connection[0], connection[1]):
				world.disconnect(connection[0], connection[1])
	_world_ref = null
	clear()

func clear() -> void:
	_links.clear()
	_inverse.clear()
	last_error = ""

func add(source: int, key: StringName, target: int, policy: int = REMOVE_LINK) -> bool:
	last_error = ""
	if key.is_empty() or policy < REMOVE_LINK or policy > RESTRICT or not _valid(source) or not _valid(target):
		last_error = "A relation requires live entities, a key and a valid policy"
		return false
	if _links.has(source) and _links[source].has(key) and _links[source][key].has(target):
		last_error = "Relation already exists"
		return false
	_insert(source, key, target, policy)
	return true

## Replaces all targets for this source/key only after validating the new link.
func set_targets(source: int, key: StringName, targets: Array, policy: int = REMOVE_LINK) -> bool:
	if key.is_empty() or policy < REMOVE_LINK or policy > RESTRICT or not _valid(source):
		last_error = "A relation requires live entities, a key and a valid policy"
		return false
	var unique: Dictionary = {}
	for target: Variant in targets:
		if target is not int or not _valid(target) or unique.has(target):
			last_error = "Relation targets must be distinct live entity IDs"
			return false
		unique[target] = true
	remove(source, key)
	for target: int in unique:
		_insert(source, key, target, policy)
	last_error = ""
	return true

## target=-1 removes all targets for the selected source/key.
func remove(source: int, key: StringName, target: int = -1) -> bool:
	if not _links.has(source) or not _links[source].has(key):
		return false
	var targets: Array = _links[source][key].keys() if target < 0 else [target]
	var removed := false
	for selected: int in targets:
		if not _links[source][key].erase(selected):
			continue
		removed = true
		_inverse[selected][source].erase(key)
		if _inverse[selected][source].is_empty():
			_inverse[selected].erase(source)
		if _inverse[selected].is_empty():
			_inverse.erase(selected)
	if _links[source][key].is_empty():
		_links[source].erase(key)
	if _links[source].is_empty():
		_links.erase(source)
	return removed

func get_targets(source: int, key: StringName) -> Array[int]:
	var result: Array[int] = []
	if _valid(source) and _links.has(source) and _links[source].has(key):
		for target: int in _links[source][key]:
			if _valid(target):
				result.append(target)
	result.sort()
	return result

func get_sources(target: int, key: StringName = &"") -> Array[int]:
	var result: Array[int] = []
	if _valid(target) and _inverse.has(target):
		for source: int in _inverse[target]:
			if _valid(source) and (key.is_empty() or _inverse[target][source].has(key)):
				result.append(source)
	result.sort()
	return result

func query(key: StringName, target: int = -1) -> Array[int]:
	if target >= 0:
		return get_sources(target, key)
	var result: Array[int] = []
	for source: int in _links:
		if not get_targets(source, key).is_empty():
			result.append(source)
	result.sort()
	return result

func can_destroy(entity: int) -> bool:
	if not _inverse.has(entity):
		return true
	for source: int in _inverse[entity]:
		if not _valid(source):
			continue
		for key: StringName in _inverse[entity][source]:
			if _inverse[entity][source][key] == RESTRICT:
				return false
	return true

func capture() -> Dictionary:
	var result: Array[Dictionary] = []
	var world := _world()
	if world != null:
		for source: int in _links:
			for key: StringName in _links[source]:
				for target: int in _links[source][key]:
					if _valid(source) and _valid(target):
						result.append({"source_uid": world.get_entity_uid(source), "target_uid": world.get_entity_uid(target), "key": key, "policy": _links[source][key][target]})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left.source_uid != right.source_uid:
			return left.source_uid < right.source_uid
		if left.key != right.key:
			return String(left.key) < String(right.key)
		return left.target_uid < right.target_uid
	)
	return {"version": 1, "links": result}

func restore(data: Dictionary, _id_map: Dictionary = {}) -> bool:
	var world := _world()
	if world == null or not validate_snapshot(data):
		last_error = "Invalid relation snapshot or missing world"
		return false
	var resolved: Array[Dictionary] = []
	for link: Dictionary in data.links:
		var source: int = world.get_entity_by_uid(link.source_uid)
		var target: int = world.get_entity_by_uid(link.target_uid)
		if not _valid(source) or not _valid(target):
			last_error = "Relation snapshot references an unknown entity UID"
			return false
		resolved.append({"source": source, "target": target, "key": StringName(link.key), "policy": link.policy})
	clear()
	for link in resolved:
		_insert(link.source, link.key, link.target, link.policy)
	return true

static func validate_snapshot(data: Dictionary, entity_uids: Array[int] = []) -> bool:
	if data.size() != 2 or data.get("version") is not int or data.version != 1 or data.get("links") is not Array:
		return false
	var seen: Dictionary = {}
	for link: Variant in data.links:
		if link is not Dictionary or link.size() != 4 or link.get("source_uid") is not int or link.get("target_uid") is not int or link.get("policy") is not int:
			return false
		if link.source_uid < 1 or link.target_uid < 1 or link.policy < REMOVE_LINK or link.policy > RESTRICT:
			return false
		if (link.get("key") is not String and link.get("key") is not StringName) or String(link.key).is_empty():
			return false
		if not entity_uids.is_empty() and (not entity_uids.has(link.source_uid) or not entity_uids.has(link.target_uid)):
			return false
		var token := "%d:%d:%s:%d" % [link.source_uid, String(link.key).length(), link.key, link.target_uid]
		if seen.has(token):
			return false
		seen[token] = true
	return true

func _insert(source: int, key: StringName, target: int, policy: int) -> void:
	if not _links.has(source):
		_links[source] = {}
	if not _links[source].has(key):
		_links[source][key] = {}
	_links[source][key][target] = policy
	if not _inverse.has(target):
		_inverse[target] = {}
	if not _inverse[target].has(source):
		_inverse[target][source] = {}
	_inverse[target][source][key] = policy

func _on_entity_destroyed(entity: int) -> void:
	var cascades: Array[int] = []
	if _inverse.has(entity):
		var incoming: Dictionary = _inverse[entity].duplicate(true)
		for source: int in incoming:
			for key: StringName in incoming[source]:
				if incoming[source][key] == DESTROY_SOURCE and not cascades.has(source):
					cascades.append(source)
				remove(source, key, entity)
	if _links.has(entity):
		for key: StringName in _links[entity].keys():
			remove(entity, key)
	var world := _world()
	if world != null and not cascades.is_empty():
		cascades.sort()
		world._begin_iteration()
		for source in cascades:
			if _valid(source):
				world.destroy_entity(source)
		world._end_iteration()

func _world() -> EcsWorld:
	return null if _world_ref == null else _world_ref.get_ref() as EcsWorld

func _valid(entity: int) -> bool:
	var world := _world()
	return world != null and world.is_entity_alive(entity) and not world.is_entity_pending_destroy(entity)
