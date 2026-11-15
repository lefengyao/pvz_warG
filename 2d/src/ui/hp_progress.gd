extends TextureProgressBar

@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar


func _ready() -> void :
	value = 100
	texture_progress_bar.value = 100

func update(max_hp: float, current_hp: float):
	value = current_hp / max_hp * 100
	if value != texture_progress_bar.value:
		var tween = create_tween()

		tween.tween_property(
			texture_progress_bar, 
			"value", 
			value, 
			1.0
		)
