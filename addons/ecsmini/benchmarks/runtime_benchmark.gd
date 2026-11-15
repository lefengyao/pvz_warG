extends SceneTree

## Deterministic headless benchmark. Correctness is checked before and after timing.
## Example: godot --headless --path . --script addons/ecsmini/benchmarks/runtime_benchmark.gd
## -- --counts=100,1000,10000 --samples=5 --iterations=30 --output=user://ecsmini_benchmark.json

const DELTA := 0.25
const SCENARIOS := ["movement", "static_query", "unrelated_changes", "spawn_destroy"]

var _counts: Array[int] = [100, 1000, 10000]
var _samples: int = 5
var _iterations: int = 30
var _warmup: int = 1
var _output_path: String = ""
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _parse_args():
		quit(1)
		return
	var results: Array[Dictionary] = []
	for population in _counts:
		for scenario in SCENARIOS:
			# Every scenario first passes a small untimed correctness run.
			var failure_count := _failures.size()
			_measure(scenario, population, 2)
			if _failures.size() != failure_count:
				continue
			for _warmup_index in range(_warmup):
				_measure(scenario, population, _iterations)
			var samples: Array[int] = []
			for _sample_index in range(_samples):
				samples.append(_measure(scenario, population, _iterations))
			var sorted_samples := samples.duplicate()
			sorted_samples.sort()
			var middle := int(float(sorted_samples.size()) / 2.0)
			var median_usec: float = sorted_samples[middle]
			if sorted_samples.size() % 2 == 0:
				median_usec = (float(sorted_samples[middle - 1]) + float(sorted_samples[middle])) / 2.0
			var total_usec: float = 0.0
			for elapsed in samples:
				total_usec += elapsed
			results.append({
				"scenario": scenario,
				"entity_count": population,
				"iterations": _iterations,
				"spawn_batch_size": maxi(1, int(float(population) / 10.0)) if scenario == "spawn_destroy" else 0,
				"samples_usec": samples,
				"median_usec": median_usec,
				"mean_usec": total_usec / float(samples.size()),
				"median_usec_per_iteration": median_usec / float(_iterations),
				"correct": _failures.size() == failure_count,
			})
	var report := {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"ecsmini_version": ECSmini.VERSION,
		"sample_count": _samples,
		"warmup_samples": _warmup,
		"clock": "Time.get_ticks_usec",
		"timed_region": "scenario loop only; world setup, correctness checks, and disposal excluded",
		"profiling_enabled": false,
		"results": results,
		"failures": _failures,
	}
	if not _output_path.is_empty():
		var output := FileAccess.open(_output_path, FileAccess.WRITE)
		if output == null:
			_fail("Cannot write benchmark output: %s" % _output_path)
			report["failures"] = _failures
		else:
			output.store_string(JSON.stringify(report, "\t") + "\n")
			output.close()
	print("ECSMINI_BENCHMARK_JSON=" + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _measure(scenario: String, population: int, iterations: int) -> int:
	var world := EcsWorld.new()
	var entities: Array[int] = []
	for index in range(population):
		var entity_id := world.create_entity()
		entities.append(entity_id)
		world.add_component(entity_id, &"benchmark_static", index)
		if scenario == "movement":
			world.add_component(entity_id, &"position", Vector2(index, -index))
			world.add_component(entity_id, &"velocity", Vector2(4, -8))
	var query := world.query({"all": [&"benchmark_static"]})
	_check(query.count() == population, "%s initial query membership" % scenario)
	if scenario == "movement":
		world.add_system(EcsMovementSystem.new())
		world.start()
		world.query({"all": [&"position", &"velocity"]}).count()
	var refresh_before: int = query.refresh_count
	var count_total := 0
	var batch_size := maxi(1, int(float(population) / 10.0))
	var last_spawned := -1
	var begin_usec := Time.get_ticks_usec()
	match scenario:
		"movement":
			for _iteration in range(iterations):
				world.tick(DELTA)
		"static_query":
			for _iteration in range(iterations):
				count_total += query.count()
		"unrelated_changes":
			for _iteration in range(iterations):
				world.add_component(entities[0], &"benchmark_unrelated", true)
				count_total += query.count()
				world.remove_component(entities[0], &"benchmark_unrelated")
				count_total += query.count()
		"spawn_destroy":
			for _iteration in range(iterations):
				var spawned: Array[int] = []
				for spawn_index in range(batch_size):
					last_spawned = world.create_entity()
					world.add_component(last_spawned, &"benchmark_spawned", spawn_index)
					spawned.append(last_spawned)
				for entity_id in spawned:
					world.destroy_entity(entity_id)
	var elapsed_usec := Time.get_ticks_usec() - begin_usec
	_check(world.entity_count() == population, "%s preserves its steady population" % scenario)
	_check(query.count() == population, "%s preserves the queried population" % scenario)
	match scenario:
		"movement":
			for index in range(entities.size()):
				var expected := Vector2(index, -index) + Vector2(1, -2) * float(iterations)
				var actual: Vector2 = world.get_component(entities[index], &"position")
				_check(actual.is_equal_approx(expected), "Movement integrates deterministic positions")
		"static_query":
			_check(count_total == population * iterations, "Static query returns all matching entities")
			_check(query.refresh_count == refresh_before, "Static query reuses cached membership")
		"unrelated_changes":
			_check(count_total == population * iterations * 2, "Unrelated mutations preserve query results")
			_check(query.refresh_count == refresh_before, "Unrelated components do not rebuild this positive query")
		"spawn_destroy":
			_check(not world.is_entity_alive(last_spawned), "Destroyed spawned ID is invalid")
			_check(world.query({"all": [&"benchmark_spawned"]}).count() == 0, "Spawned components are removed")
	world.dispose()
	_check(world.is_disposed() and world.entity_count() == 0, "Benchmark scenario disposes its world")
	return elapsed_usec


func _parse_args() -> bool:
	for argument in OS.get_cmdline_user_args():
		var pieces := argument.split("=", true, 1)
		if pieces.size() != 2:
			_fail("Expected --name=value, received: " + argument)
			return false
		match pieces[0]:
			"--counts":
				_counts.clear()
				for count_text in pieces[1].split(",", false):
					if not count_text.is_valid_int() or int(count_text) <= 0:
						_fail("Entity populations must be positive integers.")
						return false
					_counts.append(int(count_text))
				if _counts.is_empty():
					_fail("At least one entity population is required.")
					return false
			"--samples", "--iterations", "--warmup":
				if not pieces[1].is_valid_int():
					_fail("Expected an integer for " + pieces[0])
					return false
				var value := int(pieces[1])
				if value < (0 if pieces[0] == "--warmup" else 1):
					_fail("Invalid value for " + pieces[0])
					return false
				if pieces[0] == "--samples":
					_samples = value
				elif pieces[0] == "--iterations":
					_iterations = value
				else:
					_warmup = value
			"--output":
				_output_path = pieces[1]
			_:
				_fail("Unknown benchmark argument: " + argument)
				return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL: " + message)
