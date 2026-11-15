extends State









var original_speed: float


var is_vaulting: bool = false


func enter(_msg: Dictionary = {}) -> void :
	Audiomanager.play_sfx(owner_root.slide_sfx)
	owner_root.ray_cast_2d.target_position.x = -50

	is_vaulting = false


	original_speed = owner_root.character.speed
	owner_root.character.speed = original_speed * 5.0


	owner_root.animation_player.play("dash")


func exit() -> void :

	if not is_vaulting:
		owner_root.character.speed = original_speed


func physics_update(_delta: float) -> void :

	if is_vaulting:
		return


	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio


	var hit: Dictionary = owner_root.check_dash_ray(owner_root.ray_cast_2d)
	match hit.type:
		"pole":

			is_vaulting = true
			_do_pole_vault()






func _do_pole_vault() -> void :

	if owner_root.thrown_pole != null:
		owner_root.thrown_pole.queue_free()
		owner_root.thrown_pole = null

	Audiomanager.play_sfx(owner_root.pole_sfx)


	owner_root.animation_player.play("pole")


	var tween = owner_root.create_tween()
	tween.tween_property(
		owner_root, 
		"global_position:x", 
		owner_root.global_position.x - 80, 
		1.0
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)


	await tween.finished




	owner_root.run_completed = true


	owner_root.character.speed = original_speed * owner_root.walk_speed_multiplier


	if state_machine.is_in_state("DASH"):
		state_machine.change_state("WALK")
