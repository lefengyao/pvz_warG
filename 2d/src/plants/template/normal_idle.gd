extends State
class_name normal_idle

func idle_code():
	pass


func update(_delta: float) -> void :
	idle_code()

	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		state_machine.change_state("ATTACK")
	pass
