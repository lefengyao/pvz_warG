extends Area2D
class_name plant_template

@export var character: general_character
@export var ate_sfx: AudioStream
@onready var ray_cast_2d: RayCast2D = $AnimatedSprite2D / RayCast2D
@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var marker_2d: Marker2D = $AnimatedSprite2D / Marker2D

var raycast_body

@export var sun_num: int
@export var cool_time: float

@export var cooling: bool = true
@export var tex: Texture2D
@export var tex2: Texture2D

signal dead

func dead_():
	emit_dead()
	Audiomanager.play_sfx(ate_sfx)
	queue_free()
func _process(_delta: float) -> void :
	if character.current_health <= 0:
		dead_()


func raycast_body_effect1(_raycast_body):
	pass

func raycast_body_effect2():
	pass


func emit_dead():
	dead.emit(character.row, character.column)

func take_damage(_attack, _ammo_type):
	if _ammo_type == 2 and character.current_health <= _attack:
		Audiomanager.play_sfx(ate_sfx)
	character.current_health -= _attack




func check_attack_ray(ray: RayCast2D) -> Array:
	if ray.is_colliding():
		var body = ray.get_collider()
		if body != null:

			if body.global_position.x < Globalmanager.right_boder_x and body.is_in_group(character.attack_object):
				return [true, body]
	return [false, null]
