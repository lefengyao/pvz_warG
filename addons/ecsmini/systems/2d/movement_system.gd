class_name EcsMovementSystem
extends EcsSystem

## Optional 2D movement system that integrates [code]position[/code] from
## [code]velocity[/code]. Both components must contain [Vector2] values.
## This class never reads or writes a [Node], so it is suitable for headless simulation.[br][br]
## [codeblock]
## world.add_system(EcsMovementSystem.new())
## world.add_component(entity, &"position", Vector2.ZERO)
## world.add_component(entity, &"velocity", Vector2.RIGHT * 120.0)
## [/codeblock]
##
## @tutorial(2D movement overview): https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html

## Component key for the [Vector2] position updated by this system.
const POSITION: StringName = &"position"
## Component key for the [Vector2] velocity sampled by this system.
const VELOCITY: StringName = &"velocity"

var _query: EcsQuery
var compute_mode: StringName = &"serial"
var batch_size: int = 4096


## Configures movement to run after typical input systems at priority 100.
func _init() -> void:
	priority = 100
	schedule_key = &"movement2d"
	reads = [POSITION, VELOCITY]
	writes = [POSITION]


func configure(world: EcsWorld) -> void:
	_query = world.query({"all": [POSITION, VELOCITY]})


func on_detach() -> void:
	_query = null


## Adds [code]velocity * delta[/code] to [code]position[/code] for every entity that
## has both required components. For example, velocity [code]Vector2(60, 0)[/code]
## moves an entity 30 pixels during a 0.5 second tick.
func on_update(world: EcsWorld, delta: float) -> void:
	if _query == null:
		return
	var ids: Array[int] = []
	var positions := PackedVector2Array()
	var velocities := PackedVector2Array()
	for batch: Dictionary in _query.batches(batch_size):
		for row in batch.entities.size():
			var position_value: Variant = batch.columns[POSITION][row]
			var velocity_value: Variant = batch.columns[VELOCITY][row]
			if position_value is Vector2 and velocity_value is Vector2:
				ids.append(batch.entities[row])
				positions.append(position_value)
				velocities.append(velocity_value)
	var result := EcsBatchCompute.integrate2d(positions, velocities, delta, compute_mode)
	if result.size() == ids.size():
		world.write_batch(POSITION, ids, result)
