class_name EcsEventQueue
extends RefCounted

## Events emitted during stage N are readable only after advance starts N+1.
var capacity: int = 1024
var last_error: String = ""
var _stage: int = 0
var _next_sequence: int = 1
var _reset_epoch: int = 0
var _staged: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _readers: Dictionary = {}

func _init(retention_capacity: int = 1024) -> void:
	capacity = maxi(retention_capacity, 1)

func emit_event(key: StringName, payload: Variant = null) -> bool:
	last_error = ""
	if key.is_empty() or not EcsDataCopy.is_data(payload):
		last_error = "Events require a nonempty key and copyable payload"
		return false
	if _staged.size() >= capacity:
		last_error = "Staged event capacity exceeded"
		return false
	_staged.append({"sequence": _next_sequence, "stage": _stage + 1, "key": key, "payload": EcsDataCopy.copy(payload)})
	_next_sequence += 1
	return true

func advance() -> void:
	_stage += 1
	_events.append_array(_staged)
	_staged.clear()
	if _events.size() > capacity:
		_events = _events.slice(_events.size() - capacity)

func commit_stage() -> void:
	advance()

## A filtered read still advances over all committed event keys. A new named
## reader starts with retained history; only established readers report loss.
func read(reader: StringName, key: StringName = &"") -> Dictionary:
	var first_sequence: int = _next_sequence - _staged.size() if _events.is_empty() else _events.front().sequence
	var reader_state: Dictionary = _readers.get(reader, {"cursor": first_sequence - 1, "epoch": _reset_epoch})
	var was_reset: bool = reader_state.epoch != _reset_epoch
	var cursor: int = reader_state.cursor
	if was_reset:
		cursor = first_sequence - 1
	var missed := maxi(first_sequence - cursor - 1, 0) if not _events.is_empty() else 0
	var result: Array[Dictionary] = []
	for event in _events:
		if event.sequence > cursor and (key.is_empty() or event.key == key):
			result.append(EcsDataCopy.copy(event))
	var committed_cursor: int = cursor if _events.is_empty() else _events.back().sequence
	_readers[reader] = {"cursor": committed_cursor, "epoch": _reset_epoch}
	return {"events": result, "overflow": missed > 0, "missed": missed, "reset": was_reset, "stage": _stage}

func forget_reader(reader: StringName) -> bool:
	return _readers.erase(reader)

func clear() -> void:
	_staged.clear()
	_events.clear()
	_stage = 0
	_next_sequence = 1
	_reset_epoch += 1
	for reader: StringName in _readers:
		_readers[reader].cursor = 0
	last_error = ""

func capture() -> Dictionary:
	return EcsDataCopy.copy({"version": 1, "capacity": capacity, "stage": _stage, "next_sequence": _next_sequence, "reset_epoch": _reset_epoch, "staged": _staged, "events": _events, "readers": _readers})

func restore(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		last_error = "Invalid event queue snapshot"
		return false
	capacity = data.capacity
	_stage = data.stage
	_next_sequence = data.next_sequence
	_reset_epoch = data.reset_epoch
	_staged.assign(EcsDataCopy.copy(data.staged))
	_events.assign(EcsDataCopy.copy(data.events))
	_readers = EcsDataCopy.copy(data.readers)
	last_error = ""
	return true

static func validate_snapshot(data: Dictionary) -> bool:
	if data.size() != 8:
		return false
	for field: String in ["version", "capacity", "stage", "next_sequence", "reset_epoch"]:
		if not data.has(field) or data[field] is not int:
			return false
	if data.version != 1 or data.capacity < 1 or data.stage < 0 or data.next_sequence < 1 or data.reset_epoch < 0:
		return false
	if data.get("events") is not Array or data.get("staged") is not Array or data.get("readers") is not Dictionary:
		return false
	if data.events.size() > data.capacity or data.staged.size() > data.capacity:
		return false
	var previous: int = 0
	var previous_stage: int = 0
	for field: String in ["events", "staged"]:
		for event: Variant in data[field]:
			if event is not Dictionary or event.size() != 4 or event.get("sequence") is not int or event.get("stage") is not int:
				return false
			if event.sequence <= previous or event.sequence >= data.next_sequence or event.stage < 1:
				return false
			if (previous > 0 and event.sequence != previous + 1) or event.stage < previous_stage:
				return false
			if (field == "events" and event.stage > data.stage) or (field == "staged" and event.stage != data.stage + 1):
				return false
			if (event.get("key") is not String and event.get("key") is not StringName) or String(event.key).is_empty() or not event.has("payload") or not EcsDataCopy.is_data(event.payload):
				return false
			previous = event.sequence
			previous_stage = event.stage
	if previous != data.next_sequence - 1:
		return false
	var committed_cursor: int = data.next_sequence - data.staged.size() - 1
	for reader: Variant in data.readers:
		var state: Variant = data.readers[reader]
		if (reader is not String and reader is not StringName) or state is not Dictionary or state.size() != 2 or state.get("cursor") is not int or state.get("epoch") is not int:
			return false
		if state.cursor < 0 or state.cursor > committed_cursor or state.epoch < 0 or state.epoch > data.reset_epoch:
			return false
	return true
