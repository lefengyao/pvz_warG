extends SceneTree

## Regression contract for direct simulation entry points at protected boundaries.
class TickProbe extends EcsSystem:
	var starts := 0
	var updates := 0
	func on_start() -> void:
		starts += 1
	func on_update(_world: EcsWorld, _delta: float) -> void:
		updates += 1

class DestroyProbe extends EcsSystem:
	var target: int = -1
	func on_update(world: EcsWorld, _delta: float) -> void:
		if target > 0:
			world.destroy_entity(target)

var _checks := 0
var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_query_tick_boundary()
	await _test_query_runner_step_boundary()
	_test_flush_callback_tick_boundary()
	_test_normal_tick_starts_lifecycle()
	print("simulation_boundary_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)

func _test_query_tick_boundary() -> void:
	var world := EcsWorld.new()
	var entity := world.create_entity()
	world.add_component(entity, &"health", 1)
	var nested_ticks := 0
	world.query({"all": [&"health"]}).for_each(func(_entity: int) -> void:
		world.tick(0.25)
		nested_ticks = world.simulation_tick
	)
	_check(nested_ticks == 0 and world.simulation_tick == 0, "World.tick is rejected during query traversal")
	_check(is_zero_approx(world.simulation_time), "Query traversal cannot advance simulation time")
	world.dispose()

func _test_query_runner_step_boundary() -> void:
	var host := Node.new()
	var runner: EcsRunner = load("res://addons/ecsmini/runtime/ecs_runner.gd").new()
	runner.enabled = false
	host.add_child(runner)
	root.add_child(host)
	await process_frame
	var world: EcsWorld = runner.world
	var entity := world.create_entity()
	world.add_component(entity, &"health", 1)
	var accepted_state := {"accepted": true}
	world.query({"all": [&"health"]}).for_each(func(_entity: int) -> void:
		accepted_state.accepted = runner.step(0.25)
	)
	_check(not accepted_state.accepted and world.simulation_tick == 0, "Runner.step is rejected during query traversal")
	host.free()

func _test_flush_callback_tick_boundary() -> void:
	var world := EcsWorld.new()
	var entity := world.create_entity()
	var destroyer := DestroyProbe.new()
	destroyer.target = entity
	world.add_system(destroyer)
	var callback_state := {"tick": -1, "calls": 0}
	world.entity_destroyed.connect(func(_destroyed: int) -> void:
		callback_state.calls += 1
		world.tick(0.25)
		callback_state.tick = world.simulation_tick
	)
	world.tick(0.1)
	_check(callback_state.calls == 1 and callback_state.tick == 1 and world.simulation_tick == 1, "World.tick is rejected from a destruction flush callback (calls=%d, callback=%d, world=%d)" % [callback_state.calls, callback_state.tick, world.simulation_tick])
	_check(not world.is_entity_alive(entity), "Flush callback test still commits the queued destruction")
	world.dispose()

func _test_normal_tick_starts_lifecycle() -> void:
	var world := EcsWorld.new()
	var probe := TickProbe.new()
	world.add_system(probe)
	world.tick(0.1)
	_check(probe.starts == 1 and probe.updates == 1, "Normal World.tick still starts and updates systems")
	_check(world.simulation_tick == 1, "Normal World.tick advances simulation once")
	world.dispose()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)
