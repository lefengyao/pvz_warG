extends SceneTree

class RecordingSystem extends EcsSystem:
	var records: Array[String]
	var label: String
	var update_action: Callable
	var start_action: Callable
	var stop_action: Callable
	func _init(target: Array[String], system_label: String) -> void:
		records = target
		label = system_label
	func on_start() -> void:
		records.append("start:" + label)
		if start_action.is_valid():
			start_action.call()
	func on_update(world: EcsWorld, _delta: float) -> void:
		records.append(label)
		if update_action.is_valid():
			update_action.call(world)
	func on_stop() -> void:
		records.append("stop:" + label)
		if stop_action.is_valid():
			stop_action.call()
	func on_detach() -> void:
		records.append("detach:" + label)

var _failures := 0
var _checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_query_ownership()
	var world := ECSmini.create_world()
	for method: StringName in [&"clear", &"dispose", &"is_disposed", &"register_component", &"get_debug_snapshot", &"set_system_priority", &"tick_phase"]:
		_check(world.has_method(method), "Missing public API: " + String(method))
	if _failures > 0:
		quit(1)
		return
	world.call("dispose")
	_test_entity_and_query_contract()
	_test_commands()
	_test_world_lifecycle()
	_test_validation()
	_test_schedule()
	await _test_runner()
	await _test_split_runner()
	_test_dispose_notifications()
	_test_lifecycle_reentrancy()
	_test_callback_commands()
	_test_reregistered_schedule()
	await _test_runner_exit_during_start()
	print("core_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)

func _test_query_ownership() -> void:
	var world: EcsWorld = ECSmini.create_world()
	var reference: WeakRef = weakref(world)
	var query: EcsQuery = world.query()
	query.entities()
	query = null
	world = null
	_check(reference.get_ref() == null, "Cached queries must not retain the world")
	var retained: EcsWorld = reference.get_ref()
	if retained != null:
		retained._queries.clear()

func _test_entity_and_query_contract() -> void:
	var world := ECSmini.create_world()
	var entity := world.create_entity()
	_check(world.add_component(entity, &"health", 100), "Add component")
	_check(not world.add_component(entity, &"health", 0), "Reject duplicate component")
	world.add_component(entity, &"zombie")
	var query := world.query({"all": [&"health"], "any": [&"plant", &"zombie"], "none": [&"dead"]})
	_check(query.entities() == [entity], "all/any/none matching")
	var copy := query.entities()
	copy.clear()
	_check(query.entities() == [entity], "External mutation cannot corrupt query")
	var refreshes: int = query.get("refresh_count")
	world.add_component(entity, &"unrelated", 1)
	query.entities()
	_check(query.get("refresh_count") == refreshes, "Unrelated components do not rebuild query")
	world.set_component(entity, &"health", 90)
	query.entities()
	_check(query.get("refresh_count") == refreshes, "Value changes do not rebuild query")
	world.add_component(entity, &"dead")
	_check(query.entities().is_empty(), "Relevant structural change invalidates query")
	world.destroy_entity(entity)
	var replacement := world.create_entity()
	_check(not world.is_entity_alive(entity) and replacement != entity, "Old generation ID is invalid")
	world.call("clear")
	var after_clear := world.create_entity()
	_check(after_clear != replacement and not world.is_entity_alive(replacement), "Clear does not resurrect IDs")
	world.call("dispose")
	_check(query.entities().is_empty(), "Queries are empty after disposal")

func _test_commands() -> void:
	var world := ECSmini.create_world()
	var entity := world.create_entity()
	world.add_component(entity, &"health", 100)
	world.query().for_each(func(entity_id: int) -> void:
		_check(world.remove_component(entity_id, &"health"), "Queue removal")
		_check(not world.remove_component(entity_id, &"health"), "Reject duplicate pending removal")
		_check(world.add_component(entity_id, &"health", 50), "Queue replacement after removal")
		_check(not world.add_component(entity_id, &"health", 60), "Reject duplicate pending addition")
		_check(world.set_component(entity_id, &"health", 25), "Set follows queued replacement")
		_check(world.get_component(entity_id, &"health") == 100, "Structural reads remain committed")
	)
	_check(world.get_component(entity, &"health") == 25, "FIFO remove/add/set commit")
	world.query().for_each(func(entity_id: int) -> void:
		_check(world.destroy_entity(entity_id), "Queue destruction")
		_check(not world.destroy_entity(entity_id), "Reject duplicate pending destruction")
		_check(world.call("is_entity_pending_destroy", entity_id), "Pending destruction is observable")
		_check(not world.add_component(entity_id, &"late"), "Reject add after destruction request")
		_check(not world.set_component(entity_id, &"health", 0), "Reject write after destruction request")
		_check(world.query().entities().is_empty(), "Pending destruction excluded from queries")
	)
	_check(world.entity_count() == 0, "Destruction commits at boundary")
	world.call("dispose")

func _test_world_lifecycle() -> void:
	var world := ECSmini.create_world()
	var records: Array[String] = []
	var system := RecordingSystem.new(records, "one")
	world.add_system(system)
	var entity := world.create_entity()
	world.add_component(entity, &"tag")
	world.tick(0.1)
	world.query().for_each(func(_entity_id: int) -> void: world.call("clear"))
	_check(world.entity_count() == 0, "Clear is safe during iteration")
	records.clear()
	world.tick(0.1)
	_check(records == ["one"], "Clear retains configured systems")
	entity = world.create_entity()
	world.query().for_each(func(_entity_id: int) -> void: world.call("dispose"))
	_check(world.call("is_disposed"), "Dispose deferred to safe boundary")
	_check(records.has("stop:one") and records.has("detach:one"), "Dispose stops and detaches systems")
	_check(world.create_entity() == -1, "Disposed world rejects entity creation")
	records.clear()
	world.tick(0.1)
	_check(records.is_empty(), "Disposed world cannot restart")
	world.call("dispose")

func _test_validation() -> void:
	var world := ECSmini.create_world()
	world.set("validation_enabled", true)
	world.set("require_registered_components", true)
	_check(world.call("register_component", &"health", TYPE_INT, func(value: Variant) -> bool: return int(value) >= 0), "Register schema")
	var entity := world.create_entity()
	_check(not world.add_component(entity, &"typo", 1), "Reject unknown schema in strict mode")
	_check(not world.add_component(entity, &"health", "100"), "Reject wrong value type")
	_check(not world.add_component(entity, &"health", -1), "Reject failed custom validator")
	_check(world.add_component(entity, &"health", 100), "Accept schema value")
	_check(not world.set_component(entity, &"health", "bad"), "Validate replacement")
	_check(world.get_component(entity, &"health") == 100, "Rejected replacement preserves value")
	var snapshot: Dictionary = world.call("get_debug_snapshot", 1)
	_check(snapshot.get("entity_count") == 1, "Snapshot counts entities")
	_check(snapshot.get("entities", []).size() == 1, "Snapshot includes component data")
	world.call("dispose")

func _test_schedule() -> void:
	var world := ECSmini.create_world()
	var records: Array[String] = []
	var first := RecordingSystem.new(records, "first")
	var second := RecordingSystem.new(records, "second")
	var presentation := RecordingSystem.new(records, "present")
	presentation.set("phase", 1)
	presentation.priority = -100
	world.add_system(first)
	world.add_system(second)
	world.add_system(presentation)
	world.start()
	records.clear()
	world.tick(0.1)
	_check(records == ["first", "second", "present"], "Phase/priority/registration order")
	world.call("set_system_priority", second, -1)
	first.set("enabled", false)
	records.clear()
	world.call("tick_phase", 0.1, 0)
	_check(records == ["second"], "Disable and reorder simulation systems")
	records.clear()
	world.call("tick_phase", 0.1, 1)
	_check(records == ["present"], "Presentation phase runs separately")
	first.set("enabled", true)
	second.update_action = func(active_world: EcsWorld) -> void: active_world.remove_system(first)
	records.clear()
	world.tick(0.1)
	_check(not records.has("first"), "Removed system skipped in old schedule")
	world.call("dispose")

func _test_runner() -> void:
	var runner := EcsRunner.new()
	var records: Array[String] = []
	var system := RecordingSystem.new(records, "runner")
	runner.add_system(system)
	root.add_child(runner)
	await process_frame
	await process_frame
	_check(records.has("runner"), "Runner advances world")
	runner.use_physics_process = true
	_check(runner.is_physics_processing() and not runner.is_processing(), "Runtime clock switching")
	root.remove_child(runner)
	records.clear()
	root.add_child(runner)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	_check(records.has("start:runner") and records.has("runner"), "Runner re-entry restarts world")
	runner.set("enabled", false)
	records.clear()
	await physics_frame
	await process_frame
	_check(not records.has("runner"), "Disabled runner pauses updates")
	var world: EcsWorld = runner.world
	runner.queue_free()
	await process_frame
	_check(world.call("is_disposed"), "Runner destruction disposes owned world")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)

