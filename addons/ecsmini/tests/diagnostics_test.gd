extends SceneTree

## Headless diagnostics contract. Run with --script from the project root.
const WORLD_SCRIPT = preload("res://addons/ecsmini/runtime/ecs_world.gd")
const SYSTEM_SCRIPT = preload("res://addons/ecsmini/runtime/ecs_system.gd")
const PANEL_PATH := "res://addons/ecsmini/debug/ecs_debug_panel.gd"
const CONTROL_PATH := "res://addons/ecsmini/debug/ecs_debug_controls.gd"

var _failures: Array[String] = []

class PhaseCounter extends EcsSystem:
	var updates := 0
	func on_update(world: EcsWorld, _delta: float) -> void:
		updates += 1
		for entity: int in world.query({"all": [&"health"]}).entities():
			world.set_component(entity, &"health", world.get_component(entity, &"health") - 1)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(PANEL_PATH):
		_fail("Runtime diagnostics panel is missing.")
		_finish()
		return
	var panel_script: Script = load(PANEL_PATH)
	if panel_script == null or not panel_script.can_instantiate():
		_fail("Runtime diagnostics panel cannot be instantiated.")
		_finish()
		return
	var world: EcsWorld = WORLD_SCRIPT.new()
	if not world.has_method("get_debug_snapshot"):
		_fail("World diagnostics snapshot API is missing.")
		_finish()
		return
	_test_snapshot(world)
	world.dispose()
	if not ResourceLoader.exists(CONTROL_PATH):
		_fail("Single-step diagnostics controls are missing.")
		_finish()
		return
	await _test_panel(panel_script)
	await _test_runner_binding(panel_script)
	await _test_controls(panel_script)
	_finish()


func _test_snapshot(world: EcsWorld) -> void:
	var first := world.create_entity()
	var second := world.create_entity()
	world.add_component(first, &"health", 42)
	world.add_component(second, &"health", 7)
	world.add_component(second, &"position", Vector2(2, 3))
	var system: EcsSystem = SYSTEM_SCRIPT.new()
	system.priority = 23
	world.add_system(system)
	world.query({"all": [&"health"]}).count()
	var snapshot: Dictionary = world.call("get_debug_snapshot", 1)
	for key in ["entity_count", "component_counts", "entities", "systems", "query_count", "pending_command_count", "last_tick_usec", "disposed"]:
		_check(snapshot.has(key), "Snapshot contains %s." % key)
	_check(snapshot.get("entity_count") == 2, "Entity total is not limited by the preview cap.")
	_check(snapshot.get("component_counts", {}).get(&"health") == 2, "Component counts reflect all entities.")
	var entities: Array = snapshot.get("entities", [])
	_check(entities.size() == 1, "Entity previews respect the requested cap.")
	if entities.size() == 1:
		_check(entities[0].get("id") == mini(first, second), "Entity previews use deterministic ID order.")
		_check(entities[0].get("components", {}).get(&"health") == 42, "Entity previews include readable component values.")
	var systems: Array = snapshot.get("systems", [])
	_check(systems.size() == 1, "Registered systems appear in diagnostics.")
	if systems.size() == 1:
		for key in ["name", "enabled", "priority", "phase", "last_update_usec"]:
			_check(systems[0].has(key), "System diagnostics contain %s." % key)
		_check(systems[0].get("priority") == 23, "Diagnostics expose current system priority.")
	_check(snapshot.get("query_count") == 1, "Diagnostics expose cached query count.")
	_check(world.call("get_debug_snapshot", 0).get("entities", []).is_empty(), "Zero preview cap does not list entities.")
	_check(not world.profiling_enabled, "Reading diagnostics does not enable timing instrumentation.")
	world.profiling_enabled = true
	world.tick(0.1)
	snapshot = world.call("get_debug_snapshot", 5)
	_check(int(snapshot.get("last_tick_usec", -1)) >= 0, "Measured tick time is nonnegative.")
	world.destroy_entity(first)
	_check(world.get_entity_components(first).is_empty(), "Destroyed entities do not expose components.")
	world.clear()
	snapshot = world.call("get_debug_snapshot", 5)
	_check(snapshot.get("entity_count") == 0, "Cleared worlds report no entities.")
	_check(snapshot.get("systems", []).size() == 1, "Cleared worlds retain their registered systems.")


