extends TextureButton

var is_flowing: bool = false

signal chan
var init_position: Vector2 = position

func _process(_delta: float) -> void :

	if is_flowing:
		global_position = get_global_mouse_position() - size / 4
	pass

func _on_button_down() -> void :
	if is_flowing:

		chan.emit()
		position = init_position
		is_flowing = false
	else:
		is_flowing = true
	pass
