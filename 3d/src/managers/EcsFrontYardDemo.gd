extends Node

## Standalone ECS demonstration. Uses PlantLogic's cell signal as the sole input
## entry point and preserves the original FrontYard scene and lawn resources.
class LaneWrapSystem extends EcsSystem:
	var _query: EcsQuery
	var _visit: Callable

	func _init() -> void:
		priority = 200

	func configure(world: EcsWorld) -> void:
		_query = world.query({"all": [&"position3d", &"lane_start", &"lane_end", &"lane_direction"]})
		_visit = _wrap.bind(weakref(world))

	func on_update(_world: EcsWorld, _delta: float) -> void:
		_query.for_each(_visit)

	func on_detach() -> void:
		_query = null
		_visit = Callable()

	func _wrap(entity_id: int, world_ref: WeakRef) -> void:
		var world := world_ref.get_ref() as EcsWorld
		if world == null:
			return
		var current_position: Vector3 = world.get_component(entity_id, &"position3d")
		var lane_end: Vector3 = world.get_component(entity_id, &"lane_end")
		var lane_direction: Vector3 = world.get_component(entity_id, &"lane_direction")
		if (current_position - lane_end).dot(lane_direction) < 0.0:
			world.set_component(entity_id, &"position3d", world.get_component(entity_id, &"lane_start"))


@onready var runner: EcsRunner = $EcsRunner
@onready var front_yard: Node3D = get_node("../../FrontYard")
@onready var plant_logic: PlantLogic = front_yard.get_node("Manager/PlantLogic")
@onready var lawn_grid: LawnGrid = front_yard.get_node("Background/Grass/LawnGrid")
@onready var plant_visuals: Node3D = get_node("../../Presentation/PlantVisuals")
@onready var zombie_visuals: Node3D = get_node("../../Presentation/ZombieVisuals")
@onready var settings: Control = front_yard.get_node("UI/Setting")
@onready var pause_button: Button = get_node("../../DemoUI/DemoHeader/HeaderContent/Controls/PauseButton")

var _sync: EcsNodeSync3D
var _plants_by_cell: Dictionary = {}
var _entity_cells: Dictionary = {}
var _visuals: Dictionary = {}
var _plant_mesh: SphereMesh
var _zombie_mesh: CapsuleMesh
var _plant_material: StandardMaterial3D
var _zombie_material: StandardMaterial3D


func _ready() -> void:
	settings.hide()
	_sync = EcsNodeSync3D.new(runner.world)
	var transform_system := EcsTransformSync3DSystem.new(_sync)
	transform_system.use_global_transform = true
	runner.add_system(EcsMovement3DSystem.new())
	runner.add_system(LaneWrapSystem.new())
	runner.add_system(transform_system)
	runner.world.entity_destroyed.connect(_on_entity_destroyed)
	plant_logic.cell_clicked.connect(_on_cell_clicked)
	_create_visual_resources()
	_spawn_zombies()


func _create_visual_resources() -> void:
	_plant_mesh = SphereMesh.new()
	_plant_mesh.radius = 0.45
	_plant_mesh.height = 0.9
	_zombie_mesh = CapsuleMesh.new()
	_zombie_mesh.radius = 0.32
	_zombie_mesh.height = 1.2
	_plant_material = StandardMaterial3D.new()
	_plant_material.albedo_color = Color(0.35, 0.9, 0.12)
	_zombie_material = StandardMaterial3D.new()
	_zombie_material.albedo_color = Color(0.68, 0.2, 0.25)


