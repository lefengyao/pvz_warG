class_name EcsChangeJournal
extends RefCounted

## Bounded ring; every reader owns its own cursor and sees explicit history loss.
var capacity: int = 1024:
	set(value):
		capacity = maxi(1, value)
		reset()
var sequence: int = 0
var epoch: int = 0
var _records: Array[Dictionary] = []
var _head: int = 0

func append(record: Dictionary) -> Dictionary:
	sequence += 1
	var entry := record.duplicate(true)
	entry["sequence"] = sequence
	if _records.size() < capacity:
		_records.append(entry)
	else:
		_records[_head] = entry
		_head = (_head + 1) % capacity
	return entry

func records_since(cursor: int, reader_epoch: int) -> Dictionary:
	var reset_required := reader_epoch != epoch
	var oldest := sequence - _records.size() + 1
	var overflow := not reset_required and cursor < oldest - 1
	var changes: Array[Dictionary] = []
	for offset in _records.size():
		var entry := _records[(_head + offset) % _records.size()]
		if reset_required or entry.sequence > cursor:
			changes.append(entry.duplicate(true))
	return {"changes": changes, "overflow": overflow, "reset": reset_required, "unavailable": false, "sequence": sequence, "epoch": epoch, "missed": maxi(0, oldest - cursor - 1) if overflow else 0}

func reset() -> void:
	_records.clear()
	_head = 0
	sequence = 0
	epoch += 1
