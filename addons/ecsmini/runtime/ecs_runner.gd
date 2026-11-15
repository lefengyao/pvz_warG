class_name EcsRunner
extends Node

## Default: every system follows one chosen clock. Split mode separates presentation.
@export var use_physics_process: bool = false:
	set(value):
		use_physics_process = value
		_apply_clock()
@export var separate_presentation: bool = false:
	set(value):
		separate_presentation = value
		_apply_clock()
@export var enabled: bool = true
@export_range(0.0, 10.0, 0.01) var time_scale: float = 1.0:
	set(value):
		time_scale = maxf(value, 0.0) if is_finite(value) else 1.0
@export var dispose_world_on_free: bool = true

var world: EcsWorld = EcsWorld.new()
var _running: bool = false

func _enter_tree() -> void:
	call_deferred("_start_world")

func _ready() -> void:
	_start_world()

func _start_world() -> void:
	if not is_inside_tree() or _running or world == null or world.is_disposed():
		return
	_apply_clock()
	_running = true
	world.start()
	if not is_inside_tree() or world == null or world.is_disposed():
		_running = false

func _apply_clock() -> void:
	if not is_inside_tree():
		return
	set_process(not use_physics_process or separate_presentation)
	set_physics_process(use_physics_process or separate_presentation)

func _process(delta: float) -> void:
	if not _running or not enabled or world == null or world.is_disposed() or time_scale <= 0.0:
		return
	if separate_presentation:
		world.tick_phase(delta * time_scale, EcsSystem.Phase.PRESENTATION)
	elif not use_physics_process:
		world.tick(delta * time_scale)

func _physics_process(delta: float) -> void:
	if not _running or not enabled or (not use_physics_process and not separate_presentation) or world == null or world.is_disposed() or time_scale <= 0.0:
		return
	if separate_presentation:
		world.tick_phase(delta * time_scale, EcsSystem.Phase.SIMULATION)
	else:
		world.tick(delta * time_scale)

func add_system(system: EcsSystem) -> bool:
	return world != null and world.add_system(system)

## Advance one simulation tick while paused, then refresh presentation once.
func step(delta: float = 1.0 / 60.0) -> bool:
	if enabled or not _running or world == null or world.is_disposed() or not world.is_at_safe_boundary() or not is_finite(delta) or delta < 0.0:
		return false
	var previous := world.simulation_tick
	world.tick_phase(delta, EcsSystem.Phase.SIMULATION)
	if world.simulation_tick != previous + 1:
		return false
	world.tick_phase(delta, EcsSystem.Phase.PRESENTATION)
	return true

func _exit_tree() -> void:
	if _running and world != null:
		world.stop()
	_running = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and dispose_world_on_free and world != null:
		world.dispose()
