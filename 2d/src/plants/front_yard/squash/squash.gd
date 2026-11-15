extends plant_template

var enemy
@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2



func _process(_delta: float) -> void :
	if character.current_health <= 0:
		dead_()
