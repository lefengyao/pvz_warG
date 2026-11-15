extends SceneTree

class OrderedSystem extends EcsSystem:
	var output: Array[String]
	var label: String
	func _init(records: Array[String], name_value: String) -> void:
		output = records
		label = name_value
	func on_update(_world: EcsWorld, _delta: float) -> void:
		output.append(label)

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := EcsWorld.new()
	for method in [&"get_entity_uid", &"get_entity_by_uid", &"create_change_reader", &"mark_component_changed", &"write_batch", &"set_storage_backend", &"validate_schedule", &"get_execution_batches", &"get_trace", &"begin_restore", &"end_restore", &"export_metadata", &"restore_metadata"]:
		_check(world.has_method(method), "Missing advanced core API: " + String(method))
	world.dispose()
	if _failures > 0:
		_finish()
		return
	_test_persistent_ids()
	_test_incremental_query()
	_test_change_readers()
	_test_scheduler()
	_test_batch_and_trace()
	_test_backends_and_restore_bindings()
	_test_worker_guards()
	_test_deferred_trace()
	await _test_step()
	_finish()

func _test_persistent_ids() -> void:
	var world := EcsWorld.new()
	var first: int = world.call("create_entity", 42)
	_check(world.call("get_entity_uid", first) == 42, "Explicit persistent UID")
	_check(world.call("get_entity_by_uid", 42) == first, "UID resolves runtime handle")
	_check(world.call("create_entity", 42) == -1, "Duplicate live UID rejected")
	world.destroy_entity(first)
	var replacement: int = world.call("create_entity", 42)
	_check(replacement != first and not world.is_entity_alive(first), "Reused UID receives fresh generation")
	world.dispose()

func _test_incremental_query() -> void:
	var world := EcsWorld.new()
	for index in 1000:
		world.add_component(world.create_entity(), &"health", index)
	var query := world.query({"all": [&"health"], "none": [&"dead"]})
	_check(query.count() == 1000, "Initial membership")
	var checks_before: int = query.get("candidate_checks")
	var entity := world.get_entities()[200]
	world.add_component(entity, &"dead")
	_check(query.count() == 999, "Single entity membership update")
	_check(int(query.get("candidate_checks")) - checks_before == 1, "Incremental refresh checks only affected entity")
	var refreshes := query.refresh_count
	world.set_component(entity, &"health", 25)
	query.count()
	_check(query.refresh_count == refreshes, "Value changes do not rebuild membership")
	var visited: Array[int] = []
	query.for_each(func(active_entity: int) -> void:
		visited.append(active_entity)
		if visited.size() == 1:
			world.add_component(world.create_entity(), &"health", 7)
			query.count()
	)
	_check(visited.size() == 999 and query.count() == 1000, "Nested refresh preserves outer traversal")
	world.dispose()

func _test_change_readers() -> void:
	var world := EcsWorld.new()
	var reader: RefCounted = world.call("create_change_reader", [&"health"])
	var second: RefCounted = world.call("create_change_reader", [&"health"])
	var entity := world.create_entity()
	world.add_component(entity, &"health", 100)
	world.set_component(entity, &"health", 80)
	var first_report: Dictionary = reader.call("read")
	var second_report: Dictionary = second.call("read")
	_check(first_report.changes.size() == 2 and second_report.changes.size() == 2, "Readers have independent cursors")
	_check(reader.call("read").changes.is_empty(), "Reader consumes only its own cursor")
	world.call("mark_component_changed", entity, &"health")
	_check(reader.call("read").changes[0].op == &"touch", "Explicit mutable-value touch is observable")
	world.set("change_capacity", 2)
	for value in 5:
		world.set_component(entity, &"health", value)
	var overflow: Dictionary = second.call("read")
	_check(overflow.overflow or overflow.reset, "Bounded history loss is explicit")
	world.dispose()
	_check(reader.call("read").unavailable, "Reader handles disposed world")

func _test_scheduler() -> void:
	var world := EcsWorld.new()
	var records: Array[String] = []
	var movement := OrderedSystem.new(records, "move")
	var damage := OrderedSystem.new(records, "damage")
	var death := OrderedSystem.new(records, "death")
	movement.set("schedule_key", &"move")
	damage.set("schedule_key", &"damage")
	death.set("schedule_key", &"death")
	damage.set("after", [&"move"])
	death.set("after", [&"damage"])
	world.add_system(death)
	world.add_system(damage)
	world.add_system(movement)
	_check(world.call("validate_schedule"), "Explicit dependency graph validates")
	world.tick(0.1)
	_check(records == ["move", "damage", "death"], "Topological order overrides registration")
	movement.set("after", [&"death"])
	_check(not world.call("validate_schedule"), "Dependency cycles reject schedule")
	records.clear()
	world.tick(0.1)
	_check(records.is_empty(), "Invalid schedule does not execute systems")
	movement.set("after", [])
	death.set("after", [&"absent"])
	_check(not world.call("validate_schedule"), "Missing dependency is explicit")
	death.set("after", [&"damage"])
	movement.set("writes", [&"position"])
	damage.set("reads", [&"position"])
	_check(world.call("get_execution_batches").size() == 3, "Dependency stages exposed")
	world.dispose()

