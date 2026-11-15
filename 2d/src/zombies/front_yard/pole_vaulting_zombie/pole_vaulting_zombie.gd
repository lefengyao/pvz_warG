extends zombie_template





@export var run_speed_multiplier: float = 3.0
@export var walk_speed_multiplier: float = 0.7


@export var pole: PackedScene


@export var pole_sfx: AudioStream
@export var slide_sfx: AudioStream

@onready var sprite_2d: Sprite2D = $Sprite2D


var thrown_pole: Area2D = null


var run_completed: bool = false


var speed_ratio: float = 1.0


var nomal_vision: int = -35

signal die

func dead_effect():
	die.emit()




func _ready() -> void :

	super._ready()

	state_machine.change_state("RUN")





func check_dash_ray(ray: RayCast2D) -> Dictionary:
	if not ray.is_colliding():
		return {"type": "none", "body": null}

	var body = ray.get_collider()
	if body == null:
		return {"type": "none", "body": null}


	if body == thrown_pole:
		return {"type": "pole", "body": body}


	if body.global_position.x < Globalmanager.right_boder_x and body.is_in_group(character.attack_object):
		return {"type": "plant", "body": body}


	return {"type": "none", "body": null}


func ready_effect():

	super.ready_effect()

	sprite_2d.visible = false
