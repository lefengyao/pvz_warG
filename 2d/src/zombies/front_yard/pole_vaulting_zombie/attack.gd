extends State
@onready var melee: Area2D = $Melee

func physics_update(_delta: float) -> void :

	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]
	if not is_hit:
		state_machine.change_state("WALK")

	owner_root.animation_player.play("attack")

func attack():
	var bullet = melee.duplicate()
	bullet.global_position = owner_root.attack_position.global_position
	bullet.attack_object = owner_root.character.attack_object
	bullet.z_index = owner_root.character.row * 10 + 3
	bullet.monitoring = true
	bullet.visible = true
	Globalmanager.bullets.add_child(bullet)
