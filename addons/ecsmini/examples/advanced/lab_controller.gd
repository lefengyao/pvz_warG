class_name EcsLabController
extends Node

## Application-facing coordinator for the advanced ECS lab.
## Replay is the only object allowed to advance the simulation clock.
signal updated

const REPLAY = preload("res://addons/ecsmini/runtime/persistence/ecs_replay.gd")
const SNAPSHOT_STORE = preload("res://addons/ecsmini/runtime/persistence/ecs_snapshot_store.gd")
const SIMULATION = preload("res://addons/ecsmini/examples/advanced/lab_simulation.gd")
const SPARSE_STORAGE = preload("res://addons/ecsmini/runtime/storage/ecs_sparse_storage.gd")
const ARCHETYPE_STORAGE = preload("res://addons/ecsmini/runtime/storage/ecs_archetype_storage.gd")
const GROUP_INDEX = preload("res://addons/ecsmini/runtime/extensions/ecs_group_index.gd")
const SPATIAL_INDEX = preload("res://addons/ecsmini/runtime/extensions/ecs_spatial_index.gd")
const TEMPLATE = preload("res://addons/ecsmini/runtime/extensions/ecs_entity_template.gd")

var world: EcsWorld
var replay: EcsReplay
var simulation: EcsLabSimulation
var groups: Dictionary = {}
var spatial: EcsSpatialIndex
var running: bool = false
var backend: StringName = &"sparse"
var compute_mode: StringName = &"serial"
var population: int = 32
var last_error: String = ""
var _last_velocity_input: Dictionary = {}

func _ready() -> void:
	reset_lab("sparse", &"serial", 32)
	call_deferred("_bind_modules")

func _process(_delta: float) -> void:
	if not running or replay == null:
		return
	var result := replay.step(true)
	if not result.ok:
		last_error = result.error
		pause_lab()
	else:
		_emit_updated()

func reset_lab(selected_backend: String = "sparse", selected_mode: StringName = &"serial", count: int = 32) -> Dictionary:
	if selected_backend != "sparse" and selected_backend != "archetype":
		return _error("Unknown storage backend: " + selected_backend)
	if not EcsBatchCompute.MODES.has(selected_mode):
		return _error("Unknown compute mode: " + String(selected_mode))
	if count < 1 or count > 64:
		return _error("Lab population must be between 1 and 64.")
	_pause_and_release()
	var next_world := EcsWorld.new()
	var selected_storage: EcsStorage = SPARSE_STORAGE.new() if selected_backend == "sparse" else ARCHETYPE_STORAGE.new(256)
	if not next_world.set_storage_backend(selected_storage):
		next_world.dispose()
		return _error("World rejected the selected storage backend.")
	world = next_world
	backend = StringName(selected_backend)
	compute_mode = selected_mode
	population = count
	if not _populate_world(count):
		_pause_and_release()
		return _error("World rejected the lab template entities.")
	simulation = SIMULATION.new()
	if not simulation.configure(world, compute_mode):
		_pause_and_release()
		return _error("World rejected the lab simulation systems.")
	spatial = SPATIAL_INDEX.new(world, &"position", 96.0)
	_create_replay()
	_rebuild_groups()
	running = false
	last_error = ""
	_emit_updated()
	return {"ok": true, "error": "", "tick": world.simulation_tick}

func step_lab() -> Dictionary:
	if not _available():
		return _error("Lab is not initialized.")
	var result := replay.step(true)
	if result.ok:
		_emit_updated()
	else:
		last_error = result.error
	return result

func queue_velocity(uid: int, velocity: Vector2, tick: int) -> Dictionary:
	if not _available():
		return _error("Lab is not initialized.")
	if world.get_entity_by_uid(uid) < 0:
		return _error("Velocity input references an unknown UID.")
	var result := replay.queue_command(tick, &"set_velocity", {"uid": uid, "velocity": velocity})
	if result.ok:
		_last_velocity_input = {"uid": uid, "tick": tick, "velocity": velocity}
	else:
		last_error = result.error
	return result

func rewind_to(tick: int) -> Dictionary:
	if not _available():
		return _error("Lab is not initialized.")
	var result := replay.rewind(tick, true)
	if result.ok:
		_rebuild_groups()
		_emit_updated()
	else:
		last_error = result.error
	return result

func replay_to(tick: int) -> Dictionary:
	if not _available():
		return _error("Lab is not initialized.")
	var result := replay.replay_to(tick, true)
	if result.ok:
		_rebuild_groups()
		_emit_updated()
	else:
		last_error = result.error
	return result

func correct_input(uid: int = -1, tick: int = -1, velocity: Vector2 = Vector2(240.0, 0.0)) -> Dictionary:
	if not _available() or _last_velocity_input.is_empty():
		return _error("No velocity input is available to correct.")
	var corrected_uid := int(_last_velocity_input.uid) if uid < 0 else uid
	var corrected_tick := int(_last_velocity_input.tick) if tick < 0 else tick
	var corrected_velocity := velocity if velocity.is_finite() else Vector2(240.0, 0.0)
	var corrections: Array[Dictionary] = [{
		"tick": corrected_tick,
		"key": &"set_velocity",
		"payload": {"uid": corrected_uid, "velocity": corrected_velocity},
	}]
	var result := replay.rollback_and_resimulate(corrected_tick, corrections, world.simulation_tick, true)
	if result.ok:
		_last_velocity_input = {"uid": corrected_uid, "tick": corrected_tick, "velocity": corrected_velocity}
		_rebuild_groups()
		_emit_updated()
	else:
		last_error = result.error
	return result

