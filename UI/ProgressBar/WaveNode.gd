extends Sprite2D
@onready var sprite_2d: Sprite2D = $Sprite2D

var trigger_wave: int

func detect(wave):
	if wave == trigger_wave:
		sprite_2d.visible = false
		scale = Vector2(1.2, 1.2)
