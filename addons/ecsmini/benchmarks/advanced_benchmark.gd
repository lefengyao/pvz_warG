extends SceneTree

## Actual EcsWorld comparison, including isolated batch capture and atomic commit.
## godot --headless --path . --script addons/ecsmini/benchmarks/advanced_benchmark.gd
## -- --counts=100,1000,10000 --samples=3 --iterations=10
const DELTA := 0.25
const VALID_MODES: Array[StringName] = [&"serial", &"parallel", &"auto"]
var _counts: Array[int] = [100, 1000, 10000]
var _samples := 3
var _iterations := 10
var _warmup := 1
var _chunk_size := 256
var _modes: Array[StringName] = [&"serial", &"parallel", &"auto"]
var _output_path := ""
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _parse_args():
		quit(1)
		return
	var results: Array[Dictionary] = []
	if _failures.is_empty():
		for population in _counts:
			for backend: StringName in [&"sparse", &"archetype"]:
				for dimension in [2, 3]:
					for mode in _modes:
						var rows: Array[Dictionary] = []
						var failure_count := _failures.size()
						for _sample in range(_samples):
							rows.append(_measure(backend, dimension, mode, population))
						results.append(_summarize(backend, dimension, mode, population, rows, failure_count))
	var report: Dictionary = {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"ecsmini_version": ECSmini.VERSION,
		"cpu": OS.get_processor_name(),
		"logical_processor_count": OS.get_processor_count(),
		"availability": EcsBatchCompute.availability(),
		"sample_count": _samples,
		"iterations_per_sample": _iterations,
		"warmup_iterations": _warmup,
		"chunk_size": _chunk_size,
		"clock": "Time.get_ticks_usec",
		"timed_region": "Actual World batch capture/packing, isolated compute, and World.write_batch commit; setup/check/disposal excluded",
		"comparison": "Current backends only; no historical baseline or asserted speedup",
		"results": results,
		"failures": _failures,
	}
	if not _output_path.is_empty():
		var output := FileAccess.open(_output_path, FileAccess.WRITE)
		if output == null:
			_fail("Cannot write benchmark output: " + _output_path)
			report["failures"] = _failures
		else:
			output.store_string(JSON.stringify(report, "\t") + "\n")
			output.close()
	print("ECSMINI_ADVANCED_BENCHMARK_JSON=" + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)

func _measure(backend: StringName, dimension: int, mode: StringName, population: int) -> Dictionary:
	var world := EcsWorld.new()
	var storage: EcsStorage = EcsSparseStorage.new() if backend == &"sparse" else EcsArchetypeStorage.new(_chunk_size)
	if not world.set_storage_backend(storage):
		_fail("World rejected an empty backend: " + String(backend))
	var position_key := &"position" if dimension == 2 else &"position_3d"
	var velocity_key := &"velocity" if dimension == 2 else &"velocity_3d"
	var ids: Array[int] = []
	var active_count := 0
	for index in range(population):
		var id := world.create_entity()
		ids.append(id)
		world.add_component(id, position_key, _initial_position(index, dimension))
		world.add_component(id, velocity_key, _velocity(dimension))
		if index % 2 == 0:
			world.add_component(id, &"selected")
		if index % 11 == 0:
			world.add_component(id, &"frozen")
		else:
			active_count += 1
	var query := world.query({"all": [position_key, velocity_key], "none": [&"frozen"]})
	if query.count() != active_count:
		_fail("Initial World query count differs from expected membership.")
	for _iteration in range(_warmup):
		_step(world, query, position_key, velocity_key, dimension, mode)
	var totals: Dictionary = {"capture_usec": 0, "compute_usec": 0, "commit_usec": 0, "total_usec": 0, "mode": mode}
	for _iteration in range(_iterations):
		var step := _step(world, query, position_key, velocity_key, dimension, mode)
		for key: StringName in [&"capture_usec", &"compute_usec", &"commit_usec", &"total_usec"]:
			totals[key] += step[key]
		totals["mode"] = step["mode"]
	var elapsed_steps := _iterations + _warmup
	for index in range(population):
		var expected: Variant = _initial_position(index, dimension)
		if index % 11 != 0:
			expected += _velocity(dimension) * (DELTA * elapsed_steps)
		var actual: Variant = world.get_component(ids[index], position_key)
		if not actual.is_equal_approx(expected):
			_fail("%s/%dD/%s entity %d numerical correctness failed." % [backend, dimension, mode, index])
			break
	totals["active_entity_count"] = active_count
	totals["storage"] = world.storage.diagnostics()
	world.dispose()
	return totals

