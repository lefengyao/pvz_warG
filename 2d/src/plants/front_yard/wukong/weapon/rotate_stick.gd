extends Area2D

@export var speed: int = 100
@export var attack: int = 20

var max_hits: int = 3
var hits: int = 0

@export var rotation_speed: float = 1080.0
var attack_object: String

@export var ammo_type: int = 1

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object):
		area.take_damage(attack, ammo_type)
		hits += 1
		if hits > max_hits: queue_free()


func _physics_process(delta: float) -> void :
	global_position.x += delta * speed



	rotation += deg_to_rad(rotation_speed) * delta

	if global_position.x > 1500 or global_position.x < -500:
		queue_free()
