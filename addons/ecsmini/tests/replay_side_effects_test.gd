extends SceneTree

const WORLD = preload("res://addons/ecsmini/runtime/ecs_world.gd")
const SYSTEM = preload("res://addons/ecsmini/runtime/ecs_system.gd")
const REPLAY = preload("res://addons/ecsmini/runtime/persistence/ecs_replay.gd")

var _checks := 0
var _failures: Array[String] = []


class EventEmitter extends EcsSystem:

	var persistent_uid: int

	func on_update(world: EcsWorld, _delta: float) -> void:
		var entity := world.get_entity_by_uid(persistent_uid)
		world.get_events().emit_event(&"effect", {
			"event_id": "tick_%d" % world.simulation_tick,
			"marker": world.get_component(entity, &"marker", 0),
		})


class EventPresentation extends EcsSystem:

	var raw_sequences: Array[int] = []
	var raw_markers: Array[int] = []
	var applied_ids: Array[String] = []
	var seen_ids: Dictionary = {}
	var replay_flags: Array[bool] = []

	func on_update(world: EcsWorld, _delta: float) -> void:
		var report := world.get_events().read(&"presentation")
		replay_flags.append(world.is_replaying)
		for event: Dictionary in report.events:
			raw_sequences.append(event.sequence)
			raw_markers.append(event.payload.marker)
			var event_id := String(event.payload.event_id)
			if seen_ids.has(event_id):
				continue
			seen_ids[event_id] = true
			applied_ids.append(event_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_replay_presentation_side_effects()
	if _failures.is_empty():
		print("PASS: ECSmini replay presentation side-effect contract (%d checks)" % _checks)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
	quit(1 if not _failures.is_empty() else 0)


func _test_replay_presentation_side_effects() -> void:
	var world: EcsWorld = WORLD.new()
	var entity := world.create_entity()
	world.add_component(entity, &"marker", 0)
	var emitter := EventEmitter.new()
	emitter.persistent_uid = world.get_entity_uid(entity)
	var presentation := EventPresentation.new()
	emitter.priority = 0
	presentation.priority = 100
	presentation.phase = EcsSystem.Phase.PRESENTATION
	world.add_system(emitter)
	world.add_system(presentation)
	var replay: EcsReplay = REPLAY.new(world, 0.1, 8)
	_check(replay.register_command(&"set_marker", func(target: EcsWorld, payload: Dictionary) -> void:
		var id: int = target.get_entity_by_uid(payload.uid)
		target.set_component(id, &"marker", payload.value)), "Replay command handler registers.")
	var uid := world.get_entity_uid(entity)
	_check(replay.queue_command(2, &"set_marker", {"uid": uid, "value": 1}).ok, "Initial command queues.")
	_check(replay.step().ok and replay.step(true).ok and replay.step(true).ok, "Simulation and presentation advance.")
	_check(presentation.raw_sequences == [1, 2], "Initial presentation consumes committed events once.")
	_check(presentation.applied_ids == ["tick_1", "tick_2"], "Initial effect IDs are applied once.")
	_check(not presentation.replay_flags.has(true), "Presentation observes replay flag as false on normal ticks.")

	var before_rewind_raw := presentation.raw_sequences.size()
	_check(replay.rewind(1).ok and replay.replay_to(3, true).ok, "Rewind and replay can present the final state.")
	_check(not world.is_replaying, "Replay flag is false after rewind/replay presentation finishes.")
	_check(presentation.raw_sequences.slice(before_rewind_raw) == [1, 2], "Restored reader cursor re-reads historical effects after replay.")
	_check(presentation.applied_ids == ["tick_1", "tick_2"], "Application event ID dedupe suppresses replayed side effects.")
	_check(presentation.raw_markers.slice(before_rewind_raw) == [0, 1], "Replay preserves the original event payloads.")

	var before_correction_raw := presentation.raw_sequences.size()
	var corrected := replay.rollback_and_resimulate(2, [{
		"tick": 2,
		"key": &"set_marker",
		"payload": {"uid": uid, "value": 2},
	}], 3, true)
	_check(corrected.ok, "Corrected rollback can present the corrected final state.")
	_check(not world.is_replaying, "Replay flag is false after corrected rollback presentation.")
	_check(presentation.raw_sequences.slice(before_correction_raw) == [1, 2], "Corrected rollback also restores the reader cursor and re-reads effects.")
	_check(presentation.raw_markers.slice(before_correction_raw) == [0, 2], "Corrected rollback can re-read the same event ID with a changed payload.")
	_check(presentation.applied_ids == ["tick_1", "tick_2"], "Dedupe remains stable across corrected rollback.")

	# A consumer that must suppress every replayed effect can replay without
	# presentation, advance its real reader once, then present with no old events.
	_check(replay.rewind(1).ok and replay.replay_to(3).ok, "Rollback can finish without presenting replayed events.")
	var discard := world.get_events().read(&"presentation")
	_check(discard.events.size() == 2, "Presentation reader sees retained history before discard.")
	var raw_before_discard := presentation.raw_sequences.size()
	world.tick_phase(0.0, EcsSystem.Phase.PRESENTATION)
	_check(presentation.raw_sequences.size() == raw_before_discard, "Discarding the real reader prevents replayed effects on the next presentation.")
	world.dispose()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
