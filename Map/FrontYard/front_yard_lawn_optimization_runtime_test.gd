extends SceneTree

const FRONT_YARD_SCENE: PackedScene = preload("res://Map/FrontYard/FrontYard.tscn")
var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var front_yard := FRONT_YARD_SCENE.instantiate()
	root.add_child(front_yard)
	await process_frame
	await process_frame
	var grid := front_yard.get_node_or_null("Background/Grass/LawnGrid") as LawnGrid
	_require(grid != null, "LawnGrid is missing")
	_require(grid.is_built(), "LawnGrid did not build")
	_require(grid.get_render_chunk_count() > 0, "No render chunks were created")
	_require(grid.get_render_instance_count() > 0, "No grass instances were created")
	var render_chunks: Dictionary = grid.render_chunks
	_require(render_chunks.size() == grid.get_render_chunk_count(), "Render chunk map is out of sync")
	_check_chunk_aabbs(grid)
	if _failed:
		quit(1)
		return
	var baseline_chunk_count := grid.get_render_chunk_count()
	var baseline_instance_count := grid.get_render_instance_count()
	var baseline_shadow_enabled := grid.settings.grass_cast_shadow
	_check_shadow_modes(
		grid,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if baseline_shadow_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	grid.settings.grass_cast_shadow = false
	grid.rebuild_all_cells()
	_check_shadow_modes(grid, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	grid.settings.grass_cast_shadow = true
	grid.rebuild_all_cells()
	_require(grid.get_render_chunk_count() == baseline_chunk_count, "Shadow toggle changed chunk count")
	_require(grid.get_render_instance_count() == baseline_instance_count, "Shadow toggle changed instance count")
	_check_shadow_modes(grid, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	if not baseline_shadow_enabled:
		grid.settings.grass_cast_shadow = false
		grid.rebuild_all_cells()
	if _failed:
		quit(1)
		return
	var target_cell := grid.get_cell(0, 0)
	_require(target_cell != null, "Target cell is missing")
	_require(grid.set_cell_grass_density(0, 0, 1), "Single-cell density rebuild failed")
	_require(grid.get_render_instance_count() < baseline_instance_count, "Single-cell density change had no effect")
	_require(grid.get_render_signature().length() > 0, "Render signature API returned an empty string")
	print("grass_chunks=", grid.get_render_chunk_count())
	print("grass_instances=", grid.get_render_instance_count())
	print("grass_signature_length=", grid.get_render_signature().length())
	quit(1 if _failed else 0)

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _check_chunk_aabbs(grid: LawnGrid) -> void:
	var checked_renderer := false
	var old_height_bound := grid.settings.model_grass_scale * 1.12 * 3.0 * (1.0 + grid.settings.height_noise_strength)
	var tighter_than_old_bound := false
	var checked_non_origin_transform := false
	for chunk_key in grid.render_chunks.keys():
		var chunk_value = grid.render_chunks[chunk_key]
		var chunk := chunk_value as Node3D
		if chunk == null:
			continue
		var expected := _compute_chunk_geometry_bounds(grid, chunk_key)
		if expected.size == Vector3.ZERO:
			continue
		if absf(expected.position.x) > 0.1 or absf(expected.position.z) > 0.1:
			checked_non_origin_transform = true
		var renderers: Array[MultiMeshInstance3D] = []
		for child in chunk.get_children():
			var renderer := child as MultiMeshInstance3D
			if renderer == null or renderer.multimesh == null or renderer.multimesh.mesh == null:
				continue
			renderers.append(renderer)
		if renderers.is_empty():
			continue
		for renderer in renderers:
			if not renderer.multimesh.custom_aabb.encloses(expected.grow(0.01)):
				print("aabb_actual=", renderer.multimesh.custom_aabb, " expected=", expected.grow(0.01), " chunk=", chunk.name)
			_require(renderer.multimesh.custom_aabb.encloses(expected.grow(0.01)), "Chunk custom AABB does not enclose transformed grass")
			if renderer.multimesh.custom_aabb.size.y < old_height_bound:
				tighter_than_old_bound = true
			checked_renderer = true
	_require(checked_renderer, "No populated grass renderer was available for AABB checks")
	_require(checked_non_origin_transform, "Chunk bounds did not include translated cell transforms")
	_require(tighter_than_old_bound, "Chunk AABB still uses the old fixed-height bound")

func _compute_chunk_geometry_bounds(grid: LawnGrid, chunk_key: Vector2i) -> AABB:
	var expected := AABB()
	var has_expected := false
	for row in range(chunk_key.x * grid.render_chunk_rows, mini((chunk_key.x + 1) * grid.render_chunk_rows, grid.rows)):
		for column in range(chunk_key.y * grid.render_chunk_columns, mini((chunk_key.y + 1) * grid.render_chunk_columns, grid.columns)):
			var cell := grid.cells.get(Vector2i(row, column)) as LawnCell
			if cell == null:
				continue
			var batches := cell.get_model_instance_batches()
			var transforms_by_variant: Array = batches.get("transforms_by_variant", [])
			for variant_index in range(mini(transforms_by_variant.size(), grid._model_grass_meshes.size())):
				var mesh_bounds := grid._model_grass_meshes[variant_index].get_aabb()
				for local_transform in transforms_by_variant[variant_index]:
					var instance_bounds := _transform_aabb(cell.transform * local_transform, mesh_bounds)
					expected = instance_bounds if not has_expected else expected.merge(instance_bounds)
					has_expected = true
	if not has_expected:
		return AABB()
	return _expand_aabb_xz(expected, absf(grid.settings.grass_wind_strength))

func _check_shadow_modes(grid: LawnGrid, expected_shadow_mode: int) -> void:
	var checked_renderer := false
	for chunk_value in grid.render_chunks.values():
		var chunk := chunk_value as Node3D
		if chunk == null:
			continue
		for child in chunk.get_children():
			var renderer := child as MultiMeshInstance3D
			if renderer == null or renderer.multimesh == null or renderer.multimesh.instance_count == 0:
				continue
			_require(renderer.cast_shadow == expected_shadow_mode, "Grass renderer shadow mode is incorrect")
			checked_renderer = true
	_require(checked_renderer, "No populated renderer was available for shadow checks")

func _transform_aabb(transform: Transform3D, local_bounds: AABB) -> AABB:
	var local_center := local_bounds.position + local_bounds.size * 0.5
	var local_half := local_bounds.size * 0.5
	var world_center := transform * local_center
	var basis := transform.basis
	var world_half := Vector3(
		absf(basis.x.x) * local_half.x + absf(basis.y.x) * local_half.y + absf(basis.z.x) * local_half.z,
		absf(basis.x.y) * local_half.x + absf(basis.y.y) * local_half.y + absf(basis.z.y) * local_half.z,
		absf(basis.x.z) * local_half.x + absf(basis.y.z) * local_half.y + absf(basis.z.z) * local_half.z
	)
	return AABB(world_center - world_half, world_half * 2.0)

func _expand_aabb_xz(aabb: AABB, margin: float) -> AABB:
	var safe_margin := maxf(margin, 0.0)
	aabb.position.x -= safe_margin
	aabb.position.z -= safe_margin
	aabb.size.x += safe_margin * 2.0
	aabb.size.z += safe_margin * 2.0
	return aabb
