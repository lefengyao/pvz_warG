extends Node

## F6 example: data movement, boundary simulation and optional Node2D presentation.
class BoundarySystem extends EcsSystem:
	var bounds: Rect2
	var _query: EcsQuery
	var _visit: Callable

	func _init(movement_bounds: Rect2) -> void:
		bounds = movement_bounds
		priority = 200

	func configure(world: EcsWorld) -> void:
		_query = world.query({"all": [&"position", &"velocity"]})
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
		var current_position: Vector2 = world.get_component(entity_id, &"position")
		var velocity: Vector2 = world.get_component(entity_id, &"velocity")
		if current_position.x < bounds.position.x or current_position.x > bounds.end.x:
			velocity.x *= -1.0
		if current_position.y < bounds.position.y or current_position.y > bounds.end.y:
			velocity.y *= -1.0
		current_position = current_position.clamp(bounds.position, bounds.end)
		world.set_component(entity_id, &"position", current_position)
		world.set_component(entity_id, &"velocity", velocity)


@onready var runner: EcsRunner = $EcsRunner
@onready var pawn_visuals: Node2D = get_node("../../Presentation/PawnVisuals")
@onready var pause_button: Button = get_node("../../DemoUI/ExampleHeader/HeaderContent/Controls/PauseButton")

var _sync: EcsNodeSync
var _bounds: Rect2


func _ready() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_bounds = Rect2(Vector2(100.0, 200.0), viewport_size - Vector2(200.0, 300.0))
	_sync = EcsNodeSync.new(runner.world)
	runner.add_system(EcsMovementSystem.new())
	runner.add_system(BoundarySystem.new(_bounds))
	runner.add_system(EcsTransformSyncSystem.new(_sync))
	_spawn_pawns()


func _spawn_pawns() -> void:
	for index in 12:
		var entity := runner.world.create_entity()
		var visual := Polygon2D.new()
		visual.name = "Pawn%d" % index
		visual.polygon = PackedVector2Array([Vector2(24.0, 0.0), Vector2(-18.0, -18.0), Vector2(-18.0, 18.0)])
		visual.color = Color.from_hsv(float(index) / 12.0, 0.65, 0.95)
		pawn_visuals.add_child(visual)
		var column := index % 4
		var row := int(float(index) / 4.0)
		var start_position := _bounds.position + _bounds.size * Vector2(float(column + 1) / 5.0, float(row + 1) / 4.0)
		runner.world.add_component(entity, &"position", start_position)
		runner.world.add_component(entity, &"velocity", Vector2(100.0 + 12.0 * index, 55.0 if index % 2 == 0 else -55.0))
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
