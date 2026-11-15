class_name EcsReplay
extends RefCounted

## Controlled fixed-delta simulation: all mutable system state belongs in the world.
const SNAPSHOT = preload("res://addons/ecsmini/runtime/persistence/ecs_snapshot.gd")
const CODEC = preload("res://addons/ecsmini/runtime/persistence/ecs_variant_codec.gd")
var _world_ref: WeakRef
var _fixed_delta: float
var _capacity: int
var _handlers: Dictionary = {}
var _commands: Array[Dictionary] = []
var _checkpoints: Array[Dictionary] = []
var _next_sequence := 1
var _latest_tick := 0
var _busy := false
var _initial_error := ""

func _init(world: EcsWorld, fixed_delta: float = 1.0 / 60.0, checkpoint_capacity: int = 120) -> void:
	_world_ref = weakref(world) if world != null else null
	_fixed_delta = fixed_delta
	_capacity = maxi(2, checkpoint_capacity)
	if not is_finite(fixed_delta) or fixed_delta <= 0.0 or world == null or world.is_disposed():
		_initial_error = "Replay requires a live world and positive finite fixed delta."
		return
	var captured := SNAPSHOT.capture(world)
	if not captured.ok:
		_initial_error = captured.error
		return
	_latest_tick = world.simulation_tick
	_checkpoints.append({"tick": world.simulation_tick, "snapshot": captured.snapshot})

func get_world() -> EcsWorld:
	return _world_ref.get_ref() as EcsWorld if _world_ref != null else null

func register_command(key: StringName, handler: Callable) -> bool:
	if key.is_empty() or not handler.is_valid() or _handlers.has(key) or _busy:
		return false
	_handlers[key] = handler
	return true

## Inputs target an absolute simulation tick, with FIFO sequence within that tick.
func queue_command(tick: int, key: StringName, payload: Variant = null) -> Dictionary:
	var world := get_world()
	if world == null or world.is_disposed() or _busy or not _initial_error.is_empty():
		return _error("Replay is unavailable or currently executing.")
	if tick <= world.simulation_tick or not _handlers.has(key):
		return _error("Command requires a registered handler and a future tick.")
	var copied := CODEC.copy(payload)
	if not copied.ok:
		return _error(copied.error)
	_commands.append({"tick": tick, "sequence": _next_sequence, "key": key, "payload": copied.value})
	_next_sequence += 1
	return {"ok": true, "error": "", "sequence": _next_sequence - 1}

func step(present: bool = false) -> Dictionary:
	var world := get_world()
	if world == null or world.is_disposed() or _busy or not _initial_error.is_empty():
		return _error(_initial_error if not _initial_error.is_empty() else "Replay is unavailable or already executing.")
	_busy = true
	var result := _step_simulation(world)
	_busy = false
	if result.ok and present:
		world.tick_phase(_fixed_delta, EcsSystem.Phase.PRESENTATION)
	return result

func rewind(target_tick: int, present: bool = false) -> Dictionary:
	var world := get_world()
	if world == null or world.is_disposed() or _busy or not _initial_error.is_empty():
		return _error("Replay is unavailable or already executing.")
	if _checkpoints.is_empty() or target_tick < _checkpoints[0].tick or target_tick > _latest_tick:
		return _error("Requested tick is outside retained checkpoint history.")
	var checkpoint: Dictionary = _checkpoints[0]
	for candidate: Dictionary in _checkpoints:
		if candidate.tick <= target_tick:
			checkpoint = candidate
		else:
			break
	var backup := _capture_transaction(world)
	if not backup.ok:
		return backup
	_busy = true
	var was_replaying := world.is_replaying
	world.is_replaying = true
	var result := SNAPSHOT.restore(world, checkpoint.snapshot)
	if result.ok:
		result = _replay_until(world, target_tick)
	if not result.ok:
		result = _restore_transaction(world, backup, result.error)
	world.is_replaying = was_replaying
	_busy = false
	if result.ok and present:
		world.tick_phase(_fixed_delta, EcsSystem.Phase.PRESENTATION)
	return result

func replay_to(target_tick: int, present: bool = false) -> Dictionary:
	var world := get_world()
	if world == null or world.is_disposed() or _busy or target_tick < world.simulation_tick or not _initial_error.is_empty():
		return _error("Replay target precedes current state or replay is unavailable.")
	var backup := _capture_transaction(world)
	if not backup.ok:
		return backup
	_busy = true
	var was_replaying := world.is_replaying
	world.is_replaying = true
	var result := _replay_until(world, target_tick)
	if not result.ok:
		result = _restore_transaction(world, backup, result.error)
	world.is_replaying = was_replaying
	_busy = false
	if result.ok and present:
		world.tick_phase(_fixed_delta, EcsSystem.Phase.PRESENTATION)
	return result

