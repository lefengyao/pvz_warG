extends Area2D
class_name pean_template
@export var speed: int = 300
@export var attack: int = 20
@export var pean_sfx: AudioStream
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var attack_object: String

@export var ammo_type: int = 1
@export var is_run: bool = true
var is_attacked: bool = false

func _physics_process(delta: float) -> void :
	if is_run: position.x += delta * speed
	if global_position.x > 2200 or global_position.x < -500:
		queue_free()

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object) and not is_attacked:
		is_attacked = true
		speed = 0
		extra_effect(area)
		area.take_damage(attack, ammo_type)
		animated_sprite_2d.play("attack")
		Audiomanager.play_sfx(pean_sfx)
		await get_tree().create_timer(0.3).timeout
		queue_free()

func extra_effect(_area):
	pass
