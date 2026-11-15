extends plant_template

@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2

func play_attack():
	animation_player_2.play("attack")

func idle_code():
	animation_player_2.play("idle")
