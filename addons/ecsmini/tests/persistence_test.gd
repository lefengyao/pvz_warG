extends SceneTree

const WORLD = preload("res://addons/ecsmini/runtime/ecs_world.gd")
const CODEC_PATH := "res://addons/ecsmini/runtime/persistence/ecs_variant_codec.gd"
const SNAPSHOT_PATH := "res://addons/ecsmini/runtime/persistence/ecs_snapshot.gd"
const STORE_PATH := "res://addons/ecsmini/runtime/persistence/ecs_snapshot_store.gd"
const REPLAY_PATH := "res://addons/ecsmini/runtime/persistence/ecs_replay.gd"
var _failures: Array[String] = []
var _codec: Script
var _snapshot: Script
var _checks := 0

class RandomMotion extends EcsSystem:
	func on_update(world: EcsWorld, _delta: float) -> void:
		for entity in world.query({"all": [&"score"]}).entities():
			world.set_component(entity, &"score", world.get_component(entity, &"score") + world.rng.randi_range(0, 9))

class CaptureDuringTick extends EcsSystem:
	var rejected := false
	func on_update(world: EcsWorld, _delta: float) -> void:
		rejected = not load(SNAPSHOT_PATH).capture(world).ok

class ValidationLifecycleProbe extends EcsSystem:
	var starts := 0
	func on_start() -> void:
		starts += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in [CODEC_PATH, SNAPSHOT_PATH, STORE_PATH, REPLAY_PATH]:
		if not ResourceLoader.exists(path):
			_check(false, "Missing persistence module: " + path)
	if not _failures.is_empty():
		_finish()
		return
	_codec = load(CODEC_PATH)
	_snapshot = load(SNAPSHOT_PATH)
	if _codec == null or _snapshot == null or not _codec.can_instantiate() or not _snapshot.can_instantiate():
		_check(false, "Persistence scripts must compile before correctness checks.")
		_finish()
		return
	_test_codec()
	_test_restore()
	_test_store()
	_test_replay()
	_test_extension_state()
	_test_replay_failures()
	_test_capture_unsafe()
	_test_snapshot_validator_reentrancy()
	_test_snapshot_validator_lifecycle()
	_test_digest_reference_schema_order()
	_finish()

func _test_codec() -> void:
	var values: Array = [null, true, -9223372036854775807, 9223372036854775807, 0.1234567890123456,
		"hello", &"name", Vector2(2, 3), Vector3(2, 3, 4), Vector2i(2, 3), Vector3i(2, 3, 4),
		Quaternion(0, 0, 0, 1), Color(0.2, 0.4, 0.6, 1), Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)),
		PackedByteArray([1, 255]), PackedInt32Array([-100, 100]), PackedInt64Array([9223372036854775807]),
		PackedFloat32Array([0.5]), PackedFloat64Array([0.1234567890123456]), PackedStringArray(["a", "b"]),
		PackedVector2Array([Vector2.ONE]), PackedVector3Array([Vector3.ONE]), PackedColorArray([Color.RED]),
		PackedVector4Array([Vector4.ONE]),
		{&"array": [1, 2, {"nested": true}]}]
	var encoded: Dictionary = _codec.encode(values)
	_check(encoded.ok, "Safe Variant values encode.")
	if encoded.ok:
		var wire: Variant = JSON.parse_string(JSON.stringify(encoded.value))
		var decoded: Dictionary = _codec.decode(wire)
		_check(decoded.ok and decoded.value == values, "Safe values preserve exact types and integer precision through JSON.")
	var object := RefCounted.new()
	_check(not _codec.encode(object).ok, "Object values reject.")
	_check(not _codec.encode(Callable(self, "_finish")).ok, "Callable values reject.")
	var cycle: Array = []
	cycle.append(cycle)
	_check(not _codec.encode(cycle).ok, "Cyclic arrays reject without recursion failure.")
	cycle.clear()
	var dictionary_cycle: Dictionary = {}
	dictionary_cycle.self = dictionary_cycle
	_check(not _codec.encode(dictionary_cycle).ok, "Cyclic dictionaries reject.")
	dictionary_cycle.clear()
	_check(not _codec.decode({"t": "unknown", "v": 0}).ok, "Unknown wire types reject.")
	_check(not _codec.decode({"t": "int", "v": "9223372036854775808"}).ok, "Out of range integer text rejects.")
	_check(not _codec.decode({"t": "float", "v": "000000000000f07f"}).ok, "Encoded infinity rejects.")
	var huge_float: Dictionary = _codec.encode([1.0e100])
	_check(not _codec.decode({"t": "PackedFloat32Array", "v": huge_float.value}).ok, "Packed float32 decoding rejects overflow to infinity.")