## Replaces commands at each supplied corrected tick, preserving all other inputs.
## An empty corrections array removes all commands at from_tick.
func rollback_and_resimulate(from_tick: int, corrections: Array, final_tick: int = -1, present: bool = false) -> Dictionary:
	var world := get_world()
	if world == null or world.is_disposed() or _busy or not _initial_error.is_empty():
		return _error("Replay is unavailable or already executing.")
	if final_tick < 0:
		final_tick = _latest_tick
	if _checkpoints.is_empty() or from_tick <= _checkpoints[0].tick or from_tick > _latest_tick or final_tick < from_tick:
		return _error("Rollback requires a retained checkpoint before the corrected tick.")
	var replacements: Array[Dictionary] = []
	var affected: Dictionary = {from_tick: true} if corrections.is_empty() else {}
	var sequence := _next_sequence
	for correction: Variant in corrections:
		if correction is not Dictionary or correction.size() != 3 or correction.get("tick") is not int or correction.get("key") is not StringName or not correction.has("payload") or correction.tick < from_tick or correction.tick > final_tick or not _handlers.has(correction.key):
			return _error("Malformed corrected input or unregistered command.")
		var copied := CODEC.copy(correction.payload)
		if not copied.ok:
			return _error(copied.error)
		affected[correction.tick] = true
		replacements.append({"tick": correction.tick, "sequence": sequence, "key": correction.key, "payload": copied.value})
		sequence += 1
	var backup := _capture_transaction(world)
	if not backup.ok:
		return backup
	var rewound := rewind(from_tick - 1)
	if not rewound.ok:
		return rewound
	var retained: Array[Dictionary] = []
	for command: Dictionary in _commands:
		if not affected.has(command.tick):
			retained.append(command)
	retained.append_array(replacements)
	_commands = retained
	_next_sequence = sequence
	for index in range(_checkpoints.size() - 1, -1, -1):
		if _checkpoints[index].tick >= from_tick:
			_checkpoints.remove_at(index)
	var result := replay_to(final_tick, present)
	return result if result.ok else _restore_transaction(world, backup, result.error)

func state_digest() -> Dictionary:
	return SNAPSHOT.digest(get_world())

func get_history_range() -> Dictionary:
	return {"oldest_tick": _checkpoints[0].tick if not _checkpoints.is_empty() else -1, "latest_tick": _latest_tick, "checkpoint_count": _checkpoints.size(), "capacity": _capacity}

func _replay_until(world: EcsWorld, target_tick: int) -> Dictionary:
	while world.simulation_tick < target_tick:
		var result := _step_simulation(world)
		if not result.ok:
			return result
	return {"ok": true, "error": "", "tick": world.simulation_tick}

func _step_simulation(world: EcsWorld) -> Dictionary:
	var previous := SNAPSHOT.capture(world)
	if not previous.ok:
		return _error(previous.error)
	var next_tick := world.simulation_tick + 1
	var inputs: Array[Dictionary] = []
	for command: Dictionary in _commands:
		if command.tick == next_tick:
			inputs.append(command)
	inputs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.sequence < b.sequence)
	for command: Dictionary in inputs:
		var copied := CODEC.copy(command.payload)
		_handlers[command.key].call(world, copied.value)
	world.tick_phase(_fixed_delta, EcsSystem.Phase.SIMULATION)
	if world.simulation_tick != next_tick:
		return _restore_failed_step(world, previous.snapshot, "World refused the simulation tick or command altered its clock.")
	var captured := SNAPSHOT.capture(world)
	if not captured.ok:
		return _restore_failed_step(world, previous.snapshot, captured.error)
	for index in range(_checkpoints.size() - 1, -1, -1):
		if _checkpoints[index].tick >= next_tick:
			_checkpoints.remove_at(index)
	_checkpoints.append({"tick": next_tick, "snapshot": captured.snapshot})
	_latest_tick = maxi(_latest_tick, next_tick)
	while _checkpoints.size() > _capacity:
		_checkpoints.pop_front()
	var oldest_tick: int = _checkpoints[0].tick
	for index in range(_commands.size() - 1, -1, -1):
		if _commands[index].tick <= oldest_tick:
			_commands.remove_at(index)
	return {"ok": true, "error": "", "tick": next_tick}

func _restore_failed_step(world: EcsWorld, snapshot: Dictionary, message: String) -> Dictionary:
	var restored := SNAPSHOT.restore(world, snapshot)
	return _error(message if restored.ok else message + " Rollback failed: " + restored.error)

func _capture_transaction(world: EcsWorld) -> Dictionary:
	var captured := SNAPSHOT.capture(world)
	if not captured.ok:
		return _error(captured.error)
	# Internal checkpoint/input records are immutable; handlers receive codec copies.
	return {"ok": true, "error": "", "snapshot": captured.snapshot, "checkpoints": _checkpoints.duplicate(),
		"commands": _commands.duplicate(), "next_sequence": _next_sequence, "latest_tick": _latest_tick}

func _restore_transaction(world: EcsWorld, backup: Dictionary, message: String) -> Dictionary:
	var was_replaying := world.is_replaying
	world.is_replaying = true
	var restored := SNAPSHOT.restore(world, backup.snapshot)
	world.is_replaying = was_replaying
	_checkpoints.assign(backup.checkpoints)
	_commands.assign(backup.commands)
	_next_sequence = backup.next_sequence
	_latest_tick = backup.latest_tick
	return _error(message if restored.ok else message + " Transaction rollback failed: " + restored.error)

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
