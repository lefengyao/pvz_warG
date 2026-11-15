extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var example_paths: Array[String] = [
		"res://addons/ecsmini/examples/2d/Movement2D.tscn",
		"res://addons/ecsmini/examples/3d/Movement3D.tscn",
	]
	var host_demo_path := "res://3d/scenes/maps/front_yard/EcsFrontYardDemo.tscn"
	if ResourceLoader.exists(host_demo_path):
		example_paths.append(host_demo_path)
	for path in example_paths:
		if not ResourceLoader.exists(path):
			_failures += 1
			push_error("Runnable example is missing: " + path)
			continue
		var scene: PackedScene = load(path)
		if scene == null:
			_failures += 1
			continue
		var instance := scene.instantiate()
		root.add_child(instance)
		await process_frame
		await process_frame
		var controller := instance.get_node("Manager/DemoController")
		var runner := controller.get_node("EcsRunner")
		var world: RefCounted = runner.get("world")
		var world_ref := weakref(world)
		var count: int = world.call("entity_count")
		if count <= 0:
			_failures += 1
			push_error("Example has no live entities: " + path)
		if path.ends_with("Movement3D.tscn"):
			if not bool(runner.get("use_physics_process")) or not bool(runner.get("separate_presentation")) or not runner.is_processing() or not runner.is_physics_processing():
				_failures += 1
				push_error("3D example must use fixed simulation and separate presentation clocks")
			_check_debug_presentation(instance, world)
		if path.ends_with("EcsFrontYardDemo.tscn"):
			var plant_logic := instance.get_node("FrontYard/Manager/PlantLogic")
			plant_logic.emit_signal("cell_clicked", Vector2i(1, 2))
			if int(world.call("entity_count")) != count + 1:
				_failures += 1
				push_error("FrontYard cell signal did not create a plant")
			plant_logic.emit_signal("cell_clicked", Vector2i(1, 2))
			if int(world.call("entity_count")) != count:
				_failures += 1
				push_error("FrontYard repeated cell signal did not remove its plant")
			await _check_front_yard_input(instance, controller, world, count)
		controller.call("_on_reset_pressed")
		if int(world.call("entity_count")) != count:
			_failures += 1
			push_error("Example reset did not restore initial entities: " + path)
		world = null
		instance.free()
		await process_frame
		if world_ref.get_ref() != null:
			_failures += 1
			push_error("Example teardown retained its world: " + path)
	print("ECS example smoke failures: %d" % _failures)
	quit(1 if _failures else 0)


func _check_front_yard_input(instance: Node, controller: Node, world: RefCounted, initial_count: int) -> void:
	var camera := instance.get_node("FrontYard/Camera3D") as Camera3D
	var grid := instance.get_node("FrontYard/Background/Grass/LawnGrid")
	var cell: Node3D = grid.call("get_cell", 2, 4)
	var click_position := camera.unproject_position(cell.global_position)
	_click_at(click_position)
	await process_frame
	if int(world.call("entity_count")) != initial_count + 1:
		_failures += 1
		push_error("FrontYard actual lawn click did not pass through PlantLogic")
	controller.call("_on_reset_pressed")
	controller.call("_on_settings_pressed")
	await process_frame
	_click_at(click_position)
	await process_frame
	if int(world.call("entity_count")) != initial_count:
		_failures += 1
		push_error("FrontYard settings UI did not block planting input")
	controller.call("_on_settings_pressed")
	var header := instance.get_node("DemoUI/DemoHeader") as Control
	_click_at(header.get_global_rect().position + Vector2(15.0, 15.0))
	await process_frame
	if int(world.call("entity_count")) != initial_count:
		_failures += 1
		push_error("FrontYard demo header did not block planting input")
	var zombie_query: RefCounted = world.call("query", {"all": [&"zombie", &"position3d", &"row"]})
	for entity_id in zombie_query.call("entities"):
		var row: int = world.call("get_component", entity_id, &"row")
		var row_cell: Node3D = grid.call("get_cell", row, 0)
		var zombie_position: Vector3 = world.call("get_component", entity_id, &"position3d")
		if not is_equal_approx(grid.call("to_local", zombie_position).z, row_cell.position.z):
			_failures += 1
			push_error("FrontYard zombie moved outside its grid row")


func _check_debug_presentation(instance: Node, world: RefCounted) -> void:
	var panel := instance.get_node("DemoUI/EcsDebugPanel") as Control
	if panel.call("get_world") != world or not bool(world.get("profiling_enabled")):
		_failures += 1
		push_error("3D debug example did not attach its profiled world")
	var panel_rect := panel.get_global_rect()
	if not Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0)).encloses(panel_rect):
		_failures += 1
		push_error("3D debug panel does not fit the 1920 x 1080 viewport")
	var camera := instance.get_node("Presentation/Stage/Camera3D") as Camera3D
	for horizontal_edge in [-8.5, 8.5]:
		for depth_edge in [-4.5, 4.5]:
			var corner := camera.unproject_position(Vector3(horizontal_edge, 0.6, depth_edge))
			if panel_rect.has_point(corner + Vector2(20.0, 0.0)):
				_failures += 1
				push_error("3D debug panel overlaps the pawn movement area")


func _click_at(screen_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = screen_position
	root.push_input(motion)
	var press := InputEventMouseButton.new()
	press.position = screen_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.position = screen_position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release)
