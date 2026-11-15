extends plant_template

@onready var melee_挂场景上调整使用_: Area2D = $"AnimatedSprite2D/Marker2D/Melee（挂场景上调整使用）"
@onready var animation_player: AnimationPlayer = $"AnimationPlayer"
func attack():
	var bullet = melee_挂场景上调整使用_.duplicate()
	bullet.global_position = marker_2d.global_position
	bullet.attack_object = character.attack_object
	bullet.z_index = character.row * 10 + 3
	bullet.monitoring = true
	bullet.visible = true
	Globalmanager.bullets.add_child(bullet)

func play_attack():
	animation_player.play("attack")

func idle_code():
	animation_player.play("idle")

func _process(_delta: float) -> void :

	var result = check_attack_ray(ray_cast_2d)

	var is_hit: bool = result[0]
	var _body: Node2D = result[1]

	if is_hit:
		play_attack()
	else:
		idle_code()
