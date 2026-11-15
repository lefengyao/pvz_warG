extends Area2D








@export var speed: int = 500

@export var attack: int = 200

@export var ammo_type: int = 1


@export var changmao: AudioStream

@onready var animation_player: AnimationPlayer = $AnimationPlayer


var attack_object: String = ""


var is_attacked: bool = false


func _physics_process(delta: float) -> void :

	if is_attacked:
		return


	position.x += delta * speed


	if global_position.x > 1500 or global_position.x < -500:
		queue_free()



func _on_area_entered(area: Area2D) -> void :

	if is_attacked:
		return


	if not area.is_in_group(attack_object):
		return


	is_attacked = true
	speed = 0


	animation_player.play("stop")
	Audiomanager.play_sfx(changmao)


	area.take_damage(attack, ammo_type)


	var tween = create_tween()
	tween.tween_property(
		self, 
		"global_position:x", 
		global_position.x - 50, 
		0.3
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)



func dead():
	queue_free()
