extends SceneTree

const LAB_PATH := "res://addons/ecsmini/examples/advanced/AdvancedEcsLab.tscn"
const SCRIPT_PATHS := [
	"res://addons/ecsmini/examples/advanced/lab_controller.gd",
	"res://addons/ecsmini/examples/advanced/lab_simulation.gd",
	"res://addons/ecsmini/examples/advanced/lab_presentation.gd",
	"res://addons/ecsmini/examples/advanced/lab_controls.gd",
	"res://addons/ecsmini/examples/advanced/lab_observations.gd",
]
var _checks := 0
var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ResourceLoader.exists(LAB_PATH), "Advanced ECS lab scene exists")
	for path: String in SCRIPT_PATHS:
		_check(ResourceLoader.exists(path), "Advanced ECS lab module exists: " + path.get_file())
	if _failures == 0:
		await _test_interactions()
	print("advanced_lab_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)

func _test_interactions() -> void:
	var scene: PackedScene = load(LAB_PATH)
	var lab := scene.instantiate()
	root.add_child(lab)
	await process_frame
	var controller: Variant = lab.get_node("SimulationModule/LabController")
	var presentation: Variant = lab.get_node("LabUI/WindowLayout/LabLayout/ContentModule/SimulationStage/PresentationModule")
	_check(controller.world != null and controller.world.entity_count() == 32, "Lab initializes 32 template movers")
	_check(controller.groups.values().size() == 4 and controller.world.get_relations().capture().links.size() == 28, "Lab demonstrates row groups and follower relations")
	_check(not controller.running, "Lab starts paused")
	var before: int = controller.world.simulation_tick
	_check(controller.step_lab().ok and controller.world.simulation_tick == before + 1, "Step advances exactly one replay tick")
	for backend: String in ["sparse", "archetype"]:
		for mode: StringName in EcsBatchCompute.MODES:
			_check(controller.reset_lab(backend, mode, 64).ok and controller.world.entity_count() == 64, "Lab resets backend/mode/population " + backend + "/" + String(mode))
			_check(controller.step_lab().ok, "Each selected compute mode runs")
	controller.reset_lab("sparse", &"serial", 32)
	_check(controller.queue_velocity(1, Vector2(120, 0), 3).ok, "Velocity input references stable UID")
	for index in 12:
		controller.step_lab()
	var digest: String = controller.replay.state_digest().digest
	_check(controller.rewind_to(5).ok and controller.world.simulation_tick == 5, "Lab rewind restores retained tick")
	_check(controller.replay_to(12).ok and controller.replay.state_digest().digest == digest, "Lab replay reproduces component and event digest")
	_check(controller.correct_input().ok and controller.world.simulation_tick == 12 and controller.replay.state_digest().digest != digest, "Corrected UID velocity input rolls back and resimulates")
	var old_entity: int = controller.world.get_entity_by_uid(1)
	var saved_digest: String = controller.replay.state_digest().digest
	var path := "user://ecsmini_advanced_lab_contract.snapshot.json"
	_check(controller.save_lab(path).ok, "Lab snapshot saves to disk")
	controller.step_lab()
	_check(controller.load_lab(path).ok and controller.replay.state_digest().digest == saved_digest, "Lab disk load restores simulation state")
	_check(controller.replay.get_history_range().oldest_tick == controller.world.simulation_tick, "Disk load recreates replay baseline instead of mixing old history")
	var restored_entity: int = controller.world.get_entity_by_uid(1)
	_check(restored_entity != old_entity and presentation.get_bound_entity(1) == restored_entity, "Presentation remaps stable UID bindings on load")
	_check(presentation.highlighted_entities.size() > 0, "Spatial nearest search highlights an entity")
	controller.run_lab()
	await process_frame
	controller.pause_lab()
	_check(not controller.running, "Run and pause controls are callable without global input")
	var reference := weakref(controller.world)
	lab.free()
	await process_frame
	_check(reference.get_ref() == null, "Lab teardown releases world and replay callbacks")
	DirAccess.remove_absolute(path)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)
