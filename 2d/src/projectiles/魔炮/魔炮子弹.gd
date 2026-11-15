extends pean_template


var mode: int = 0

func _ready() -> void :
	if randf_range(0, 1.0) < 0.05:
		mode = 1
		attack *= 3
		animated_sprite_2d.play("idle2")
	else:
		animated_sprite_2d.play("idle1")

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object) and not is_attacked:
		if mode == 1:
			is_attacked = true
			speed = 0
			Audiomanager.play_sfx(pean_sfx)
		extra_effect(area)
		area.take_damage(attack, ammo_type)
		animated_sprite_2d.play("attack")
		await get_tree().create_timer(0.3).timeout
		if mode == 1:
			queue_free()
		animated_sprite_2d.play("idle1")
