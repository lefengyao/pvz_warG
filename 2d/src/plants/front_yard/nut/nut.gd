extends plant_template
@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2

func _ready() -> void :
	animation_player_2.play("swing")

func _process(_delta: float) -> void :
	if character.current_health <= 0:
		dead_()
	elif character.current_health < character.max_health * 0.33:
		animated_sprite_2d.play("idle3")
	elif character.current_health < character.max_health * 0.66:
		animated_sprite_2d.play("idle2")
	else:
		animated_sprite_2d.play("idle1")
