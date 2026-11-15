class_name EcsDebugControls
extends VBoxContainer

## Optional local buttons. Weak bindings never own the Runner or World.
signal stepped
signal trace_changed
var step_delta: float = 1.0 / 60.0
var _world_ref: WeakRef
var _runner_ref: WeakRef
var _pause_button: Button
var _step_button: Button
var _trace_toggle: CheckButton
var _status: Label

func _ready() -> void:
	_build_ui()
	refresh_now()

func set_world(world: EcsWorld) -> void:
	_world_ref = weakref(world) if world != null else null
	_runner_ref = null
	refresh_now()

func set_runner(runner: EcsRunner) -> void:
	_runner_ref = weakref(runner) if runner != null else null
	_world_ref = weakref(runner.world) if runner != null and runner.world != null else null
	refresh_now()

func get_world() -> EcsWorld:
	return _world_ref.get_ref() as EcsWorld if _world_ref != null else null

func get_runner() -> EcsRunner:
	return _runner_ref.get_ref() as EcsRunner if _runner_ref != null else null

func toggle_pause() -> bool:
	var runner := get_runner()
	if runner == null or not runner.is_inside_tree() or runner.world == null or runner.world.is_disposed():
		return false
	runner.enabled = not runner.enabled
	refresh_now()
	return true

func step_once() -> bool:
	var world := get_world()
	if world == null or not world.is_at_safe_boundary() or not is_finite(step_delta) or step_delta <= 0.0:
		return false
	var runner := get_runner()
	var success := false
	if runner != null:
		success = runner.step(step_delta)
	else:
		var previous_tick: int = world.simulation_tick
		world.tick_phase(step_delta, EcsSystem.Phase.SIMULATION)
		success = world.simulation_tick == previous_tick + 1
		if success:
			world.tick_phase(step_delta, EcsSystem.Phase.PRESENTATION)
	refresh_now()
	if success:
		stepped.emit()
	return success

func refresh_now() -> void:
	_build_ui()
	var world := get_world()
	var runner := get_runner()
	var available := world != null and not world.is_disposed()
	_step_button.disabled = not available or (runner != null and (runner.enabled or not runner.is_inside_tree()))
	_pause_button.disabled = not available or runner == null or not runner.is_inside_tree()
	_pause_button.text = "Pause" if runner != null and runner.enabled else "Resume"
	_trace_toggle.disabled = not available
	_trace_toggle.set_pressed_no_signal(world.trace_enabled if available else false)
	_status.text = "Tick %d   Time %.3f s   %s" % [world.simulation_tick, world.simulation_time,
		("Running" if runner.enabled else "Paused") if runner != null else "Manual world steps"] if available else "Simulation unavailable"

func _on_trace_toggled(value: bool) -> void:
	var world := get_world()
	if world != null and not world.is_disposed():
		world.trace_enabled = value
		trace_changed.emit()

func _build_ui() -> void:
	if _pause_button != null:
		return
	name = "SimulationControlModule"
	var header := Label.new()
	header.name = "SectionHeader"
	header.text = "Simulation Controls"
	add_child(header)
	var actions := HBoxContainer.new()
	actions.name = "SimulationActions"
	add_child(actions)
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = "Pause"
	_pause_button.pressed.connect(toggle_pause)
	actions.add_child(_pause_button)
	_step_button = Button.new()
	_step_button.name = "StepButton"
	_step_button.text = "Step"
	_step_button.pressed.connect(step_once)
	actions.add_child(_step_button)
	_trace_toggle = CheckButton.new()
	_trace_toggle.name = "TraceToggle"
	_trace_toggle.text = "Mutation trace"
	_trace_toggle.toggled.connect(_on_trace_toggled)
	actions.add_child(_trace_toggle)
	_status = Label.new()
	_status.name = "SimulationStatus"
	add_child(_status)
