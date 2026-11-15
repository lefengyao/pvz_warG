extends normal_attack


func play_attack():
	owner_root.animation_player_2.play("attack")

func double_attack():
	var bullet = bullet2.instantiate()
	bullet.global_position = owner_root.marker_2d.global_position
	bullet.attack_object = owner_root.character.attack_object
	bullet.z_index = owner_root.character.row * 10 + 3
	Globalmanager.bullets.add_child(bullet)
	await get_tree().create_timer(0.2).timeout
	var bullet1 = bullet2.instantiate()
	bullet1.global_position = owner_root.marker_2d.global_position
	bullet1.attack_object = owner_root.character.attack_object
	bullet1.z_index = owner_root.character.row * 10 + 3
	Globalmanager.add_child(bullet1)

func attack():
	var a: float = randf_range(0, 1.0)
	double_attack()
	if a <= 0.4:
		await get_tree().create_timer(0.3).timeout
		double_attack()
	attack_effect()
