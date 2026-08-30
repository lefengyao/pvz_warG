extends SceneTree


const SETTINGS_SCENE := preload("res://Scene/Settings/Setting.tscn")
const MODULE_PATHS := [
	NodePath("SettingsLayout"),
	NodePath("SettingsLayout/NavigationModule"),
	NodePath("SettingsLayout/NavigationModule/CategoryNavigation"),
	NodePath("SettingsLayout/ContentModule"),
	NodePath("SettingsLayout/ContentModule/SectionHeader"),
	NodePath("SettingsLayout/ContentModule/SectionContent"),
	NodePath("OverlayLayer/WindowControls"),
]
var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings_panel := SETTINGS_SCENE.instantiate()
	root.add_child(settings_panel)

	for module_path: NodePath in MODULE_PATHS:
		_require(settings_panel.get_node_or_null(module_path) != null, "Missing settings module: %s" % module_path)
	if _failed:
		quit(1)
		return

	var audio_button := settings_panel.get_node_or_null("SettingsLayout/NavigationModule/CategoryNavigation/AudioButton") as Button
	var general_button := settings_panel.get_node_or_null("SettingsLayout/NavigationModule/CategoryNavigation/GeneralButton") as Button
	var section_title := settings_panel.get_node_or_null("SettingsLayout/ContentModule/SectionHeader/SectionTitle") as Label
	var audio_settings := settings_panel.get_node_or_null("SettingsLayout/ContentModule/SectionContent/AudioSettings") as Control
	if audio_button == null or general_button == null or section_title == null or audio_settings == null:
		_require(false, "Settings navigation or content nodes are missing")
		quit(1)
		return

	_require(section_title.text == "声音设置" and audio_settings.visible, "Audio section must be selected by default")
	if _failed:
		quit(1)
		return

	general_button.emit_signal("pressed")
	_require(section_title.text == "通用设置" and not audio_settings.visible, "Selecting another category must retain the existing section behavior")

	quit(1 if _failed else 0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
