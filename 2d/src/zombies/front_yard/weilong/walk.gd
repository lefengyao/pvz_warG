extends State

func physics_update(_delta: float) -> void :
	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio
	owner_root.animation_player.play("walk")
	throw_c4()

	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		state_machine.change_state("ATTACK")

func throw_c4():
	if owner_root.c4_num > 0:

		var result = owner_root.check_attack_ray(owner_root.ray_cast_2d_2, owner_root.self_type)

		var is_hit: bool = result[0]
		var _body: Node2D = result[1]

		if is_hit:
			owner_root.throw_c4(_body)
			_body.play_special_sfx()
			_body.state_machine.change_state("JET")
