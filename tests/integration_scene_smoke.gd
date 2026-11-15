extends SceneTree
## Run with --script; add -- --capture with a real renderer for visual evidence.

var _failures: Array[String] = []
var _checks := 0
var _capture_enabled := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _capture(name: String) -> void:
	if not _capture_enabled:
		return
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	_check(not screenshot.is_empty(), "Rendered " + name)
	_check(screenshot.save_png("res://tools/logs/" + name + ".png") == OK, "Captured " + name)


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void: quit(1))
	_capture_enabled = "--capture" in OS.get_cmdline_user_args()
	_check(root.get_node_or_null("Audiomanager") != null, "Shared audio singleton exists")
	_check(root.get_node_or_null("AudioManager") == null, "No duplicate legacy audio singleton")
	var audio_singleton := root.get_node("Audiomanager")
	var settings_singleton := root.get_node("Settings")
	var master_bus := AudioServer.get_bus_index("Master")
	var master_muted := AudioServer.is_bus_mute(master_bus)
	var master_volume_db := AudioServer.get_bus_volume_db(master_bus)
	var scene_paths := [
		"res://3d/scenes/maps/front_yard/FrontYard.tscn",
		"res://3d/scenes/maps/front_yard/EcsFrontYardDemo.tscn",
		"res://3d/scenes/cards_box/CardsBox.tscn",
	]
	for scene_path: String in scene_paths:
		_check(change_scene_to_file(scene_path) == OK, "Open " + scene_path)
		await scene_changed
		await _settle()
		var instance := current_scene
		if scene_path.ends_with("FrontYard.tscn"):
			var grid := instance.get_node("Background/Grass/LawnGrid") as LawnGrid
			_check(grid.is_built() and grid.get_render_instance_count() > 0, "FrontYard builds grass")
			var settings_panel := instance.get_node("UI/Setting") as Control
			settings_panel.hide()
			await _settle()
			await _capture("front_yard")
			settings_panel.show()
			await _settle()
			await _capture("shared_settings")
			settings_panel.call("_on_close_button_pressed")
			_check(not settings_panel.visible, "Shared settings closes")
			var master_slider := settings_panel.find_children("*", "AudioSlider", true, false)
			for slider in master_slider:
				if slider.get("bus_name") == "Master":
					slider.set("value", 0.0)
			_check(AudioServer.is_bus_mute(master_bus), "3D Master slider can mute without saving")
		elif scene_path.ends_with("EcsFrontYardDemo.tscn"):
			var controller := instance.get_node("Manager/DemoController")
			var runner := controller.get_node("EcsRunner") as EcsRunner
			var initial_count := runner.world.entity_count()
			_check(initial_count > 0, "Demo creates zombies")
			instance.get_node("FrontYard/Manager/PlantLogic").emit_signal("cell_clicked", Vector2i(2, 4))
			_check(runner.world.entity_count() == initial_count + 1, "Shared input signal plants in ECS")
			await _settle()
			await _capture("ecs_front_yard")
			controller.call("_on_reset_pressed")
			_check(runner.world.entity_count() == initial_count, "Demo reset preserves original entity count")
		else:
			_check(instance.get("selected_card") == "queen", "Cards preview starts on the pea shooter")
			instance.call("_on_king_button_pressed")
			_check(instance.get("selected_card") == "king", "Cards preview navigation works")
			await _settle()
			await _capture("cards_box")
		_check(root.get_node("Audiomanager") == audio_singleton, "Audio singleton survives scene changes")
		_check(root.get_node("Settings") == settings_singleton, "2D settings singleton survives scene changes")
		_check(not settings_singleton.get("ingameset").visible, "2D pause panel stays hidden in 3D")
		_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) == OK, "Return from 3D to 2D main")
		await scene_changed
		await _settle()
		_check(current_scene.has_method("_on_story_pressed"), "2D menu works after 3D scenes")
		_check(AudioServer.is_bus_mute(master_bus) == master_muted, "3D mute does not leak into 2D")
		_check(is_equal_approx(AudioServer.get_bus_volume_db(master_bus), master_volume_db), "3D Master volume does not leak into 2D")
	print("INTEGRATION SCENES RESULT ", JSON.stringify({"checks": _checks, "failures": _failures}))
	_stop_audio(root)
	await create_timer(0.2).timeout
	quit(0 if _failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
