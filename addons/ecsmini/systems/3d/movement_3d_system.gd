class_name EcsMovement3DSystem
extends EcsSystem

## Headless 3D movement: integrates Vector3 position3d from Vector3 velocity3d.
## Separate keys let 2D and 3D systems coexist in the same world.
const POSITION: StringName = &"position3d"
const VELOCITY: StringName = &"velocity3d"

var _query: EcsQuery
var compute_mode: StringName = &"serial"
var batch_size: int = 4096


func _init() -> void:
	priority = 100
	schedule_key = &"movement3d"
	reads = [POSITION, VELOCITY]
	writes = [POSITION]


func configure(world: EcsWorld) -> void:
	_query = world.query({"all": [POSITION, VELOCITY]})


func on_detach() -> void:
	_query = null


func on_update(world: EcsWorld, delta: float) -> void:
	if _query == null:
		return
	var ids: Array[int] = []
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	for batch: Dictionary in _query.batches(batch_size):
		for row in batch.entities.size():
			var position_value: Variant = batch.columns[POSITION][row]
			var velocity_value: Variant = batch.columns[VELOCITY][row]
			if position_value is Vector3 and velocity_value is Vector3:
				ids.append(batch.entities[row])
				positions.append(position_value)
				velocities.append(velocity_value)
	var result := EcsBatchCompute.integrate3d(positions, velocities, delta, compute_mode)
	if result.size() == ids.size():
		world.write_batch(POSITION, ids, result)
