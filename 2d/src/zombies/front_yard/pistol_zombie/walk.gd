extends State

var walk: bool = false
var gun_shot: bool = false
var first_shoot: bool = false
func enter(_msg: Dictionary = {}) -> void :
	walk = true

func exit() -> void :
	walk = false
func physics_update(_delta: float) -> void :
	if gun_shot: return

	var level = owner_root.level
	if not first_shoot:
		if level.top_left.global_position.x < owner_root.global_position.x and \
		owner_root.global_position.x < level.top_right.global_position.x:
			var collumn = owner_root.get_column()
			if collumn == level.cell_column - 2:
				gun_shot = true
				for i in range(2):
					owner_root.animation_player.play("gunshot")
					await owner_root.animation_player.animation_finished
				gun_shot = false
				first_shoot = true
	owner_root.global_position.x += _delta * owner_root.character.speed * owner_root.character.speed_ratio
	owner_root.animation_player.play("walk")


	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		state_machine.change_state("ATTACK")

func _on_timer_timeout() -> void :
	if walk:

		var result = owner_root.check_attack_ray(owner_root.ray_cast_2d_2)

		var is_hit: bool = result[0]
		var _body: Node2D = result[1]

		if is_hit:
			gun_shot = true
			owner_root.animation_player.play("gunshot")
			await owner_root.animation_player.animation_finished
			gun_shot = false
	pass
