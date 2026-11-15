extends SceneTree

class LifecycleProbe extends EcsSystem:
	var records: Array[String]
	var label: String
	var start_action: Callable
	func _init(output: Array[String], probe_label: String) -> void:
		records = output
		label = probe_label
	func on_start() -> void:
		records.append("start:" + label)
		if start_action.is_valid():
			start_action.call()
	func on_update(_world: EcsWorld, _delta: float) -> void:
		records.append("update:" + label)
	func on_stop() -> void:
		records.append("stop:" + label)

class SelfDetachingSystem extends EcsSystem:
	var detach_count := 0
	func configure(world: EcsWorld) -> void:
		world.remove_system(self)
	func on_detach() -> void:
		detach_count += 1

var _checks := 0
var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_invalid_start_recovery()
	_test_worker_lifecycle_guards()
	_test_untracked_signal_sequences()
	_test_mutable_schedule_declarations()
	_test_malformed_dependencies()
	_test_runtime_system_registration()
	_test_startup_schedule_mutation()
	_test_startup_cancellation()
	_test_registration_after_priority_change()
	_test_configure_self_detach()
	_test_scheduler_releases_systems()
	print("core_review_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)

func _test_invalid_start_recovery() -> void:
	var world := EcsWorld.new()
	var output: Array[String] = []
	var system := LifecycleProbe.new(output, "a")
	system.schedule_key = &"a"
	system.after = [&"missing"]
	world.add_system(system)
	world.start()
	_check(output.is_empty(), "Invalid schedule does not start lifecycle")
	system.after = []
	world.tick(0.1)
	_check(output == ["start:a", "update:a"], "Fixed dependency schedule starts before first update")
	world.dispose()

func _test_worker_lifecycle_guards() -> void:
	for action: StringName in [&"clear", &"dispose", &"stop"]:
		var world := EcsWorld.new()
		var output: Array[String] = []
		world.add_system(LifecycleProbe.new(output, "a"))
		world.start()
		var first := world.create_entity()
		var thread := Thread.new()
		thread.start(func() -> void: world.call(action))
		thread.wait_to_finish()
		var second := world.create_entity()
		world.tick(0.1)
		_check(second > 0 and world.is_entity_alive(first) and not world.is_disposed(), "Worker " + String(action) + " cannot schedule world lifecycle changes")
		_check(output == ["start:a", "update:a"], "Worker " + String(action) + " cannot stop owner systems")
		world.dispose()

func _test_untracked_signal_sequences() -> void:
	var world := EcsWorld.new()
	var sequences: Array[int] = []
	world.mutation_committed.connect(func(record: Dictionary) -> void: sequences.append(record.sequence))
	var entity := world.create_entity()
	world.add_component(entity, &"health", 100)
	world.set_component(entity, &"health", 50)
	_check(sequences == [1, 2, 3], "Committed signal sequences advance independently of optional change readers")
	world.change_capacity = 2
	world.set_component(entity, &"health", 25)
	_check(sequences.back() == 4, "Journal capacity reset does not restart committed signal sequence")
	world.dispose()

func _test_mutable_schedule_declarations() -> void:
	var world := EcsWorld.new()
	var output: Array[String] = []
	var first := LifecycleProbe.new(output, "a")
	var second := LifecycleProbe.new(output, "b")
	first.schedule_key = &"a"
	second.schedule_key = &"b"
	world.add_system(first)
	world.add_system(second)
	world.validate_schedule()
	first.after.append(&"b")
	world.tick(0.1)
	_check(output == ["start:b", "start:a", "update:b", "update:a"], "In-place dependency array edits update schedule")
	first.after.clear()
	first.writes.append(&"health")
	second.reads.append(&"health")
	_check(world.get_execution_batches().size() == 2, "In-place access declarations update conflict stages")
	world.dispose()

func _test_malformed_dependencies() -> void:
	var world := EcsWorld.new()
	var output: Array[String] = []
	var system := LifecycleProbe.new(output, "a")
	system.schedule_key = &"a"
	system.after = [123]
	world.add_system(system)
	_check(not world.validate_schedule() and not world.last_schedule_error.is_empty(), "Malformed dependency entries reject schedule explicitly")
	world.dispose()

func _test_runtime_system_registration() -> void:
	var world := EcsWorld.new()
	var output: Array[String] = []
	var adder := LifecycleProbe.new(output, "a")
	var dependency := LifecycleProbe.new(output, "c")
	var inserted := LifecycleProbe.new(output, "b")
	adder.schedule_key = &"a"
	dependency.schedule_key = &"c"
	inserted.schedule_key = &"b"
	inserted.after = [&"c"]
	adder.start_action = func() -> void: world.add_system(inserted)
	world.add_system(adder)
	world.add_system(dependency)
	world.start()
	_check(output == ["start:a", "start:c", "start:b"], "Systems added during startup start in the refreshed dependency order")
	world.tick(0.1)
	_check(output == ["start:a", "start:c", "start:b", "update:a", "update:c", "update:b"], "Newly attached systems update after ordered startup")
	world.dispose()

	world = EcsWorld.new()
	output = []
	var existing := LifecycleProbe.new(output, "existing")
	var late := LifecycleProbe.new(output, "late")
	existing.schedule_key = &"existing"
	late.schedule_key = &"late"
	late.after = [&"missing"]
	world.add_system(existing)
	world.start()
	_check(not world.add_system(late) and output == ["start:existing"] and world.validate_schedule(), "Late systems with invalid dependencies are rejected before their start hook")
	var before_existing := LifecycleProbe.new(output, "before_existing")
	before_existing.schedule_key = &"before_existing"
	before_existing.before = [&"existing"]
	_check(not world.add_system(before_existing) and output == ["start:existing"], "Late systems cannot reorder already-started lifecycle hooks")
	late.after = []
	_check(world.add_system(late), "Late systems with a valid schedule attach successfully")
	world.start()
	world.tick(0.1)
	_check(output == ["start:existing", "start:late", "update:existing", "update:late"], "Late systems start after a valid schedule is restored")
	world.dispose()

func _test_scheduler_releases_systems() -> void:
	var world := EcsWorld.new()
	var system: EcsSystem = EcsSystem.new()
	world.add_system(system)
	world.validate_schedule()
	var reference := weakref(system)
	world.remove_system(system)
	system = null
	_check(reference.get_ref() == null, "Removed system is released from cached scheduler graph")
	system = EcsSystem.new()
	world.add_system(system)
	world.validate_schedule()
	reference = weakref(system)
	world.dispose()
	system = null
	_check(reference.get_ref() == null, "Disposed world releases scheduler-owned systems")

func _test_startup_schedule_mutation() -> void:
	for missing_dependency in [false, true]:
		var world := EcsWorld.new()
		var output: Array[String] = []
		var first := LifecycleProbe.new(output, "a")
		var second := LifecycleProbe.new(output, "b")
		first.schedule_key = &"a"
		second.schedule_key = &"b"
		first.start_action = func() -> void:
			if missing_dependency:
				second.after = [&"missing"]
			else:
				first.after = [&"b"]
		world.add_system(first)
		world.add_system(second)
		world.tick(0.1)
		_check(output == ["start:a"], "Interrupted startup never updates an unstarted system")
		_check(world.simulation_tick == 0 and world.simulation_time == 0.0, "Interrupted startup does not advance the simulation clock")
		first.start_action = Callable()
		first.after = []
		second.after = []
		world.tick(0.1)
		_check(output == ["start:a", "start:b", "update:a", "update:b"], "Corrected startup declarations resume before updating")
		world.dispose()

func _test_registration_after_priority_change() -> void:
	var world := EcsWorld.new()
	var output: Array[String] = []
	var first := LifecycleProbe.new(output, "a")
	var second := LifecycleProbe.new(output, "b")
	var late := LifecycleProbe.new(output, "c")
	world.add_system(first)
	world.add_system(second)
	world.start()
	second.priority = -1
	_check(world.add_system(late), "Changing started systems' priorities does not reject a valid late append")
	world.tick(0.1)
	_check(output == ["start:a", "start:b", "start:c", "update:b", "update:a", "update:c"], "Dynamic priorities preserve startup and refresh update order")
	world.dispose()

func _test_startup_cancellation() -> void:
	for action: StringName in [&"stop", &"dispose"]:
		var world := EcsWorld.new()
		var output: Array[String] = []
		var system := LifecycleProbe.new(output, "a")
		system.start_action = func() -> void: world.call(action)
		world.add_system(system)
		world.tick(0.1)
		_check(world.simulation_tick == 0 and world.simulation_time == 0.0, "Startup " + String(action) + " cancels simulation clock advancement")
		_check(output == ["start:a", "stop:a"], "Startup " + String(action) + " completes cleanup without an update")
		system.start_action = Callable()
		world.dispose()

func _test_configure_self_detach() -> void:
	var world := EcsWorld.new()
	world.start()
	var system := SelfDetachingSystem.new()
	_check(not world.add_system(system), "Registration reports configure removing its own system")
	_check(system.detach_count == 1 and system._world_instance_id == 0, "Configure self-detach runs cleanup exactly once")
	world.dispose()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)