func save_lab(path: String) -> Dictionary:
	if not _available():
		return _error("Lab is not initialized.")
	var result := SNAPSHOT_STORE.new().save(world, path)
	if not result.ok:
		last_error = result.error
	return result

func load_lab(path: String) -> Dictionary:
	if not _available():
		return _error("Lab is not initialized.")
	var result := SNAPSHOT_STORE.new().load_into(world, path)
	if not result.ok:
		last_error = result.error
		return result
	# A disk load is a new replay baseline; old checkpoints reference old handles.
	_create_replay()
	_rebuild_groups()
	running = false
	last_error = ""
	_emit_updated()
	return {"ok": true, "error": "", "tick": world.simulation_tick, "id_map": result.id_map}

func run_lab() -> void:
	if _available():
		running = true
		set_process(true)
		_emit_updated()

func pause_lab() -> void:
	running = false
	_emit_updated()

func state_summary() -> Dictionary:
	if not _available():
		return {"ready": false, "running": running, "backend": String(backend), "compute_mode": String(compute_mode), "population": population,
			"entity_count": 0, "group_count": 0, "relation_count": 0, "tick": 0, "simulation_time": 0.0,
			"oldest_tick": -1, "latest_tick": -1, "last_error": last_error}
	var history := replay.get_history_range()
	return {"ready": true, "running": running, "backend": String(backend), "compute_mode": String(compute_mode),
		"population": world.entity_count(), "entity_count": world.entity_count(), "tick": world.simulation_tick,
		"simulation_time": world.simulation_time, "groups": groups.size(), "group_count": groups.size(),
		"relations": world.get_relations().capture().links.size(), "relation_count": world.get_relations().capture().links.size(),
		"oldest_tick": history.oldest_tick, "latest_tick": history.latest_tick, "history": history,
		"last_error": last_error}

func _populate_world(count: int) -> bool:
	var template := TEMPLATE.new()
	template.components = {&"position": Vector2.ZERO, &"velocity": Vector2.ZERO, &"row": 0}
	for index in count:
		var row := int(float(index) / float(maxi(1, int(ceil(float(count) / 4.0)))))
		row = mini(row, 3)
		var column := index % maxi(1, int(ceil(float(count) / 4.0)))
		var entity := world.create_entity(index + 1)
		if entity < 0:
			return false
		var values := template.resolve({&"position": Vector2(80.0 + column * 92.0, 80.0 + row * 100.0), &"row": row})
		for key: StringName in values:
			if not world.add_component(entity, key, values[key]):
				return false
	var relation_registry := world.get_relations()
	var row_width := maxi(1, int(ceil(float(count) / 4.0)))
	for index in range(1, count):
		var source := world.get_entity_by_uid(index + 1)
		var target := world.get_entity_by_uid(index)
		if index % row_width != 0 and (relation_registry == null or not relation_registry.add(source, &"follows", target)):
			return false
	return true

func _create_replay() -> void:
	replay = REPLAY.new(world, 1.0 / 60.0, 120)
	replay.register_command(&"set_velocity", func(target: EcsWorld, payload: Dictionary) -> void:
		var entity := target.get_entity_by_uid(int(payload.get("uid", 0)))
		if entity >= 0 and target.has_component(entity, &"velocity") and payload.get("velocity") is Vector2:
			target.set_component(entity, &"velocity", payload.velocity)
	)

func _rebuild_groups() -> void:
	groups.clear()
	if world == null or world.is_disposed():
		return
	for entity in world.get_entities():
		var row := int(world.get_component(entity, &"row", -1))
		if row < 0:
			continue
		if not groups.has(row):
			groups[row] = []
		groups[row].append(entity)
	for row: int in groups:
		groups[row].sort()

func _pause_and_release() -> void:
	running = false
	if simulation != null:
		simulation.shutdown()
	if spatial != null:
		spatial.detach()
	if world != null and not world.is_disposed():
		world.dispose()
	replay = null
	simulation = null
	spatial = null
	world = null
	groups.clear()

func _available() -> bool:
	return world != null and not world.is_disposed() and replay != null

func _emit_updated() -> void:
	updated.emit()

func _bind_modules() -> void:
	var presentation := get_node_or_null("../../LabUI/WindowLayout/LabLayout/ContentModule/SimulationStage/PresentationModule")
	var controls := get_node_or_null("../../LabUI/WindowLayout/LabLayout/ContentModule/ControlsModule")
	var observations := get_node_or_null("../../LabUI/WindowLayout/LabLayout/ContentModule/ObservationsModule")
	if presentation != null and presentation.has_method("set_controller"):
		presentation.set_controller(self)
	if controls != null and controls.has_method("set_controller"):
		controls.set_controller(self)
	if observations != null and observations.has_method("set_controller"):
		observations.set_controller(self)

func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}

func _exit_tree() -> void:
	_pause_and_release()
