extends Area2D

@export var attack: int = 20
var attack_object: String

@export var ammo_type: int = 3
func _on_timer_timeout() -> void :
	queue_free()
	pass


func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object):
		area.take_damage(attack, ammo_type)

	pass
