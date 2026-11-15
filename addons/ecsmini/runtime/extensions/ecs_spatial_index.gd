class_name EcsSpatialIndex
extends EcsIndexBase

var cell_size: float = 64.0:
	set(value):
		if is_finite(value) and value > 0.0:
			cell_size = value
			reindex()
var _buckets_2d: Dictionary = {}
var _buckets_3d: Dictionary = {}
var _positions: Dictionary = {}
var _entity_buckets: Dictionary = {}

func _init(world: EcsWorld = null, key: StringName = &"position", bucket_size: float = 64.0) -> void:
	cell_size = bucket_size
	if world != null:
		attach(world, key)

func radius(position: Variant, distance: float) -> Array[int]:
	if not _valid_position(position) or not is_finite(distance) or distance < 0.0:
		return []
	return _ordered(_candidates(position, distance), position, distance)

func nearest(position: Variant, limit: int = 1, max_distance: float = INF) -> Array[int]:
	if not _valid_position(position) or limit < 1 or is_nan(max_distance) or max_distance < 0.0:
		return []
	var candidates: Array[int] = []
	if is_finite(max_distance):
		candidates = _candidates(position, max_distance)
	else:
		for entity: int in _positions:
			if typeof(_positions[entity]) == typeof(position):
				candidates.append(entity)
	var ordered := _ordered(candidates, position, max_distance)
	ordered.resize(mini(limit, ordered.size()))
	return ordered

func _reindex_entity(entity: int) -> void:
	_erase_entity(entity)
	var world := _world()
	if not _valid(entity) or not world.has_component(entity, component_key):
		return
	var position: Variant = world.get_component(entity, component_key)
	if not _valid_position(position):
		return
	var bucket: Variant = _bucket(position)
	var buckets: Dictionary = _buckets_2d if position is Vector2 else _buckets_3d
	if not buckets.has(bucket):
		buckets[bucket] = {}
	buckets[bucket][entity] = true
	_positions[entity] = position
	_entity_buckets[entity] = bucket

func _erase_entity(entity: int) -> void:
	if not _positions.has(entity):
		return
	var buckets: Dictionary = _buckets_2d if _positions[entity] is Vector2 else _buckets_3d
	var bucket: Variant = _entity_buckets[entity]
	buckets[bucket].erase(entity)
	if buckets[bucket].is_empty():
		buckets.erase(bucket)
	_positions.erase(entity)
	_entity_buckets.erase(entity)

func _clear_index() -> void:
	_buckets_2d.clear()
	_buckets_3d.clear()
	_positions.clear()
	_entity_buckets.clear()

func _bucket(position: Variant) -> Variant:
	if position is Vector2:
		return Vector2(floor(position.x / cell_size), floor(position.y / cell_size))
	return Vector3(floor(position.x / cell_size), floor(position.y / cell_size), floor(position.z / cell_size))

func _candidates(position: Variant, distance: float) -> Array[int]:
	var buckets: Dictionary = _buckets_2d if position is Vector2 else _buckets_3d
	var result: Array[int] = []
	var cell_radius := distance / cell_size
	var center_bucket: Variant = _bucket(position)
	# Vector coordinates may be finite even when their cell coordinates are too
	# large for integer loop bounds. Exact occupied-bucket scanning handles them.
	if not center_bucket.is_finite() or absf(center_bucket.x) > 1e9 or absf(center_bucket.y) > 1e9 or (position is Vector3 and absf(center_bucket.z) > 1e9) or not is_finite(cell_radius) or cell_radius > maxi(buckets.size() * 4, 64):
		for bucket: Variant in buckets:
			for entity: int in buckets[bucket]:
				result.append(entity)
		return result
	var extent: Variant = Vector2.ONE * distance if position is Vector2 else Vector3.ONE * distance
	var lower: Variant = _bucket(position - extent)
	var upper: Variant = _bucket(position + extent)
	var bucket_count: float = float(upper.x - lower.x + 1) * float(upper.y - lower.y + 1)
	if position is Vector3:
		bucket_count *= float(upper.z - lower.z + 1)
	# Huge radii scan occupied buckets, avoiding unbounded empty-cell loops.
	if bucket_count > maxi(buckets.size() * 4, 64):
		for bucket: Variant in buckets:
			for entity: int in buckets[bucket]:
				result.append(entity)
		return result
	for x in range(lower.x, upper.x + 1):
		for y in range(lower.y, upper.y + 1):
			if position is Vector2:
				for entity: int in buckets.get(Vector2(x, y), {}):
					result.append(entity)
			else:
				for z in range(lower.z, upper.z + 1):
					for entity: int in buckets.get(Vector3(x, y, z), {}):
						result.append(entity)
	return result

func _ordered(candidates: Array[int], position: Variant, distance: float) -> Array[int]:
	var result: Array[int] = []
	var distances: Dictionary = {}
	var squared_distance := distance * distance
	for entity in candidates:
		if not _valid(entity):
			continue
		var candidate_distance: float = _distance_squared(position, _positions[entity])
		if candidate_distance <= squared_distance:
			result.append(entity)
			distances[entity] = candidate_distance
	result.sort_custom(func(left: int, right: int) -> bool:
		return left < right if distances[left] == distances[right] else distances[left] < distances[right]
	)
	return result

func _valid_position(position: Variant) -> bool:
	return (position is Vector2 or position is Vector3) and position.is_finite()

func _distance_squared(left: Variant, right: Variant) -> float:
	# Calculate in GDScript's double precision instead of Vector's real_t to
	# retain exact filtering for large finite positions on single precision builds.
	var dx: float = float(left.x) - float(right.x)
	var dy: float = float(left.y) - float(right.y)
	var result := dx * dx + dy * dy
	if left is Vector3:
		var dz: float = float(left.z) - float(right.z)
		result += dz * dz
	return result
