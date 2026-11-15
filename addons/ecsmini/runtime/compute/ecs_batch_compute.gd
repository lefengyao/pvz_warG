class_name EcsBatchCompute
extends RefCounted

## Synchronous packed-data kernels. Capture and commit belong to the main thread.
## Each WorkerThreadPool task owns separate inputs and a separate output buffer.
const MODES: Array[StringName] = [&"serial", &"parallel", &"auto"]
static var parallel_threshold: int = 4096
static var worker_chunk_size: int = 2048
static var last_error: String = ""
static var last_mode: StringName = &"serial"

class Vector2Job extends RefCounted:
	var positions: PackedVector2Array
	var velocities: PackedVector2Array
	var delta: float
	var result: PackedVector2Array
	var error: String = ""
	func run() -> void:
		var output := PackedVector2Array()
		output.resize(positions.size())
		for index in range(positions.size()):
			if not positions[index].is_finite() or not velocities[index].is_finite():
				error = "Position and velocity vectors must be finite."
				return
			output[index] = positions[index] + velocities[index] * delta
			if not output[index].is_finite():
				error = "Integration produced a nonfinite vector."
				return
		result = output

class Vector3Job extends RefCounted:
	var positions: PackedVector3Array
	var velocities: PackedVector3Array
	var delta: float
	var result: PackedVector3Array
	var error: String = ""
	func run() -> void:
		var output := PackedVector3Array()
		output.resize(positions.size())
		for index in range(positions.size()):
			if not positions[index].is_finite() or not velocities[index].is_finite():
				error = "Position and velocity vectors must be finite."
				return
			output[index] = positions[index] + velocities[index] * delta
			if not output[index].is_finite():
				error = "Integration produced a nonfinite vector."
				return
		result = output

static func availability() -> Dictionary:
	return {"serial": true, "parallel": true, "modes": MODES.duplicate(), "parallel_threshold": parallel_threshold, "worker_chunk_size": worker_chunk_size}

static func _validate(position_count: int, velocity_count: int, delta: float, mode: StringName) -> bool:
	last_error = ""
	if not Thread.is_main_thread():
		last_error = "Batch orchestration must run on the main thread."
	elif position_count != velocity_count:
		last_error = "Position and velocity lengths must match."
	elif not is_finite(delta) or delta < 0.0:
		last_error = "Delta must be finite and nonnegative."
	elif not MODES.has(mode):
		last_error = "Unknown batch compute mode: " + String(mode)
	return last_error.is_empty()

static func _resolve_mode(mode: StringName, count: int) -> StringName:
	if mode == &"auto":
		return &"parallel" if count >= maxi(1, parallel_threshold) else &"serial"
	return mode

static func integrate2d(positions: PackedVector2Array, velocities: PackedVector2Array, delta: float, mode: StringName = &"serial") -> PackedVector2Array:
	if not _validate(positions.size(), velocities.size(), delta, mode):
		return PackedVector2Array()
	last_mode = _resolve_mode(mode, positions.size())
	if last_mode == &"parallel" and not positions.is_empty():
		return _parallel2d(positions, velocities, delta)
	var job := Vector2Job.new()
	job.positions = positions
	job.velocities = velocities
	job.delta = delta
	job.run()
	if not job.error.is_empty():
		last_error = job.error
	return job.result

static func integrate3d(positions: PackedVector3Array, velocities: PackedVector3Array, delta: float, mode: StringName = &"serial") -> PackedVector3Array:
	if not _validate(positions.size(), velocities.size(), delta, mode):
		return PackedVector3Array()
	last_mode = _resolve_mode(mode, positions.size())
	if last_mode == &"parallel" and not positions.is_empty():
		return _parallel3d(positions, velocities, delta)
	var job := Vector3Job.new()
	job.positions = positions
	job.velocities = velocities
	job.delta = delta
	job.run()
	if not job.error.is_empty():
		last_error = job.error
	return job.result

static func _parallel2d(positions: PackedVector2Array, velocities: PackedVector2Array, delta: float) -> PackedVector2Array:
	var jobs: Array[Vector2Job] = []
	var tasks: Array[int] = []
	var size := maxi(1, worker_chunk_size)
	for first in range(0, positions.size(), size):
		var job := Vector2Job.new()
		job.positions = positions.slice(first, mini(first + size, positions.size()))
		job.velocities = velocities.slice(first, mini(first + size, velocities.size()))
		job.delta = delta
		jobs.append(job)
		tasks.append(WorkerThreadPool.add_task(job.run, false, "ECSmini Vector2 batch"))
	# Join EVERY task before touching results or releasing job references.
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	var result := PackedVector2Array()
	for job in jobs:
		if not job.error.is_empty():
			last_error = job.error
			return PackedVector2Array()
		result.append_array(job.result)
	return result

static func _parallel3d(positions: PackedVector3Array, velocities: PackedVector3Array, delta: float) -> PackedVector3Array:
	var jobs: Array[Vector3Job] = []
	var tasks: Array[int] = []
	var size := maxi(1, worker_chunk_size)
	for first in range(0, positions.size(), size):
		var job := Vector3Job.new()
		job.positions = positions.slice(first, mini(first + size, positions.size()))
		job.velocities = velocities.slice(first, mini(first + size, velocities.size()))
		job.delta = delta
		jobs.append(job)
		tasks.append(WorkerThreadPool.add_task(job.run, false, "ECSmini Vector3 batch"))
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	var result := PackedVector3Array()
	for job in jobs:
		if not job.error.is_empty():
			last_error = job.error
			return PackedVector3Array()
		result.append_array(job.result)
	return result
