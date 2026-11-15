extends SceneTree

const STORAGE_PATHS: Array[String] = [
	"res://addons/ecsmini/runtime/storage/ecs_sparse_storage.gd",
	"res://addons/ecsmini/runtime/storage/ecs_archetype_storage.gd",
]
const COMPUTE_PATH := "res://addons/ecsmini/runtime/compute/ecs_batch_compute.gd"
var _failures := 0
var _checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in STORAGE_PATHS + [COMPUTE_PATH]:
		_check(ResourceLoader.exists(path), "Missing storage/compute implementation: " + path)
	if _failures > 0:
		_finish()
		return
	for path in STORAGE_PATHS:
		var script: Script = load(path)
		_test_storage_contract(script)
		_test_randomized_model(script)
		_test_bulk_commit(script)
	_test_archetype_chunks()
	_test_compute(load(COMPUTE_PATH))
	_check(ResourceLoader.exists("res://addons/ecsmini/benchmarks/advanced_benchmark.gd"), "Missing actual-world staged storage/compute benchmark")
	_finish()

func _test_storage_contract(script: Script) -> void:
	var storage: RefCounted = script.new()
	_check(storage.create_entity(-50), "Arbitrary negative IDs are storage keys")
	_check(not storage.create_entity(-50), "Duplicate entities are rejected")
	_check(not storage.add(1234, &"missing", 1), "Components require a living storage entity")
	_check(not storage.add(-50, &"", 1), "Empty component keys are rejected")
	_check(storage.add(-50, &"payload", {"nested": [1, {"value": 2}]}), "Store nested values")
	_check(not storage.add(-50, &"payload", 3), "Duplicate additions are rejected")
	_check(not storage.set_value(-50, &"missing", 3), "Missing writes are rejected")
	_check(storage.add(-50, &"tag"), "Null-valued tags have membership")
	_check(storage.has(-50, &"tag") and storage.component_count(&"tag") == 1, "Tags retain membership")
	_check(storage.has_method("keys_for"), "Keys can be read without copying component payloads")
	if storage.has_method("keys_for"):
		var keys: Array[StringName] = storage.keys_for(-50)
		_check(keys == [&"payload", &"tag"], "Component keys are typed and sorted")
		keys.clear()
		_check(storage.keys_for(-50).size() == 2, "Key snapshots cannot alter membership")
		var absent_keys: Array[StringName] = storage.keys_for(1234)
		_check(absent_keys.is_empty(), "Missing entity returns typed empty key array")
	_check(storage.get_value(1234, &"payload", 99) == 99, "Missing reads use default")
	var required: Array[StringName] = [&"payload"]
	var empty: Array[StringName] = []
	var batches: Array = storage.export_batches(required, empty, empty, 1)
	_check(batches.size() == 1 and batches[0]["entities"] == [-50], "Aligned bounded batch")
	batches[0]["columns"][&"payload"][0]["nested"][1]["value"] = 200
	batches[0]["entities"].clear()
	_check(storage.get_value(-50, &"payload")["nested"][1]["value"] == 2, "Batch values are deeply isolated")
	var snapshot: Dictionary = storage.entity_components(-50)
	snapshot[&"payload"]["nested"].clear()
	_check(storage.get_value(-50, &"payload")["nested"].size() == 2, "Entity snapshot values are deeply isolated")
	var gradient := Gradient.new()
	storage.set_value(-50, &"payload", {"resource": gradient, "packed": PackedInt32Array([7, 8])})
	var resource_batch: Array = storage.export_batches(required, empty, empty)
	resource_batch[0]["columns"][&"payload"][0]["resource"].set_color(0, Color.RED)
	resource_batch[0]["columns"][&"payload"][0]["packed"][0] = 99
	_check(gradient.get_color(0) != Color.RED, "Nested Resource batch values are isolated")
	_check(storage.get_value(-50, &"payload")["packed"][0] == 7, "Nested packed batch values are isolated")
	var excluded: Array[StringName] = [&"tag"]
	var alternatives: Array[StringName] = [&"absent"]
	_check(storage.export_batches(required, empty, excluded, 1).is_empty(), "Exclusion criteria are applied")
	_check(storage.export_batches(empty, alternatives, empty, 1).is_empty(), "Any requires a matching component")
	_check(storage.export_batches(empty, empty, empty, 0).is_empty(), "Invalid chunk size is rejected")
	_check(storage.remove(-50, &"tag"), "Remove membership")
	_check(not storage.remove(-50, &"tag"), "Missing removals rejected")
	_check(storage.destroy_entity(-50), "Destroy entity")
	_check(not storage.destroy_entity(-50), "Duplicate destruction rejected")
	_check(storage.component_types().is_empty(), "Empty component types are reclaimed")
	_check(storage.export_batches(empty, empty, empty).is_empty(), "Destroyed entity leaves every query")
	storage.create_entity(0)
	_check(storage.export_batches(empty, empty, empty)[0]["entities"] == [0], "Componentless entity is queryable")
	storage.clear()
	_check(storage.export_batches(empty, empty, empty).is_empty(), "Clear removes componentless entities")
	_check(not String(storage.backend_name).is_empty(), "Storage identifies its backend")
	_check(storage.diagnostics()["entity_count"] == 0, "Diagnostics reflect clear")

