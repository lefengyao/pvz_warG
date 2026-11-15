extends State

func physics_update(_delta: float) -> void :
	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio
	owner_root.animation_player.play("walk")


	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		state_machine.change_state("ATTACK")