func _test_restore() -> void:
	var world: EcsWorld = WORLD.new()
	var first := world.create_entity()
	var second := world.create_entity()
	world.register_reference_component(&"target")
	world.register_reference_component(&"targets")
	world.add_component(first, &"target", second)
	world.add_component(first, &"targets", [first, second])
	world.add_component(first, &"plain", second)
	world.add_component(second, &"health", 42)
	var uid: int = world.get_entity_uid(first)
	var query := world.query({"all": [&"health"]})
	var captured: Dictionary = _snapshot.capture(world)
	_check(captured.ok, "World snapshot capture succeeds.")
	if not captured.ok:
		world.dispose()
		return
	var corrupt: Dictionary = captured.snapshot.duplicate(true)
	corrupt.entities[1].uid = corrupt.entities[0].uid
	_check(not _snapshot.restore(world, corrupt).ok and world.is_entity_alive(first), "Duplicate UID restore rejects atomically.")
	corrupt = captured.snapshot.duplicate(true)
	corrupt.version = 999
	_check(not _snapshot.restore(world, corrupt).ok and world.entity_count() == 2, "Unknown snapshot version rejects atomically.")
	corrupt = captured.snapshot.duplicate(true)
	corrupt.entities[0].components[&"object"] = RefCounted.new()
	_check(not _snapshot.restore(world, corrupt).ok and world.is_entity_alive(first), "Unsupported object snapshot rejects atomically.")
	corrupt = captured.snapshot.duplicate(true)
	corrupt.metadata.next_uid = corrupt.entities[1].uid
	_check(not _snapshot.restore(world, corrupt).ok and world.is_entity_alive(first), "UID allocator metadata cannot collide with restored entities.")
	var barrier := CaptureDuringTick.new()
	world.add_system(barrier)
	world.tick(0.0)
	_check(barrier.rejected, "Capture rejects ticking even when no pending structural commands exist.")
	world.remove_system(barrier)
	world.register_component(&"health", TYPE_INT, func(value: Variant) -> bool: return value > 0)
	corrupt = captured.snapshot.duplicate(true)
	corrupt.entities[1].components[&"health"] = -1
	_check(not _snapshot.restore(world, corrupt).ok and world.get_component(second, &"health") == 42, "Application schema rejection precedes clearing.")
	var restored: Dictionary = _snapshot.restore(world, captured.snapshot)
	_check(restored.ok, "Validated snapshot restores.")
	if restored.ok:
		var fresh: int = restored.id_map[first]
		var fresh_second: int = restored.id_map[second]
		_check(fresh != first and not world.is_entity_alive(first), "Restore invalidates old generation handles.")
		_check(world.get_entity_uid(fresh) == uid, "Restore preserves persistent UID.")
		_check(world.get_component(fresh, &"target") == fresh_second, "Explicit scalar reference remaps.")
		_check(world.get_component(fresh, &"targets") == [fresh, fresh_second], "Explicit array references remap.")
		_check(world.get_component(fresh, &"plain") == second, "Plain integer payload is never guessed as reference.")
		_check(query.count() == 1, "Existing query remains usable after restore.")
	world.dispose()