func _on_cell_clicked(index: Vector2i) -> void:
	if index.x < 0 or index.x >= lawn_grid.rows or index.y < 0 or index.y >= lawn_grid.columns:
		return
	if _plants_by_cell.has(index):
		runner.world.destroy_entity(int(_plants_by_cell[index]))
		return
	var cell := lawn_grid.get_cell(index.x, index.y)
	if cell == null:
		return
	var entity := runner.world.create_entity()
	var world_position := cell.global_position + lawn_grid.global_basis.y.normalized() * 0.5
	runner.world.add_component(entity, &"position3d", world_position)
	runner.world.add_component(entity, &"cell_index", index)
	runner.world.add_component(entity, &"plant", true)
	runner.world.add_component(entity, &"health", 100)
	_plants_by_cell[index] = entity
	_entity_cells[entity] = index
	_bind_visual(entity, "Plant_%d_%d" % [index.x, index.y], _plant_mesh, _plant_material, plant_visuals)
	# Present the click immediately, including while the simulation is paused.
	runner.world.tick_phase(0.0, EcsSystem.Phase.PRESENTATION)


func _spawn_zombies() -> void:
	var direction := lawn_grid.global_basis.x.normalized()
	var vertical_offset := lawn_grid.global_basis.y.normalized() * 0.65
	var edge_offset := direction * lawn_grid.cell_size.x * 0.6
	for row in lawn_grid.rows:
		var first_cell := lawn_grid.get_cell(row, 0)
		var last_cell := lawn_grid.get_cell(row, lawn_grid.columns - 1)
		if first_cell == null or last_cell == null:
			continue
		var entity := runner.world.create_entity()
		var lane_start := last_cell.global_position + edge_offset + vertical_offset
		var lane_end := first_cell.global_position - edge_offset + vertical_offset
		runner.world.add_component(entity, &"position3d", lane_start)
		runner.world.add_component(entity, &"velocity3d", -direction * (0.6 + row * 0.08))
		runner.world.add_component(entity, &"lane_start", lane_start)
		runner.world.add_component(entity, &"lane_end", lane_end)
		runner.world.add_component(entity, &"lane_direction", direction)
		runner.world.add_component(entity, &"row", row)
		runner.world.add_component(entity, &"zombie", true)
		_bind_visual(entity, "Zombie_Row%d" % row, _zombie_mesh, _zombie_material, zombie_visuals)
	runner.world.tick_phase(0.0, EcsSystem.Phase.PRESENTATION)


func _bind_visual(entity_id: int, visual_name: String, mesh: Mesh, material: Material, visual_parent: Node3D) -> void:
	var visual := MeshInstance3D.new()
	visual.name = visual_name
	visual.mesh = mesh
	visual.material_override = material
	visual_parent.add_child(visual)
	_sync.bind(entity_id, visual)
	_visuals[entity_id] = weakref(visual)


func _on_entity_destroyed(entity_id: int) -> void:
	if _entity_cells.has(entity_id):
		_plants_by_cell.erase(_entity_cells[entity_id])
		_entity_cells.erase(entity_id)
	var visual_ref: WeakRef = _visuals.get(entity_id)
	var visual: Node3D = visual_ref.get_ref() as Node3D if visual_ref != null else null
	_visuals.erase(entity_id)
	if visual != null:
		visual.free()


func _on_pause_pressed() -> void:
	var paused := runner.process_mode != Node.PROCESS_MODE_DISABLED
	runner.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	pause_button.text = "Resume" if paused else "Pause"


func _on_reset_pressed() -> void:
	runner.world.clear()
	_spawn_zombies()


func _on_settings_pressed() -> void:
	settings.visible = not settings.visible


func _exit_tree() -> void:
	if is_instance_valid(plant_logic) and plant_logic.cell_clicked.is_connected(_on_cell_clicked):
		plant_logic.cell_clicked.disconnect(_on_cell_clicked)
	if _sync != null:
		_sync.attach_world(null)
	if is_instance_valid(runner):
		if runner.world.entity_destroyed.is_connected(_on_entity_destroyed):
			runner.world.entity_destroyed.disconnect(_on_entity_destroyed)
		runner.world.dispose()
	_plants_by_cell.clear()
	_entity_cells.clear()
	_visuals.clear()