func _test_randomized_model(script: Script) -> void:
	var storage: RefCounted = script.new()
	var model: Dictionary = {}
	var random := RandomNumberGenerator.new()
	random.seed = 719241
	var types: Array[StringName] = [&"a", &"b", &"c", &"tag", &"a:1", &"1:a"]
	for step in range(1200):
		var id := random.randi_range(-25, 75)
		var key := types[random.randi_range(0, types.size() - 1)]
		var value: Variant = null if key == &"tag" else {"step": step, "data": [id, step]}
		var exists := model.has(id)
		var present: bool = exists and model[id].has(key)
		var actual := false
		var expected := false
		match random.randi_range(0, 4):
			0:
				expected = not exists
				actual = storage.create_entity(id)
				if expected:
					model[id] = {}
			1:
				expected = exists
				actual = storage.destroy_entity(id)
				if expected:
					model.erase(id)
			2:
				expected = exists and not present
				actual = storage.add(id, key, value)
				if expected:
					model[id][key] = value
			3:
				expected = present
				actual = storage.remove(id, key)
				if expected:
					model[id].erase(key)
			4:
				expected = present
				actual = storage.set_value(id, key, value)
				if expected:
					model[id][key] = value
		_check(actual == expected, "Operation agrees with model at step %d" % step)
		if step % 40 == 0:
			_verify_model(storage, model, types)
	_verify_model(storage, model, types)

func _test_bulk_commit(script: Script) -> void:
	var storage: RefCounted = script.new()
	_check(storage.has_method("set_values_unchecked"), "Storage supports a prevalidated bulk value commit")
	if not storage.has_method("set_values_unchecked"):
		return
	var ids: Array[int] = []
	var values := PackedVector2Array()
	for index in range(19):
		var id := index * 17 - 50
		storage.create_entity(id)
		storage.add(id, &"position", Vector2.ZERO)
		if index % 2 == 0:
			storage.add(id, &"selected")
		ids.append(id)
		values.append(Vector2(index, -index))
	storage.set_values_unchecked(&"position", ids, values)
	for row in range(ids.size()):
		_check(storage.get_value(ids[row], &"position") == values[row], "Packed bulk commit preserves entity/value alignment")
	storage.set_values_unchecked(&"position", PackedInt64Array(), PackedVector2Array())
	_check(storage.component_count(&"position") == ids.size(), "Empty bulk commit leaves membership intact")

func _verify_model(storage: RefCounted, model: Dictionary, types: Array[StringName]) -> void:
	for id: int in model:
		_check(storage.entity_components(id) == model[id], "Entity values agree with reference model")
	for key in types:
		var expected: Array[int] = []
		for id: int in model:
			if model[id].has(key):
				expected.append(id)
		expected.sort()
		var actual: Array[int] = storage.entities_for(key)
		actual.sort()
		_check(actual == expected and storage.component_count(key) == expected.size(), "Dense index agrees with model")
	var criteria: Array[Dictionary] = [
		{"all": [], "any": [], "none": []},
		{"all": [&"a"], "any": [&"b", &"c"], "none": [&"tag"]},
		{"all": [], "any": [&"b", &"tag"], "none": [&"a"]},
		{"all": [&"missing"], "any": [], "none": []},
	]
	for rule in criteria:
		var all_types: Array[StringName] = []
		var any_types: Array[StringName] = []
		var none_types: Array[StringName] = []
		all_types.assign(rule["all"])
		any_types.assign(rule["any"])
		none_types.assign(rule["none"])
		var expected: Array[int] = []
		for id: int in model:
			if _model_matches(model[id], all_types, any_types, none_types):
				expected.append(id)
		var actual: Array[int] = []
		for batch: Dictionary in storage.export_batches(all_types, any_types, none_types, 7):
			_check(batch["entities"].size() <= 7, "Export chunk bound is respected")
			for key in all_types:
				_check(batch["columns"].has(key), "Required column always exists")
			for row in range(batch["entities"].size()):
				var id: int = batch["entities"][row]
				for key: StringName in batch["columns"]:
					_check(batch["columns"][key].size() == batch["entities"].size(), "Columns are aligned")
					_check(model[id].has(key) and batch["columns"][key][row] == model[id][key], "Batch values match row identity")
			actual.append_array(batch["entities"])
		actual.sort()
		expected.sort()
		_check(actual == expected, "Batch query agrees with reference model")

