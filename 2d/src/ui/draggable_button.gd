extends TextureProgressBar


@onready var label: Label = $Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var marker_2d: Marker2D = $Marker2D


@export var tex1: Texture2D
@export var tex2: Texture2D
@export var tex3: Texture2D
@export var bus_name: String = "music"


const START_POS: Vector2 = Vector2(-12, -2)
const SAVE_PATH: String = "user://audio_settings.tres"


var is_dragging: bool = false
var bus_index: int = -1


func _ready() -> void :

	bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("找不到音频总线: " + bus_name)


	load_settings()


	value_changed.connect(_on_value_changed)
	_on_value_changed(value)







func load_settings() -> void :
	print("[Audio UI] 正在加载音频设置: ", SAVE_PATH)
	if not ResourceLoader.exists(SAVE_PATH):
		print("[Audio UI] 存档不存在，使用默认值")
		return

	var res: Resource = ResourceLoader.load(SAVE_PATH)
	if res is musicset:

		if bus_name == "music":
			value = res.music_volume
		elif bus_name == "sfx":
			value = res.sfx_volume
		print("[Audio UI] 加载成功: music=%d, sfx=%d" % [res.music_volume, res.sfx_volume])
	else:
		push_warning("[Audio UI] 存档类型不匹配，使用默认值")



func save_settings() -> void :
	print("[Audio UI] 正在保存音频设置...")


	var current: musicset = null
	if ResourceLoader.exists(SAVE_PATH):
		var existing: Resource = ResourceLoader.load(SAVE_PATH)
		if existing is musicset:
			current = existing
			print("[Audio UI] 读取现有存档: music=%d, sfx=%d" % [current.music_volume, current.sfx_volume])
		else:
			push_warning("[Audio UI] 现有存档损坏，将创建新存档")


	if current == null:
		current = musicset.new()
		print("[Audio UI] 创建新的音频设置资源")


	if bus_name == "music":
		current.music_volume = int(value)
		print("[Audio UI] 更新音乐音量为: ", current.music_volume)
	elif bus_name == "sfx":
		current.sfx_volume = int(value)
		print("[Audio UI] 更新音效音量为: ", current.sfx_volume)


	var err: int = ResourceSaver.save(current, SAVE_PATH)
	if err == OK:
		print("[Audio UI] 保存成功: ", SAVE_PATH)
	else:
		push_error("[Audio UI] 保存失败，错误码: ", err)







func _on_value_changed(new_value: float) -> void :

	_update_audio(new_value)


	var percent: int = int(float(new_value) / float(max_value) * 100.0)
	label.text = str(percent) + "%"


	_update_texture()
	_update_handle_position()



func _update_audio(val: float) -> void :
	if bus_index == -1:
		return

	var value_ratio: float = val / float(max_value)
	if value_ratio <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		var db: float = linear_to_db(value_ratio)
		AudioServer.set_bus_volume_db(bus_index, db)



func _update_texture() -> void :
	if value <= 0.0:
		texture_rect.texture = tex3
	elif is_dragging:
		texture_rect.texture = tex2
	else:
		texture_rect.texture = tex1



func _update_handle_position() -> void :
	if texture_rect == null or size.x <= 0.0:
		return

	var value_ratio: float = float(value) / float(max_value)


	var end_pos: Vector2
	if marker_2d:
		end_pos = marker_2d.position
	else:
		end_pos = Vector2(size.x - texture_rect.size.x, texture_rect.position.y)

	texture_rect.position = START_POS.lerp(end_pos, value_ratio)







func _on_gui_input(event: InputEvent) -> void :
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:

				is_dragging = true
				_update_value_from_mouse(event.position.x)
				accept_event()
			else:

				is_dragging = false
				_update_texture()

				save_settings()
				accept_event()

	elif event is InputEventMouseMotion:

		if is_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_update_value_from_mouse(event.position.x)
			accept_event()



func _update_value_from_mouse(mouse_x: float) -> void :
	if size.x <= 0.0:
		return

	var value_ratio: float = clamp(mouse_x / float(size.x), 0.0, 1.0)
	value = value_ratio * float(max_value)
