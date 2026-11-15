class_name EcsScheduler
extends RefCounted

var last_error: String = ""
var order: Array[EcsSystem] = []
var batches: Array[Array] = []
var _declarations: Dictionary = {}

func clear_cache() -> void:
	order = []
	batches = []
	_declarations.clear()

func declarations_changed(systems: Array[EcsSystem]) -> bool:
	for system in systems:
		if not _declarations.has(system):
			return true
		var saved: Array = _declarations[system]
		if system.before != saved[0] or system.after != saved[1] or system.reads != saved[2] or system.writes != saved[3]:
			return true
	return false

func build(systems: Array[EcsSystem], registration: Dictionary) -> bool:
	last_error = ""
	order = []
	batches = []
	_declarations.clear()
	for system in systems:
		_declarations[system] = [system.before.duplicate(), system.after.duplicate(), system.reads.duplicate(), system.writes.duplicate()]
		for entries: Array in [system.before, system.after, system.reads, system.writes]:
			for entry: Variant in entries:
				if (entry is not String and entry is not StringName) or String(entry).is_empty():
					return _fail("System declarations require nonempty component/dependency names")
	var stable := systems.duplicate()
	stable.sort_custom(func(a: EcsSystem, b: EcsSystem) -> bool:
		if a.phase != b.phase:
			return a.phase < b.phase
		if a.priority != b.priority:
			return a.priority < b.priority
		return registration[a] < registration[b]
	)
	var keys: Dictionary = {}
	var edges: Dictionary = {}
	for system in stable:
		edges[system] = []
		if not system.schedule_key.is_empty():
			if keys.has(system.schedule_key):
				return _fail("Duplicate system key: %s" % system.schedule_key)
			keys[system.schedule_key] = system
	for system in stable:
		for key: StringName in system.after:
			if not keys.has(key):
				return _fail("Missing dependency: %s" % key)
			_link(edges, keys[key], system)
		for key: StringName in system.before:
			if not keys.has(key):
				return _fail("Missing dependency: %s" % key)
			_link(edges, system, keys[key])
	for left in stable:
		for right in stable:
			if left.phase < right.phase:
				_link(edges, left, right)
	if not _topological(stable, edges):
		return _fail("System dependency cycle or phase conflict")
	# Conflict edges follow the explicit topological order, so they cannot reverse it.
	var explicit_order := order.duplicate()
	for i in explicit_order.size():
		for j in range(i + 1, explicit_order.size()):
			if _conflicts(explicit_order[i], explicit_order[j]):
				_link(edges, explicit_order[i], explicit_order[j])
	return _topological(stable, edges)

func _topological(stable: Array[EcsSystem], edges: Dictionary) -> bool:
	var indegrees: Dictionary = {}
	for system in stable:
		indegrees[system] = 0
	for source in stable:
		for target: EcsSystem in edges[source]:
			indegrees[target] += 1
	var result: Array[EcsSystem] = []
	var stages: Array[Array] = []
	while result.size() < stable.size():
		var ready: Array[EcsSystem] = []
		for system in stable:
			if indegrees[system] == 0 and not result.has(system):
				ready.append(system)
		if ready.is_empty():
			return false
		stages.append(ready)
		for system in ready:
			result.append(system)
			for target: EcsSystem in edges[system]:
				indegrees[target] -= 1
	order = result
	batches = stages
	return true

func _link(edges: Dictionary, source: EcsSystem, target: EcsSystem) -> void:
	if not edges[source].has(target):
		edges[source].append(target)

func _conflicts(a: EcsSystem, b: EcsSystem) -> bool:
	for key in a.writes:
		if b.writes.has(key) or b.reads.has(key):
			return true
	for key in b.writes:
		if a.reads.has(key):
			return true
	return false

func _fail(message: String) -> bool:
	last_error = message
	order = []
	batches = []
	return false
