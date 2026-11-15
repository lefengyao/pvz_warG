extends Node2D

@onready var staff_stance: Node2D = $"../staff_stance"
var attack_object: String

@export var ammo_type: int = 1

var pigun_attack: int = 250
var chuogun_attack: int = 150

func _on_area_2_dpigun_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object):
		area.take_damage(pigun_attack * staff_stance.current_phase, ammo_type)
	pass


func _on_area_2_dchuogun_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object):
		area.take_damage(chuogun_attack * staff_stance.current_phase, ammo_type)
	pass
