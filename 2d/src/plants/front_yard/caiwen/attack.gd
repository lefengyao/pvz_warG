extends normal_attack

func attack():
	var bullet = owner_root.melee_挂场景上调整使用_.duplicate()
	bullet.global_position = owner_root.marker_2d.global_position
	bullet.attack_object = owner_root.character.attack_object
	bullet.z_index = owner_root.character.row * 10 + 3
	bullet.monitoring = true
	bullet.visible = true
	Globalmanager.bullets.add_child(bullet)

var right: bool = true
var left: bool = false

func raycast_body_effect1(_raycast_body):
	if _raycast_body:
		if _raycast_body.global_position.x <= owner_root.global_position.x:
			owner_root.animated_sprite_2d.scale.x = -1
			left = true
			right = false
		else:
			owner_root.animated_sprite_2d.scale.x = 1
			left = false
			right = true
		if _raycast_body.character.current_health < 100:
			_raycast_body.character.current_health = 0
			if right:
				owner_root.gpu_particles_2d.slay()
			else:
				owner_root.gpu_particles_2d_2.slay()


func play_attack():
	owner_root.animation_player_2.play("attack")
