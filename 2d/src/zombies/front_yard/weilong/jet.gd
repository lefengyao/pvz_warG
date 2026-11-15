extends State

func enter(_msg: Dictionary = {}) -> void :
	owner_root.jet(400, 500)

func update(_delta: float) -> void :

	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		owner_root.throw_c4(_body)
