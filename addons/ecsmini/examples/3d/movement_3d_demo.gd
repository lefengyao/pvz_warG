extends Node

## F6 example: a Node3D bridge presents headless Vector3 movement data.
class BoundarySystem extends EcsSystem:
	var _query: EcsQuery
	var _visit: Callable

	func _init() -> void:
		priority = 200

	func configure(world: EcsWorld) -> void:
		_query = world.query({"all": [&"position3d", &"velocity3d"]})
		_visit = _bounce.bind(weakref(world))

	func on_update(_world: EcsWorld, _delta: float) -> void:
		_query.for_each(_visit)

	func on_detach() -> void:
		_query = null
		_visit = Callable()

	func _bounce(entity_id: int, world_ref: WeakRef) -> void:
		var world := world_ref.get_ref() as EcsWorld
		if world == null:
			return
		var current_position: Vector3 = world.get_component(entity_id, &"position3d")
		var velocity: Vector3 = world.get_component(entity_id, &"velocity3d")
		if absf(current_position.x) > 8.5:
			velocity.x *= -1.0
		if absf(current_position.z) > 4.5:
			velocity.z *= -1.0
		current_position.x = clampf(current_position.x, -8.5, 8.5)
		current_position.z = clampf(current_position.z, -4.5, 4.5)
		world.set_component(entity_id, &"position3d", current_position)
		world.set_component(entity_id, &"velocity3d", velocity)


@onready var runner: EcsRunner = $EcsRunner
@onready var pawn_visuals: Node3D = get_node("../../Presentation/PawnVisuals")
@onready var pause_button: Button = get_node("../../DemoUI/ExampleHeader/HeaderContent/Controls/PauseButton")

var _sync: EcsNodeSync3D


func _ready() -> void:
	runner.world.profiling_enabled = true
	_sync = EcsNodeSync3D.new(runner.world)
	runner.add_system(EcsMovement3DSystem.new())
	runner.add_system(BoundarySystem.new())
	runner.add_system(EcsTransformSync3DSystem.new(_sync))
	_spawn_pawns()


func _spawn_pawns() -> void:
	var pawn_mesh := CapsuleMesh.new()
	pawn_mesh.radius = 0.3
	pawn_mesh.height = 1.2
	for index in 12:
		var entity := runner.world.create_entity()
		var visual := MeshInstance3D.new()
		visual.name = "Pawn%d" % index
		visual.mesh = pawn_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(float(index) / 12.0, 0.65, 0.95)
		visual.material_override = material
		pawn_visuals.add_child(visual)
		var column := index % 4
		var row := int(float(index) / 4.0)
		runner.world.add_component(entity, &"position3d", Vector3((float(column) - 1.5) * 3.0, 0.6, (float(row) - 1.0) * 3.0))
		runner.world.add_component(entity, &"velocity3d", Vector3(1.0 + 0.1 * index, 0.0, 0.6 if index % 2 == 0 else -0.6))
		_sync.bind(entity, visual)
	runner.world.tick(0.0)


func _on_pause_pressed() -> void:
	var paused := runner.process_mode != Node.PROCESS_MODE_DISABLED
	runner.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	pause_button.text = "Resume" if paused else "Pause"


func _on_reset_pressed() -> void:
	runner.world.clear()
	for visual in pawn_visuals.get_children():
		visual.free()
	_spawn_pawns()


func _exit_tree() -> void:
	if _sync != null:
		_sync.attach_world(null)
	if is_instance_valid(runner):
		runner.world.dispose()
