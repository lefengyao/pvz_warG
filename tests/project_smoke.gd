extends Node
## End-to-end resource and scene-flow checks using the real project Autoloads.

var failures: Array[String] = []
var loaded_count: int = 0
var checks: int = 0
var started_games: int = 0
var capture: bool = false


func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		push_error("SMOKE watchdog timeout")
		get_tree().quit(1)
	)
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("SMOKE FAIL: " + message)
	return condition


func _load_folder(folder: String) -> void:
	var directory := DirAccess.open(folder)
	if not _check(directory != null, "Open " + folder):
		return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() in ["gd", "gdshader", "tscn", "tres", "png", "svg", "mp3", "wav", "ogg", "ttf"]:
			var path := folder.path_join(file_name)
			if _check(ResourceLoader.load(path) != null, "Load " + path):
				loaded_count += 1
	for child in directory.get_directories():
		_load_folder(folder.path_join(child))


func _wait_until(predicate: Callable, label: String, timeout_seconds: float = 20.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _check(predicate.call(), label)


func _game_started() -> void:
	started_games += 1


func _open_level_selection(menu: Node) -> void:
	menu.get_node("MenuRoot/StoryButton").emit_signal("pressed")
	await _wait_until(func() -> bool: return menu.get_node("MapRoot").visible, "Story opens map cards")
	var cards := menu.get_node("MapRoot").find_children("*", "Control", true, false)
	for card in cards:
		var descriptor: Variant = card.get("info")
		if descriptor is MapInfo and not descriptor.locked:
			card.get_node("Body/CardButton").emit_signal("pressed")
			await get_tree().scene_changed
			return
	_check(false, "Unlocked courtyard map card exists")


func _check_save_migration() -> void:
	var legacy_scripts: Array[String] = [
		"res://" + "UI/UI/music/music_setting.gd",
		"res://" + "src/ui/music/music_setting.gd",
	]
	var case_index := 0
	for legacy_script in legacy_scripts:
		for existing_backup in [false, true]:
			_check_save_migration_case(legacy_script, existing_backup, case_index)
			case_index += 1


func _check_save_migration_case(legacy_script: String, existing_backup: bool, case_index: int) -> void:
	const CURRENT_SCRIPT := "res://shared/src/audio/music_setting.gd"
	var save_path := "user://layout_migration_test_%d_%d.tres" % [OS.get_process_id(), case_index]
	var backup_path := save_path + ".before_layout_migration.bak"
	var migrated_path := save_path + ".migration_tmp"
	var case_label := "%s (existing backup=%s)" % [legacy_script, existing_backup]
	if not _check(
		not FileAccess.file_exists(save_path)
		and not FileAccess.file_exists(backup_path)
		and not FileAccess.file_exists(migrated_path),
		"Migration fixture starts empty: " + case_label
	):
		return
	Settings.call("_migrate_audio_settings", save_path)
	_check(not FileAccess.file_exists(save_path), "Missing save remains missing: " + case_label)
	_check(not FileAccess.file_exists(backup_path), "Missing save creates no backup: " + case_label)
	var original := '[gd_resource type="Resource" script_class="musicset" format=3]\n\n'
	original += '[ext_resource type="Script" path="%s" id="1"]\n\n' % legacy_script
	original += '[resource]\nscript = ExtResource("1")\nmusic_volume = 37\nsfx_volume = 62\n'
	var fixture := FileAccess.open(save_path, FileAccess.WRITE)
	if not _check(fixture != null, "Create migration fixture: " + case_label):
		return
	fixture.store_string(original)
	fixture.close()
	var expected_backup := original
	if existing_backup:
		expected_backup = "Existing backup must remain unchanged.\n"
		var backup_fixture := FileAccess.open(backup_path, FileAccess.WRITE)
		if not _check(backup_fixture != null, "Create existing backup: " + case_label):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
			return
		backup_fixture.store_string(expected_backup)
		backup_fixture.close()
	Settings.call("_migrate_audio_settings", save_path)
	_check(
		FileAccess.get_file_as_bytes(backup_path) == expected_backup.to_utf8_buffer(),
		"Migration creates or preserves backup byte for byte: " + case_label
	)
	var first_pass := FileAccess.get_file_as_string(save_path)
	_check(first_pass == original.replace(legacy_script, CURRENT_SCRIPT), "Only script path changes: " + case_label)
	var migrated := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(migrated is musicset, "Legacy save loads with shared script: " + case_label)
	if migrated is musicset:
		_check(migrated.music_volume == 37 and migrated.sfx_volume == 62, "Both saved volume values preserved: " + case_label)
	Settings.call("_migrate_audio_settings", save_path)
	_check(first_pass == FileAccess.get_file_as_string(save_path), "Save migration is idempotent: " + case_label)
	_check(
		FileAccess.get_file_as_bytes(backup_path) == expected_backup.to_utf8_buffer(),
		"Repeated migration preserves backup: " + case_label
	)
	_check(not FileAccess.file_exists(migrated_path), "Migration leaves no temporary file: " + case_label)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _capture(name: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image != null and not image.is_empty(), "Rendered " + name)
	if image != null:
		_check(image.save_png("res://tools/logs/" + name + ".png") == OK, "Save " + name + " screenshot")


func _run() -> void:
	# Keep the runner as a root child while the real current scene changes.
	get_tree().current_scene = null
	capture = "--capture" in OS.get_cmdline_user_args()
	Engine.time_scale = 8.0
	GameProgressBus.game_started.connect(_game_started)
	_check_save_migration()
	for folder in ["res://2d", "res://shared"]:
		_load_folder(folder)
	print("SMOKE resources_loaded=", loaded_count)
	_check(AudioServer.get_bus_index("music") >= 0, "Music audio bus exists")
	_check(AudioServer.get_bus_index("sfx") >= 0, "SFX audio bus exists")
	_check(get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) == OK, "Start configured main scene")
	await get_tree().scene_changed
	var menu := get_tree().current_scene
	if not _check(menu != null and menu.has_method("_on_story_pressed"), "Main menu loaded"):
		_finish()
		return
	await _capture("main_menu")
	await _open_level_selection(menu)
	var selection := get_tree().current_scene
	if not _check(selection != null and selection.get("level_resources") != null, "Main menu opens level selection"):
		_finish()
		return
	var level_count: int = selection.get("level_resources").size()
	_check(level_count == 4, "Four configured front-yard levels")
	for index in range(level_count):
		selection = get_tree().current_scene
		selection.get("grid").emit_signal("level_selected", index)
		var descriptor: Resource = selection.get("level_resources")[index]
		print("SMOKE level=", index + 1, " name=", descriptor.get("level_name"))
		selection.get_node("StartButton").emit_signal("pressed")
		await get_tree().scene_changed
		var level := get_tree().current_scene
		if not _check(level != null and level.get("ui_all_cards") != null, "Level instantiated"):
			break
		var cards: Control = level.get("ui_all_cards")
		if not await _wait_until(func() -> bool: return cards.visible, "Camera enters card selection"):
			break
		var slots: GridContainer = cards.get("all_cards_slot")
		_check(slots.get_child_count() == GenerateCards.plant_cards.size(), "All plant cards generated")
		# Cover both complete and partial selections, including deselect/reselect.
		var selected_count := slots.get_child_count() if index % 2 == 0 else 3
		for card in slots.get_children().slice(0, selected_count):
			card.call("_on_button_down")
		var flow: HBoxContainer = cards.get("flow_cards_slot")
		flow.get_child(0).call("_on_button_down")
		await get_tree().process_frame
		_check(cards.get("current_num") == selected_count - 1, "Deselect plant card")
		slots.get_child(0).call("_on_button_down")
		_check(cards.get("current_num") == selected_count, "Reselect plant card")
		var before_start := started_games
		cards.call("_on_texture_button_button_down")
		if not await _wait_until(func() -> bool: return started_games > before_start, "Selection starts game"):
			break
		_check(Globalmanager.lawnmowers.get_child_count() == level.get("cell_row"), "Lawnmowers initialized")
		_check(level.get("card_selection").get("h_box_container").get_child_count() == selected_count, "Cards transferred to battle UI")
		var has_zombie := func() -> bool:
			for child in Globalmanager.zombies.get_children():
				if child.is_in_group("zombie"):
					return true
			return false
		if not await _wait_until(has_zombie, "First zombie wave spawns", 20.0):
			break
		if index == 0:
			await _capture("first_level_battle")
		_check(Globalmanager.suns.get("sun_num") != null, "Sun system initialized")
		Settings.ingameset.call("pause_game")
		_check(Settings.ingameset.visible and level.process_mode == Node.PROCESS_MODE_DISABLED, "Pause opens settings")
		Settings.ingameset.call("resume_game")
		_check(not Settings.ingameset.visible and level.process_mode == Node.PROCESS_MODE_INHERIT, "Resume returns to battle")
		Settings.ingameset.call("go_to_main_menu")
		await get_tree().scene_changed
		menu = get_tree().current_scene
		_check(menu.scene_file_path == "res://2d/scenes/levels/chose_map.tscn", "Return to main menu")
		if index < level_count - 1:
			await _open_level_selection(menu)
	_finish()


func _finish() -> void:
	_check(started_games == 4, "All four levels reached battle")
	print("SMOKE RESULT ", JSON.stringify({"resources_loaded": loaded_count, "checks": checks, "levels_started": started_games, "failures": failures}))
	# Let the audio thread retire active playbacks before engine shutdown.
	_stop_audio(get_tree().root)
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