func _test_split_runner() -> void:
	var runner := EcsRunner.new()
	runner.separate_presentation = true
	var records: Array[String] = []
	var simulation := RecordingSystem.new(records, "simulation")
	var presentation := RecordingSystem.new(records, "presentation")
	presentation.set("phase", 1)
	runner.add_system(simulation)
	runner.add_system(presentation)
	root.add_child(runner)
	_check(runner.is_processing() and runner.is_physics_processing(), "Split mode enables both clocks independently")
	records.clear()
	runner._process(0.1)
	_check(records == ["presentation"], "Render clock updates presentation only")
	records.clear()
	runner._physics_process(0.1)
	_check(records == ["simulation"], "Physics clock updates simulation only")
	runner.queue_free()
	await process_frame

func _test_dispose_notifications() -> void:
	var world := ECSmini.create_world()
	var creation_results: Array[int] = []
	world.cleared.connect(func() -> void: creation_results.append(world.create_entity()))
	world.create_entity()
	world.dispose()
	_check(creation_results == [-1], "Dispose rejects creation from cleared callback")
	_check(world.entity_count() == 0, "Disposed world contains no callback-created entities")

func _test_lifecycle_reentrancy() -> void:
	var world := ECSmini.create_world()
	var records: Array[String] = []
	var first := RecordingSystem.new(records, "first")
	var second := RecordingSystem.new(records, "second")
	first.start_action = world.stop
	world.add_system(first)
	world.add_system(second)
	world.start()
	_check(records == ["start:first", "stop:first"], "Stop during start cancels remaining starts")
	_check(world._started_systems.is_empty(), "Cancelled startup leaves no started systems")
	first.start_action = Callable()
	world.start()
	second.stop_action = world.start
	records.clear()
	world.stop()
	_check(not world._started and world._started_systems.is_empty(), "Start during stop cannot partially restart")
	second.stop_action = Callable()
	first.start_action = world.tick.bind(0.1)
	records.clear()
	world.start()
	_check(records == ["start:first", "start:second"], "Nested tick cannot update systems before startup finishes")
	first.start_action = Callable()
	world.dispose()

