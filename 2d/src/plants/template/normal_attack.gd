extends State
class_name normal_attack
@export var bullet2: PackedScene

func attack():
	var bullet1 = bullet2.instantiate()
	bullet1.global_position = owner_root.marker_2d.global_position
	bullet1.attack_object = owner_root.character.attack_object
	bullet1.z_index = owner_root.character.row * 10 + 3
	Globalmanager.bullets.add_child(bullet1)
	attack_effect()


func attack_effect():
	pass


func play_attack():
	owner_root.animation_player.play("attack")

func update(_delta: float) -> void :

	var result = owner_root.check_attack_ray(owner_root.ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]
	raycast_body_effect1(_body)
	if not is_hit:
		state_machine.change_state("IDLE")

	play_attack()

func raycast_body_effect1(_body):
	pass
