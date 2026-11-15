extends State








var original_speed: float

func enter(_msg: Dictionary = {}) -> void :

	owner_root.sprite_2d.visible = false


	original_speed = owner_root.character.speed
	owner_root.character.speed = original_speed * owner_root.run_speed_multiplier


func exit() -> void :

	owner_root.character.speed = original_speed


func physics_update(_delta: float) -> void :

	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio


	owner_root.animation_player.play("run")


	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)
	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:


		var pole_instance: Area2D = owner_root.pole.instantiate()

		pole_instance.global_position = owner_root.attack_position.global_position

		pole_instance.attack_object = owner_root.character.attack_object

		if not owner_root.die.is_connected(pole_instance.dead):
			owner_root.die.connect(pole_instance.dead)


		owner_root.level.add_child(pole_instance)


		owner_root.thrown_pole = pole_instance


		state_machine.change_state("DASH")
