extends Control

const SECTION_TITLES := {
	"general": "通用设置",
	"audio": "声音设置",
	"display": "画面设置",
	"controls": "操作设置",
	"accessibility": "辅助设置",
}
const ACTIVE_COLOR := Color("e4b565")
const INACTIVE_COLOR := Color("aebbc0")

@onready var section_title: Label = $SettingsLayout/ContentModule/SectionHeader/SectionTitle
@onready var selection_marker: ColorRect = $SettingsLayout/NavigationModule/SelectionMarker
@onready var category_navigation: VBoxContainer = $SettingsLayout/NavigationModule/CategoryNavigation
@onready var audio_settings: Control = $SettingsLayout/ContentModule/SectionContent/AudioSettings
@onready var general_button: Button = $SettingsLayout/NavigationModule/CategoryNavigation/GeneralButton
@onready var audio_button: Button = $SettingsLayout/NavigationModule/CategoryNavigation/AudioButton
@onready var display_button: Button = $SettingsLayout/NavigationModule/CategoryNavigation/DisplayButton
@onready var controls_button: Button = $SettingsLayout/NavigationModule/CategoryNavigation/ControlsButton
@onready var accessibility_button: Button = $SettingsLayout/NavigationModule/CategoryNavigation/AccessibilityButton

var buttons: Dictionary
var selected_section := "audio"


func _ready() -> void:
	buttons = {
		"general": general_button,
		"audio": audio_button,
		"display": display_button,
		"controls": controls_button,
		"accessibility": accessibility_button,
	}
	resized.connect(_refresh_selection_marker)
	_select_section("audio")
	call_deferred("_refresh_selection_marker")


func _select_section(section: String) -> void:
	if not buttons.has(section):
		return

	selected_section = section
	section_title.text = SECTION_TITLES[section]
	audio_settings.visible = section == "audio"
	for section_key: String in buttons:
		var button: Button = buttons[section_key]
		button.add_theme_color_override("font_color", ACTIVE_COLOR if section_key == section else INACTIVE_COLOR)
	_refresh_selection_marker()


func _refresh_selection_marker() -> void:
	if not buttons.has(selected_section):
		return

	var selected_button: Button = buttons[selected_section]
	selection_marker.position.y = category_navigation.position.y + selected_button.position.y + (selected_button.size.y - selection_marker.size.y) * 0.5


func _on_general_button_pressed() -> void:
	_select_section("general")


func _on_audio_button_pressed() -> void:
	_select_section("audio")


func _on_display_button_pressed() -> void:
	_select_section("display")


func _on_controls_button_pressed() -> void:
	_select_section("controls")


func _on_accessibility_button_pressed() -> void:
	_select_section("accessibility")


func _on_close_button_pressed() -> void:
	hide()
