extends State


func physics_update(_delta: float) -> void :
	var level = owner_root.level
	if level.top_left.global_position.x < owner_root.global_position.x and \
	owner_root.global_position.x < level.top_right.global_position.x:
		var collumn = owner_root.get_column()
		if collumn == level.cell_column - 2:
			state_machine.change_state("DASH")
			Audiomanager.play_sfx(owner_root.slay_sfx)
			return
	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio
	owner_root.animation_player.play("walk")


	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		state_machine.change_state("ATTACK")