func _test_store() -> void:
	var store: RefCounted = load(STORE_PATH).new()
	var world: EcsWorld = WORLD.new()
	var entity := world.create_entity()
	world.add_component(entity, &"large", 9223372036854775807)
	var path := "user://ecsmini_persistence_contract.json"
	_check(store.save(world, path).ok, "Versioned disk save succeeds.")
	_check(store.save(world, path).ok, "Save safely replaces an existing file.")
	world.set_component(entity, &"large", 1)
	var loaded: Dictionary = store.load_into(world, path)
	_check(loaded.ok and world.get_component(world.get_entities()[0], &"large") == 9223372036854775807, "Disk load preserves int64 values.")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"format\":\"ecsmini.snapshot\",\"version\":999,\"data\":{}}")
	file.close()
	var current := world.get_entities()[0]
	_check(not store.load_into(world, path).ok and world.is_entity_alive(current), "Unknown disk version rejects before touching world.")
	var old_snapshot: Dictionary = _snapshot.capture(world).snapshot
	old_snapshot.version = 0
	_check(store.register_migration(0, func(data: Dictionary) -> Dictionary:
		data.version = 1
		return data), "Application migration callback registers.")
	var migration: Dictionary = store.migrate(old_snapshot)
	_check(migration.ok and migration.snapshot.version == 1, "Migration advances one explicit schema version.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	world.dispose()

func _test_replay() -> void:
	var world: EcsWorld = WORLD.new()
	var entity := world.create_entity()
	world.add_component(entity, &"score", 0)
	world.add_system(RandomMotion.new())
	var uid: int = world.get_entity_uid(entity)
	var replay: RefCounted = load(REPLAY_PATH).new(world, 0.125, 8)
	_check(replay.register_command(&"add", func(target: EcsWorld, payload: Dictionary) -> void:
		var id: int = target.get_entity_by_uid(payload.uid)
		target.set_component(id, &"score", target.get_component(id, &"score") + payload.amount)), "Replay command handler registers.")
	_check(replay.queue_command(1, &"add", {"uid": uid, "amount": 10}).ok, "Command input queues before target tick.")
	_check(replay.step().ok and replay.step().ok and replay.step().ok, "Fixed simulation advances.")
	var expected: String = replay.state_digest().digest
	_check(replay.rewind(0).ok and replay.replay_to(3).ok, "Replay restores checkpoint and re-simulates commands.")
	_check(replay.state_digest().digest == expected, "RNG and inputs replay to identical state digest.")
	var before: int = world.get_component(world.get_entity_by_uid(uid), &"score")
	var corrected: Dictionary = replay.rollback_and_resimulate(1, [{"tick": 1, "key": &"add", "payload": {"uid": uid, "amount": 15}}], 3)
	_check(corrected.ok and world.get_component(world.get_entity_by_uid(uid), &"score") == before + 5, "Corrected command rollback produces expected final state.")
	_check(not world.is_replaying, "Replay flag restores after resimulation.")
	var small: RefCounted = load(REPLAY_PATH).new(world, 0.125, 2)
	var original_tick: int = world.simulation_tick
	small.step()
	small.step()
	small.step()
	_check(not small.rewind(original_tick).ok, "Evicted replay checkpoint returns explicit error.")
	world.dispose()

func _test_extension_state() -> void:
	var world: EcsWorld = WORLD.new()
	var first := world.create_entity()
	var second := world.create_entity()
	world.get_relations().add(first, &"follow", second)
	world.get_events().emit_event(&"spawn", {"uid": world.get_entity_uid(second)})
	var captured: Dictionary = _snapshot.capture(world)
	var corrupt: Dictionary = captured.snapshot.duplicate(true)
	corrupt.entities.clear()
	_check(not _snapshot.restore(world, corrupt).ok and world.is_entity_alive(first), "Relations cannot reference entities absent from snapshot, including empty world.")
	corrupt = captured.snapshot.duplicate(true)
	corrupt.events.staged[0].sequence = corrupt.events.next_sequence
	_check(not _snapshot.restore(world, corrupt).ok and world.entity_count() == 2, "Corrupt event queue rejects atomically.")
	corrupt = captured.snapshot.duplicate(true)
	corrupt.entities.clear()
	corrupt.relations.links = 7
	_check(not _snapshot.restore(world, corrupt).ok and world.entity_count() == 2, "Malformed extension container returns an explicit atomic rejection.")
	var restored: Dictionary = _snapshot.restore(world, captured.snapshot)
	_check(restored.ok, "Snapshot containing relationships and staged events restores.")
	if restored.ok:
		_check(world.get_relations().get_targets(restored.id_map[first], &"follow") == [restored.id_map[second]], "Relationship restore resolves persistent UIDs.")
		_check(world.get_events().read(&"test").events.is_empty(), "Staged event remains unreadable after restore.")
		world.get_events().advance()
		_check(world.get_events().read(&"test").events.size() == 1, "Restored staged event appears on its next stage.")
	world.dispose()

func _test_replay_failures() -> void:
	var world: EcsWorld = WORLD.new()
	var entity := world.create_entity()
	world.add_component(entity, &"score", 1)
	var replay: RefCounted = load(REPLAY_PATH).new(world, 0.1, 4)
	var uid := world.get_entity_uid(entity)
	replay.register_command(&"set", func(target: EcsWorld, payload: Dictionary) -> void:
		target.set_component(target.get_entity_by_uid(payload.uid), &"score", payload.value))
	replay.register_command(&"times", func(target: EcsWorld, payload: Dictionary) -> void:
		var id: int = target.get_entity_by_uid(payload.uid)
		target.set_component(id, &"score", target.get_component(id, &"score") * payload.value))
	var payload := {"uid": uid, "value": 3}
	replay.queue_command(1, &"set", payload)
	payload.value = 99
	replay.queue_command(1, &"times", {"uid": uid, "value": 4})
	_check(replay.step().ok and world.get_component(entity, &"score") == 12, "Command payload is copied and same-tick inputs preserve FIFO order.")
	var before: String = replay.state_digest().digest
	_check(not replay.rollback_and_resimulate(1, [{"tick": 1, "key": &"missing", "payload": null}], 1).ok and replay.state_digest().digest == before, "Invalid correction rejects without changing world state.")
	replay.register_command(&"unsafe", func(target: EcsWorld, data: Dictionary) -> void:
		target.add_component(target.get_entity_by_uid(data.uid), &"object", RefCounted.new()))
	replay.queue_command(2, &"unsafe", {"uid": uid})
	_check(not replay.step().ok and replay.state_digest().get("digest", "") == before, "A command producing unsnapshotable state rolls back a failed step.")
	_check(replay.rollback_and_resimulate(1, [{"tick": 2, "key": &"set", "payload": {"uid": uid, "value": 12}}], 3).ok, "Valid corrected input can replace the previously failed command.")
	before = replay.state_digest().digest
	var history: Dictionary = replay.get_history_range()
	var failed: Dictionary = replay.rollback_and_resimulate(1, [
		{"tick": 1, "key": &"set", "payload": {"uid": uid, "value": 99}},
		{"tick": 2, "key": &"unsafe", "payload": {"uid": uid}}], 3)
	_check(not failed.ok and replay.state_digest().get("digest", "") == before and replay.get_history_range() == history, "Failed multi-step rollback restores prior final state and replay history.")
	world.dispose()

func _test_capture_unsafe() -> void:
	var world: EcsWorld = WORLD.new()
	var entity := world.create_entity()
	var cycle: Array = []
	cycle.append(cycle)
	world.add_component(entity, &"cycle", cycle)
	_check(not _snapshot.capture(world).ok and world.is_entity_alive(entity), "World capture rejects a cyclic component without copying it recursively first.")
	cycle.clear()
	world.dispose()

func _test_snapshot_validator_reentrancy() -> void:
	var world: EcsWorld = WORLD.new()
	var entity := world.create_entity()
	var attempted_entities: Array[int] = []
	world.register_component(&"probe", TYPE_INT, func(_value: Variant) -> bool:
		attempted_entities.append(world.create_entity())
		return true
	)
	world.add_component(entity, &"probe", 1)
	var captured: Dictionary = _snapshot.capture(world)
	_check(captured.ok and attempted_entities == [-1] and world.entity_count() == 1, "Snapshot validators cannot mutate the world during capture validation.")
	world.dispose()

func _test_digest_reference_schema_order() -> void:
	var first: EcsWorld = WORLD.new()
	var second: EcsWorld = WORLD.new()
	var first_entity := first.create_entity()
	var second_entity := second.create_entity()
	first.register_reference_component(&"target")
	first.register_reference_component(&"targets")
	second.register_reference_component(&"targets")
	second.register_reference_component(&"target")
	first.add_component(first_entity, &"target", first_entity)
	second.add_component(second_entity, &"target", second_entity)
	first.add_component(first_entity, &"targets", [first_entity])
	second.add_component(second_entity, &"targets", [second_entity])
	var first_digest: Dictionary = _snapshot.digest(first)
	var second_digest: Dictionary = _snapshot.digest(second)
	_check(first_digest.ok and second_digest.ok and first_digest.digest == second_digest.digest, "Equivalent state digests ignore reference registration order.")
	first.dispose()
	second.dispose()

func _test_snapshot_validator_lifecycle() -> void:
	var world: EcsWorld = WORLD.new()
	var system := ValidationLifecycleProbe.new()
	world.add_system(system)
	var entity := world.create_entity()
	world.add_component(entity, &"probe", 1)
	var removed: Array[bool] = []
	world.register_component(&"probe", TYPE_INT, func(_value: Variant) -> bool:
		world.start()
		removed.append(world.remove_system(system))
		return true
	)
	_check(_snapshot.capture(world).ok and system.starts == 0 and removed == [false], "Snapshot validation cannot start or remove systems")
	world.start()
	_check(system.starts == 1, "Schema validation leaves lifecycle registration intact")
	world.dispose()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: " + message)

func _finish() -> void:
	if _failures.is_empty():
		print("PASS: ECSmini persistence and controlled replay (%d checks)" % _checks)
	quit(0 if _failures.is_empty() else 1)
