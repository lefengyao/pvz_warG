class_name EcsChangeReader
extends RefCounted

var _world_reference: WeakRef
var _types: Array[StringName] = []
var _cursor: int = 0
var _epoch: int = 0

func _init(world: EcsWorld, types: Array[StringName] = []) -> void:
	_world_reference = weakref(world)
	_types = types.duplicate()
	_cursor = world._journal.sequence
	_epoch = world._journal.epoch

func read() -> Dictionary:
	var world := _world_reference.get_ref() as EcsWorld
	if world == null or world.is_disposed():
		return {"changes": [], "overflow": false, "reset": false, "unavailable": true, "sequence": _cursor, "epoch": _epoch, "missed": 0}
	var report := world._journal.records_since(_cursor, _epoch)
	_cursor = report.sequence
	_epoch = report.epoch
	if not _types.is_empty():
		var filtered: Array[Dictionary] = []
		for record: Dictionary in report.changes:
			if _types.has(record.key) or record.op == &"destroy":
				filtered.append(record)
		report.changes = filtered
	return report
