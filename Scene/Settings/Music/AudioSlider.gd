class_name AudioSlider
extends Control

const SAVE_PATH := "user://audio_settings.json"
const MIN_VOLUME_RATIO := 0.0001
const MIN_VALUE := 0.0
const MAX_VALUE := 100.0

@export var bus_name: String = "music"
@export var setting_label: String = "音乐音量"
@export_range(MIN_VALUE, MAX_VALUE, 1.0) var value: float = MAX_VALUE:
	set(new_value):
		value = clampf(new_value, MIN_VALUE, MAX_VALUE)
		if is_node_ready():
			_refresh()

@onready var title_label: Label = $TitleLabel
@onready var value_label: Label = $ValueLabel
@onready var track: ColorRect = $Track
@onready var fill: ColorRect = $Track/Fill
@onready var handle: ColorRect = $Handle

var bus_index := -1
var is_dragging := false
var is_dirty := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bus_index = _ensure_audio_bus(bus_name)

	load_settings()
	resized.connect(_refresh)
	_refresh()


func _ensure_audio_bus(requested_bus_name: String) -> int:
	if requested_bus_name.is_empty():
		push_warning("音频滑块未配置总线名称")
		return -1

	var index := AudioServer.get_bus_index(requested_bus_name)
	if index != -1:
		return index

	# Standalone scenes may not have a project-level bus layout. Create missing
	# buses at runtime so the control remains portable.
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, requested_bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_dirty:
		save_settings()


# Settings are shared by every audio slider in one simple JSON object.
func _load_settings() -> Dictionary:
	var defaults := {
		"Master": MAX_VALUE,
		"music": MAX_VALUE,
		"sfx": MAX_VALUE,
	}
	if not FileAccess.file_exists(SAVE_PATH):
		return defaults

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[AudioSlider] 无法读取音频设置")
		return defaults

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		push_warning("[AudioSlider] 音频设置 JSON 无效，第 %d 行: %s" % [json.get_error_line(), json.get_error_message()])
		return defaults

	if json.data is not Dictionary:
		push_warning("[AudioSlider] 音频设置必须是 JSON 对象")
		return defaults

	var saved_values: Dictionary = json.data
	for key: String in defaults:
		var saved_value: Variant = saved_values.get(key)
		if saved_value is float or saved_value is int:
			defaults[key] = clampf(float(saved_value), MIN_VALUE, MAX_VALUE)
	return defaults


func load_settings() -> void:
	var settings := _load_settings()
	var saved_value: Variant = settings.get(bus_name, value)
	if saved_value is float or saved_value is int:
		value = float(saved_value)


func save_settings() -> void:
	var settings := _load_settings()
	settings[bus_name] = roundi(value)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[AudioSlider] 无法保存音频设置")
		return

	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	is_dirty = false


func _refresh() -> void:
	if not is_node_ready():
		return

	var ratio := inverse_lerp(MIN_VALUE, MAX_VALUE, value)
	title_label.text = setting_label
	value_label.text = "%d%%" % roundi(value)
	fill.size.x = track.size.x * ratio
	handle.position = Vector2(
		track.position.x + (track.size.x - handle.size.x) * ratio,
		track.position.y + (track.size.y - handle.size.y) * 0.5,
	)
	handle.color = Color("f1b95f") if is_dragging else Color("f5d694")
	_update_audio(ratio)


func _update_audio(volume_ratio: float) -> void:
	if bus_index == -1:
		return

	if volume_ratio <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
		return

	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume_ratio, MIN_VOLUME_RATIO)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		_update_value_from_mouse(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and is_dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_update_value_from_mouse(event.position.x)
		accept_event()


func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		_refresh()
		if is_dirty:
			save_settings()


func _update_value_from_mouse(mouse_x: float) -> void:
	if track.size.x <= 0.0:
		return

	var track_x := track.position.x
	var clamped_x := clampf(mouse_x - track_x, 0.0, track.size.x)
	var new_value := lerpf(MIN_VALUE, MAX_VALUE, clamped_x / track.size.x)
	if not is_equal_approx(new_value, value):
		is_dirty = true
		value = new_value