func _step(world: EcsWorld, query: EcsQuery, position_key: StringName, velocity_key: StringName, dimension: int, mode: StringName) -> Dictionary:
	var start := Time.get_ticks_usec()
	var ids: Array[int] = []
	var positions2 := PackedVector2Array()
	var velocities2 := PackedVector2Array()
	var positions3 := PackedVector3Array()
	var velocities3 := PackedVector3Array()
	for batch: Dictionary in query.batches(_chunk_size):
		ids.append_array(batch["entities"])
		if dimension == 2:
			positions2.append_array(PackedVector2Array(batch["columns"][position_key]))
			velocities2.append_array(PackedVector2Array(batch["columns"][velocity_key]))
		else:
			positions3.append_array(PackedVector3Array(batch["columns"][position_key]))
			velocities3.append_array(PackedVector3Array(batch["columns"][velocity_key]))
	var captured := Time.get_ticks_usec()
	var values: Variant
	if dimension == 2:
		values = EcsBatchCompute.integrate2d(positions2, velocities2, DELTA, mode)
	else:
		values = EcsBatchCompute.integrate3d(positions3, velocities3, DELTA, mode)
	var computed := Time.get_ticks_usec()
	if values.size() != ids.size():
		_fail("Batch compute returned an invalid result: " + EcsBatchCompute.last_error)
	var effective_mode := EcsBatchCompute.last_mode
	if not world.write_batch(position_key, ids, values):
		_fail("World rejected a captured batch commit.")
	var committed := Time.get_ticks_usec()
	return {"capture_usec": captured - start, "compute_usec": computed - captured, "commit_usec": committed - computed, "total_usec": committed - start, "mode": effective_mode}

func _summarize(backend: StringName, dimension: int, mode: StringName, population: int, rows: Array[Dictionary], failure_count: int) -> Dictionary:
	var result: Dictionary = {"scenario": "movement_%dd" % dimension, "backend": backend, "requested_mode": mode, "effective_mode": rows[0]["mode"], "entity_count": population, "active_entity_count": rows[0]["active_entity_count"], "storage": rows[0]["storage"], "correct": _failures.size() == failure_count}
	for stage in ["capture", "compute", "commit", "total"]:
		var samples: Array[int] = []
		for row in rows:
			samples.append(row[stage + "_usec"])
		result[stage + "_samples_usec"] = samples
		result[stage + "_median_usec_per_iteration"] = _median(samples) / float(_iterations)
	return result

func _median(samples: Array[int]) -> float:
	var sorted := samples.duplicate()
	sorted.sort()
	var middle := int(float(sorted.size()) / 2.0)
	if sorted.size() % 2 == 0:
		return (float(sorted[middle - 1]) + float(sorted[middle])) / 2.0
	return float(sorted[middle])

func _initial_position(index: int, dimension: int) -> Variant:
	return Vector2(index * 0.5, -index * 0.25) if dimension == 2 else Vector3(index * 0.5, -index * 0.25, index % 5)

func _velocity(dimension: int) -> Variant:
	return Vector2(2, -4) if dimension == 2 else Vector3(2, -4, 1)

func _parse_args() -> bool:
	for argument in OS.get_cmdline_user_args():
		var fields := argument.split("=", true, 1)
		if fields.size() != 2:
			_fail("Expected --option=value: " + argument)
			continue
		var value: String = fields[1]
		match fields[0]:
			"--counts":
				_counts.clear()
				for token in value.split(","):
					if not token.is_valid_int() or int(token) <= 0:
						_fail("Population counts must be positive integers.")
					else:
						_counts.append(int(token))
			"--modes":
				_modes.clear()
				for token in value.split(","):
					var mode := StringName(token)
					if not VALID_MODES.has(mode):
						_fail("Unknown benchmark mode: " + token)
					else:
						_modes.append(mode)
			"--samples", "--iterations", "--warmup", "--chunk-size":
				if not value.is_valid_int() or int(value) < (0 if fields[0] == "--warmup" else 1):
					_fail("Invalid numeric benchmark option: " + argument)
					continue
				match fields[0]:
					"--samples": _samples = int(value)
					"--iterations": _iterations = int(value)
					"--warmup": _warmup = int(value)
					"--chunk-size": _chunk_size = int(value)
			"--output": _output_path = value
			_: _fail("Unknown benchmark option: " + fields[0])
	if _counts.is_empty() or _modes.is_empty():
		_fail("At least one population and compute mode are required.")
	return _failures.is_empty()

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL: ", message)
