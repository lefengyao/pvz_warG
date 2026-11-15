extends pean_template

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object) and not is_attacked:
		is_attacked = true
		speed = 0
		extra_effect(area)
		area.take_damage(attack, ammo_type)
		queue_free()
	pass
