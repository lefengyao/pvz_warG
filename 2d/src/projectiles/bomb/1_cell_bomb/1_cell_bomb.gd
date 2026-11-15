extends Area2D

@export var attack: int = 1500
@export var bomb_sfx: AudioStream
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var attack_object: String

var attack_type: int = 3
func _ready() -> void :
	animated_sprite_2d.play("bomb")
	Audiomanager.play_sfx(bomb_sfx)
	await animated_sprite_2d.animation_finished
	queue_free()

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object):
		print(1)
		area.take_damage(attack, attack_type)