func _test_batch_and_trace() -> void:
	var world := EcsWorld.new()
	var entities: Array[int] = [world.create_entity(), world.create_entity()]
	for entity in entities:
		world.add_component(entity, &"health", 100)
	world.set("trace_enabled", true)
	world.set("trace_capacity", 2)
	_check(world.call("write_batch", &"health", entities, [25, 50]), "Aligned batch update")
	_check(world.get_component(entities[1], &"health") == 50, "Batch commits values")
	_check(not world.call("write_batch", &"health", [entities[0], -1], [0, 0]), "Invalid batch rejected atomically")
	_check(world.get_component(entities[0], &"health") == 25, "Invalid batch preserves earlier values")
	world.set_component(entities[0], &"health", 12)
	_check(world.call("get_trace").size() == 2, "Trace retention is bounded")
	var metadata: Dictionary = world.call("export_metadata")
	world.tick_phase(0.5, EcsSystem.Phase.PRESENTATION)
	_check(world.call("export_metadata").simulation_tick == metadata.simulation_tick, "Presentation does not advance simulation clock")
	world.tick_phase(0.5, EcsSystem.Phase.SIMULATION)
	_check(world.call("export_metadata").simulation_tick == metadata.simulation_tick + 1, "Simulation advances tracked clock")
	world.dispose()

func _test_step() -> void:
	var runner := EcsRunner.new()
	root.add_child(runner)
	runner.enabled = false
	_check(runner.has_method("step"), "Explicit single-step API")
	if runner.has_method("step"):
		var previous: int = runner.world.call("export_metadata").simulation_tick
		_check(runner.call("step", 0.1), "Paused runner can step")
		_check(runner.world.call("export_metadata").simulation_tick == previous + 1, "Step advances exactly one simulation tick")
	runner.free()
	await process_frame

func _test_backends_and_restore_bindings() -> void:
	for backend: EcsStorage in [EcsSparseStorage.new(), EcsArchetypeStorage.new(16)]:
		var world := ECSmini.create_world(backend)
		_check(world != null, "World accepts empty isolated backend")
		var other := EcsWorld.new()
		_check(not other.set_storage_backend(backend), "Backend cannot be shared between worlds")
		var sync2 := EcsNodeSync.new(world)
		var sync3 := EcsNodeSync3D.new(world)
		var node2 := Node2D.new()
		var node3 := Node3D.new()
		var entity := world.create_entity(10)
		world.add_component(entity, &"position", Vector2.ONE)
		world.add_component(entity, &"velocity", Vector2.RIGHT)
		world.add_component(entity, &"position3d", Vector3.ONE)
		world.add_component(entity, &"velocity3d", Vector3.UP)
		sync2.bind(entity, node2)
		sync3.bind(entity, node3)
		world.add_system(EcsMovementSystem.new())
		world.add_system(EcsMovement3DSystem.new())
		var snapshot := EcsSnapshot.capture(world)
		_check(snapshot.ok, "Backend snapshot captures")
		world.tick(0.5)
		_check(world.get_component(entity, &"position") == Vector2(1.5, 1.0), "Backend batch movement2d")
		_check(world.get_component(entity, &"position3d") == Vector3(1.0, 1.5, 1.0), "Backend batch movement3d")
		_check(EcsSnapshot.restore(world, snapshot.snapshot).ok, "Backend snapshot restores")
		var replacement := world.get_entity_by_uid(10)
		_check(replacement != entity and sync2.get_entity(node2) == replacement and sync3.get_entity(node3) == replacement, "Visual bindings survive fresh handles through stable UID")
		_check(EcsSnapshot.restore(world, snapshot.snapshot).ok, "Repeated restore succeeds")
		_check(sync2.get_entity(node2) == world.get_entity_by_uid(10), "Bindings remap across multiple generations")
		world.dispose()
		_check(other.set_storage_backend(backend), "Disposed world releases empty storage ownership")
		other.dispose()
		node2.free()
		node3.free()

func _test_worker_guards() -> void:
	var world := EcsWorld.new()
	var thread := Thread.new()
	thread.start(func() -> int: return world.create_entity())
	_check(thread.wait_to_finish() == -1 and world.entity_count() == 0, "Worker cannot mutate live world")
	world.dispose()

func _test_deferred_trace() -> void:
	var world := EcsWorld.new()
	world.trace_enabled = true
	var output: Array[String] = []
	var system := OrderedSystem.new(output, "test")
	system.schedule_key = &"producer"
	# Capture responsibility even after commands leave the system callback.
	world._current_system = system.schedule_key
	world._begin_iteration()
	var entity := world.create_entity()
	world.add_component(entity, &"health", 1)
	world._current_system = &""
	world._end_iteration()
	_check(world.get_trace().back().system == &"producer", "Deferred structural trace records responsible system")
	var reader := world.create_change_reader()
	world.query().for_each(func(_entity: int) -> void:
		_check(not EcsSnapshot.capture(world).ok, "Capture rejected during protected iteration without pending commands")
	)
	world.clear()
	_check(not reader.read().changes.is_empty(), "Clear reports committed destruction")
	world.dispose()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)

func _finish() -> void:
	print("advanced_core_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)