func _test_panel(panel_script: Script) -> void:
	var panel: PanelContainer = panel_script.new()
	root.add_child(panel)
	await process_frame
	for module in ["WorldSummaryModule", "EntityModule", "SystemModule"]:
		_check(panel.find_child(module, true, false) != null, "Diagnostics have a semantic %s." % module)
	panel.call("refresh_now")
	var status := panel.find_child("WorldStatus", true, false) as Label
	_check(status != null, "Panel provides readable world status.")
	if status != null:
		_check(status.text == "No world attached", "Unbound panel reports its empty state.")
	var world: EcsWorld = WORLD_SCRIPT.new()
	var entity := world.create_entity()
	world.add_component(entity, &"health", 42)
	var system: EcsSystem = SYSTEM_SCRIPT.new()
	system.priority = 23
	world.add_system(system)
	panel.call("set_world", world)
	panel.call("refresh_now")
	var entity_list := panel.find_child("EntityList", true, false) as ItemList
	var system_list := panel.find_child("SystemList", true, false) as Tree
	_check(entity_list != null and entity_list.item_count == 1, "Panel shows live entity rows.")
	_check(system_list != null and system_list.get_root() != null and system_list.get_root().get_child_count() == 1, "Panel shows registered systems.")
	_check(bool(panel.call("select_entity", entity)), "Live entity can be selected.")
	var values := panel.find_child("ComponentValues", true, false) as RichTextLabel
	_check(values != null and values.text.contains("health") and values.text.contains("42"), "Selection reveals actual component values.")
	world.set_component(entity, &"health", 17)
	panel.call("refresh_now")
	_check(values.text.contains("17"), "Component previews update while retaining selection.")
	_check(not bool(panel.call("select_entity", -1)), "Missing entity selection is rejected.")
	panel.set("max_entities", 0)
	panel.call("refresh_now")
	_check(entity_list.item_count == 0, "Panel enforces the configured entity preview cap.")
	panel.set("max_entities", 100)
	panel.call("select_entity", entity)
	world.destroy_entity(entity)
	panel.call("refresh_now")
	_check(values.text.contains("Select an entity"), "Destroyed selection is cleared gracefully.")
	world.dispose()
	panel.call("refresh_now")
	if status != null:
		_check(status.text == "World disposed", "Disposed world is reported without reading stale entities.")
	_check(entity_list.item_count == 0, "Disposed worlds clear entity rows.")
	panel.call("set_world", null)
	world = WORLD_SCRIPT.new()
	var reference := weakref(world)
	panel.call("set_world", world)
	world = null
	_check(reference.get_ref() == null, "Panel does not keep an otherwise unreferenced world alive.")
	panel.call("refresh_now")
	if status != null:
		_check(status.text == "World unavailable", "Freed world is reported gracefully.")
	panel.set("refresh_interval", 0.0)
	_check(float(panel.get("refresh_interval")) > 0.0, "Refresh interval prevents continuous zero-delay polling.")
	panel.free()


func _test_runner_binding(panel_script: Script) -> void:
	var host := Node.new()
	var runner: Node = load("res://addons/ecsmini/runtime/ecs_runner.gd").new()
	runner.name = "EcsRuntime"
	host.add_child(runner)
	var panel: PanelContainer = panel_script.new()
	panel.set("runner_path", NodePath("../EcsRuntime"))
	host.add_child(panel)
	root.add_child(host)
	await process_frame
	_check(panel.call("get_world") == runner.get("world"), "Inspector runner path resolves the live world.")
	host.free()


func _test_controls(panel_script: Script) -> void:
	var host := Node.new()
	var runner: Node = load("res://addons/ecsmini/runtime/ecs_runner.gd").new()
	runner.set("enabled", false)
	host.add_child(runner)
	var panel: PanelContainer = panel_script.new()
	host.add_child(panel)
	root.add_child(host)
	await process_frame
	panel.call("set_runner", runner)
	var world: EcsWorld = runner.get("world")
	var simulation := PhaseCounter.new()
	simulation.debug_name = "HealthSimulation"
	var presentation := PhaseCounter.new()
	presentation.phase = EcsSystem.Phase.PRESENTATION
	world.add_system(simulation)
	world.add_system(presentation)
	var controls: Node = panel.find_child("SimulationControlModule", true, false)
	_check(controls != null, "Simulation controls use a separate semantic module.")
	if controls != null:
		var tick: int = world.get("simulation_tick")
		_check(bool(controls.call("step_once")), "Bound paused runner single-steps.")
		_check(int(world.get("simulation_tick")) == tick + 1 and not bool(runner.get("enabled")), "Single step does not resume the runner.")
		_check(simulation.updates == 1 and presentation.updates == 1, "Single step executes both simulation and presentation once.")
		controls.call("toggle_pause")
		_check(bool(runner.get("enabled")), "Pause toggle resumes a paused runner.")
		var step_button := controls.find_child("StepButton", true, false) as Button
		_check(step_button != null and step_button.disabled, "Running runner disables its paused-only Step button.")
		controls.call("toggle_pause")
		_check(not bool(runner.get("enabled")), "Pause toggle pauses a running runner.")
	world.set("trace_enabled", true)
	world.set("trace_capacity", 2)
	var entity := world.create_entity()
	world.add_component(entity, &"health", 2)
	world.set_component(entity, &"health", 1)
	world.tick_phase(0.0, EcsSystem.Phase.SIMULATION)
	panel.set("max_trace_entries", 1)
	panel.call("refresh_now")
	var trace := panel.find_child("MutationTrace", true, false) as RichTextLabel
	_check(trace != null and trace.text.contains("health"), "Trace panel displays recent mutations.")
	_check(trace != null and trace.text.contains("HealthSimulation") and trace.text.split("\n").size() == 1, "Trace rows show responsible system and respect preview limit.")
	_check(world.call("get_trace").size() == 2, "Mutation trace enforces World capacity.")
	panel.call("set_world", world)
	if controls != null:
		var tick: int = world.get("simulation_tick")
		_check(bool(controls.call("step_once")) and int(world.get("simulation_tick")) == tick + 1, "External world binding supports a safe manual step.")
		var callback_state := {"stepped": true}
		world.query({"all": [&"health"]}).for_each(func(_entity: int) -> void:
			callback_state.stepped = controls.call("step_once"))
		_check(not callback_state.stepped, "Debug steps reject a protected query iteration boundary.")
		world.dispose()
		_check(not bool(controls.call("step_once")), "Disposed world refuses debug steps.")
	host.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: ECSmini diagnostics")
	quit(0 if _failures.is_empty() else 1)