func _test_callback_commands() -> void:
	var world := ECSmini.create_world()
	world.cleared.connect(world.dispose, CONNECT_ONE_SHOT)
	world.clear()
	_check(world.is_disposed(), "Dispose requested by clear callback completes at same boundary")
	world = ECSmini.create_world()
	var created: Array[int] = []
	world.cleared.connect(_create_after_clear.bind(world, created), CONNECT_ONE_SHOT)
	world.clear()
	_check(created.size() == 1 and world.get_component(created[0], &"health") == 100, "Clear callback component writes commit before returning")
	var records: Array[String] = []
	var system := RecordingSystem.new(records, "stop_writer")
	system.update_action = func(active_world: EcsWorld) -> void: active_world.stop()
	system.stop_action = world.add_component.bind(created[0], &"stopped")
	world.add_system(system)
	world.tick(0.1)
	_check(world.has_component(created[0], &"stopped"), "Stop callback component writes commit at tick boundary")
	_check(world.get_debug_snapshot().pending_command_count == 0, "Boundary leaves no callback-generated commands pending")
	system.stop_action = Callable()
	var clear_events: Array[int] = []
	world.cleared.connect(_request_recursive_clear.bind(world, clear_events))
	world.clear()
	_check(clear_events.size() == 1, "Recursive clear notification does not clear twice")
	world.dispose()

func _create_after_clear(world: EcsWorld, created: Array[int]) -> void:
	var entity := world.create_entity()
	created.append(entity)
	world.add_component(entity, &"health", 100)

func _request_recursive_clear(world: EcsWorld, events: Array[int]) -> void:
	events.append(1)
	if events.size() < 2:
		world.clear()

func _test_reregistered_schedule() -> void:
	var world := ECSmini.create_world()
	var records: Array[String] = []
	var first := RecordingSystem.new(records, "first")
	var second := RecordingSystem.new(records, "second")
	var third := RecordingSystem.new(records, "third")
	world.add_system(first)
	world.add_system(second)
	world.add_system(third)
	world.start()
	first.update_action = _reregister_system.bind(second)
	records.clear()
	world.tick(0.1)
	_check(not records.has("second") and records.has("third"), "Re-registered system skips old schedule entry")
	first.update_action = Callable()
	records.clear()
	world.tick(0.1)
	_check(records == ["first", "third", "second"], "Re-registered priority takes effect next tick")
	world.dispose()

func _reregister_system(world: EcsWorld, system: EcsSystem) -> void:
	world.remove_system(system)
	system.priority = 100
	world.add_system(system)

func _test_runner_exit_during_start() -> void:
	var runner := EcsRunner.new()
	var records: Array[String] = []
	var system := RecordingSystem.new(records, "exiting")
	runner.add_system(system)
	root.add_child(runner)
	runner.world.stop()
	runner._running = false
	system.start_action = root.remove_child.bind(runner)
	records.clear()
	runner._start_world()
	_check(not runner.is_inside_tree() and not runner._running, "Runner exits cleanly during on_start")
	_check(records == ["start:exiting", "stop:exiting"], "Runner exit during start stops world")
	system.start_action = Callable()
	runner.free()
	await process_frame
