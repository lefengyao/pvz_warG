extends TextureButton

class_name plant_template_card
@export var sun_num: int
@export var cool_time: float
@export var plant_card: PackedScene

@export var cooling: bool = true
var texture1: Texture2D
@onready var texture_rect: TextureRect = $TextureRect
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

var global_mouse_pos: Vector2
var is_flowing: bool = false
var disable: bool = false
var wait_sun: bool = false
var start_game: bool = false:
	set(index):
		start_game = index
		if start_game:
			modulate = Color8(255, 255, 255, 255)

var cd_time: float = 0.0
signal is_clicked

func _ready() -> void :
	texture_rect.texture = texture1
	modulate = Color8(100, 100, 100, 255)
	texture_rect.visible = false
	label.text = str(sun_num)
	pass


func _process(_delta: float) -> void :
	if start_game:
		if is_flowing:
			texture_rect.global_position = get_global_mouse_position() - texture_rect.size / 2
			pass
		if cooling:
			cd_time += _delta
			progress_bar.value = (cool_time - cd_time) / cool_time * 100
		if Globalmanager.suns.sun_num < sun_num:
			modulate = Color8(100, 100, 100, 255)
		else: modulate = Color8(255, 255, 255, 255)

func already_plant():
	is_flowing = false
	texture_rect.visible = false
	cooling = true
	cd_time = 0.0

func _on_button_down() -> void :
	if start_game:
		if is_flowing:
			texture_rect.visible = false
			is_flowing = false
		elif Globalmanager.suns.sun_num >= sun_num and not cooling:
			Globalmanager.play_click_successful_sfx()
			texture_rect.visible = true
			is_flowing = true
			is_clicked.emit(self)
		else:
			Globalmanager.play_click_failed_sfx(1)



func _on_progress_bar_value_changed(value: float) -> void :
	if value <= progress_bar.min_value:
		cooling = false
	pass