func _model_matches(components: Dictionary, required: Array[StringName], alternatives: Array[StringName], excluded: Array[StringName]) -> bool:
	for key in required:
		if not components.has(key):
			return false
	var any_matches := alternatives.is_empty()
	for key in alternatives:
		any_matches = any_matches or components.has(key)
	for key in excluded:
		if components.has(key):
			return false
	return any_matches

func _test_archetype_chunks() -> void:
	var storage: RefCounted = load(STORAGE_PATHS[1]).new(4)
	for id in range(21):
		storage.create_entity(id)
		storage.add(id, &"position", Vector2(id, id * 2))
		storage.add(id, &"velocity", Vector2.ONE)
	var before: Dictionary = storage.diagnostics()
	_check(before["chunk_capacity"] == 4 and before["chunk_count"] == 6, "Exact-signature archetypes use bounded chunks")
	for id in range(0, 21, 2):
		storage.remove(id, &"velocity")
		_check(storage.get_value(id, &"position") == Vector2(id, id * 2), "Structural migration preserves other columns")
	for id in range(1, 21, 2):
		storage.destroy_entity(id)
	_check(storage.entities_for(&"position").size() == 11, "Chunk swap removal preserves all surviving rows")
	for id in range(0, 21, 2):
		storage.remove(id, &"position")
	_check(storage.component_types().is_empty(), "Empty archetypes reclaim component counts")
	var empty: Array[StringName] = []
	var survivors: Array[int] = []
	for batch: Dictionary in storage.export_batches(empty, empty, empty, 3):
		survivors.append_array(batch["entities"])
	_check(survivors.size() == 11, "Migration to empty signature retains entities")
	storage.clear()
	_check(storage.diagnostics()["chunk_count"] == 0, "Clear reclaims chunks")

