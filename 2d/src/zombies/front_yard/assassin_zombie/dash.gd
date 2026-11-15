extends State

func enter(_msg: Dictionary = {}) -> void :
	owner_root.animation_player_2.play("dash")
	owner_root.gpu_particles_2d.emitting = true
	owner_root.character.speed = -48 * 48

func exit() -> void :
	owner_root.gpu_particles_2d.emitting = false
	owner_root.character.speed = -48

func physics_update(_delta: float) -> void :
	var level = owner_root.level
	if level.top_left.global_position.x < owner_root.global_position.x and \
	owner_root.global_position.x < level.top_right.global_position.x:
		var collumn = owner_root.get_column()
		if collumn == 1:
			var a: Array = owner_root.get_overlapping_areas()
			for i in a:
				if i.is_in_group(owner_root.character.attack_object):
					i.character.current_health -= i.character.max_health
			Audiomanager.play_sfx(owner_root.slay_sfx)
			state_machine.change_state("WALK")
			return
	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio


func _on_ordinary_zombie_area_entered(area: Area2D) -> void :
	if not area.is_in_group(owner_root.character.attack_object):
		return

	if area.is_in_group("defence_plant"):
		area.character.current_health -= area.character.max_health * 0.6
		var dic: Dictionary = {
			"distance": 0, 
			"duration": 0
		}
		state_machine.change_state("PARRY", dic)
		return
	elif area.is_in_group("melee_type_plant"):
		var dic: Dictionary = {
			"distance": 600, 
			"duration": 1.0
		}
		state_machine.change_state("PARRY", dic)
		area.parry()
		return
	else:
		area.character.current_health -= area.character.max_health
		Audiomanager.play_sfx(owner_root.slay_sfx)
		return