func _test_compute(compute: Script) -> void:
	var positions2 := PackedVector2Array()
	var velocities2 := PackedVector2Array()
	var positions3 := PackedVector3Array()
	var velocities3 := PackedVector3Array()
	for index in range(5003):
		positions2.append(Vector2(index * 0.25, -index * 0.125))
		velocities2.append(Vector2(index % 7, -2.5))
		positions3.append(Vector3(index * 0.25, -index * 0.125, index % 5))
		velocities3.append(Vector3(index % 7, -2.5, 1.75))
	var original2 := positions2.duplicate()
	var original3 := positions3.duplicate()
	var serial2: PackedVector2Array = compute.integrate2d(positions2, velocities2, 0.125)
	var serial3: PackedVector3Array = compute.integrate3d(positions3, velocities3, 0.125)
	_check(serial2.size() == positions2.size() and serial3.size() == positions3.size(), "Serial computes every packed row")
	for index in range(positions2.size()):
		_check(serial2[index].is_equal_approx(positions2[index] + velocities2[index] * 0.125), "2D serial numerical contract")
		_check(serial3[index].is_equal_approx(positions3[index] + velocities3[index] * 0.125), "3D serial numerical contract")
	for mode: StringName in [&"parallel", &"auto"]:
		_check(compute.integrate2d(positions2, velocities2, 0.125, mode) == serial2, "2D compute modes are equivalent: " + String(mode))
		_check(compute.integrate3d(positions3, velocities3, 0.125, mode) == serial3, "3D compute modes are equivalent: " + String(mode))
	_check(positions2 == original2 and positions3 == original3, "Compute never mutates captured inputs")
	var invalid_partition := positions2.duplicate()
	invalid_partition[3000] = Vector2(INF, 0)
	_check(compute.integrate2d(invalid_partition, velocities2, 0.125, &"parallel").is_empty(), "One rejected worker partition rejects the complete result")
	_check(compute.integrate2d(positions2, velocities2, 0.125, &"parallel") == serial2, "Subsequent parallel work succeeds after every rejected task is joined")
	_check(compute.integrate2d(positions2, PackedVector2Array(), 1.0).is_empty(), "Mismatched packed lengths rejected")
	_check(not String(compute.last_error).is_empty(), "Invalid arguments expose a diagnostic")
	_check(compute.integrate3d(positions3, velocities3, NAN).is_empty(), "Nonfinite delta rejected")
	_check(compute.integrate2d(positions2, velocities2, -1.0).is_empty(), "Negative delta rejected")
	_check(compute.integrate2d(positions2, velocities2, 0.1, &"invalid").is_empty(), "Unknown mode rejected")
	_check(compute.integrate2d(PackedVector2Array(), PackedVector2Array(), 0.1).is_empty(), "Empty valid input supported")
	_check(compute.last_error == "", "Empty valid input clears errors")
	_check(compute.integrate2d(positions2, velocities2, 0.0) == positions2, "Zero delta returns position values")
	for mode: StringName in [&"serial", &"parallel", &"auto"]:
		_check(compute.integrate2d(PackedVector2Array([Vector2(INF, 0)]), PackedVector2Array([Vector2.ONE]), 0.1, mode).is_empty(), "Nonfinite Vector2 input rejected: " + String(mode))
		_check(compute.integrate3d(PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3(0, NAN, 0)]), 0.1, mode).is_empty(), "Nonfinite Vector3 input rejected: " + String(mode))
		_check(compute.integrate2d(PackedVector2Array([Vector2(1e38, 0)]), PackedVector2Array([Vector2(1e38, 0)]), 100.0, mode).is_empty(), "Vector2 overflow rejected: " + String(mode))
		_check(compute.integrate3d(PackedVector3Array([Vector3(0, 1e38, 0)]), PackedVector3Array([Vector3(0, 1e38, 0)]), 100.0, mode).is_empty(), "Vector3 overflow rejected: " + String(mode))
	var availability: Dictionary = compute.availability()
	_check(availability.has("modes") and availability["modes"] == [&"serial", &"parallel", &"auto"], "Only pure GDScript compute modes are exposed")
	_check(availability.has("serial") and availability.has("parallel") and not availability.has("native"), "Compute availability describes the pure GDScript backends")
	var expected_auto_mode: StringName = &"parallel" if positions2.size() >= int(availability["parallel_threshold"]) else &"serial"
	compute.integrate2d(positions2, velocities2, 0.125, &"auto")
	_check(compute.last_mode == expected_auto_mode, "Auto mode selects a GDScript backend from the batch size")
	compute.integrate3d(positions3, velocities3, 0.125, &"auto")
	_check(compute.last_mode == expected_auto_mode, "Auto mode selects the same backend for Vector3 batches")
	_test_fractional_compute(compute)

func _test_fractional_compute(compute: Script) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 907331
	var positions2 := PackedVector2Array()
	var velocities2 := PackedVector2Array()
	var positions3 := PackedVector3Array()
	var velocities3 := PackedVector3Array()
	for _row in range(1003):
		positions2.append(Vector2(random.randf_range(-10000, 10000), random.randf_range(-10000, 10000)))
		velocities2.append(Vector2(random.randf_range(-100, 100), random.randf_range(-100, 100)))
		positions3.append(Vector3(random.randf_range(-10000, 10000), random.randf_range(-10000, 10000), random.randf_range(-10000, 10000)))
		velocities3.append(Vector3(random.randf_range(-100, 100), random.randf_range(-100, 100), random.randf_range(-100, 100)))
	var expected2: PackedVector2Array = compute.integrate2d(positions2, velocities2, 0.17325)
	var expected3: PackedVector3Array = compute.integrate3d(positions3, velocities3, 0.17325)
	for mode: StringName in [&"parallel", &"auto"]:
		_check(compute.integrate2d(positions2, velocities2, 0.17325, mode) == expected2, "Random fractional 2D math is identical: " + String(mode))
		_check(compute.integrate3d(positions3, velocities3, 0.17325, mode) == expected3, "Random fractional 3D math is identical: " + String(mode))

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)

func _finish() -> void:
	print("storage_compute_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)
