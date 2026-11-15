extends plant_template
@onready var timer: Timer = $Timer

@export var bullet1: PackedScene

func _ready() -> void :
	animated_sprite_2d.play("attack")
	timer.wait_time = character.attack_speed_constant_value
	timer.stop()
	timer.start()
func _process(_delta: float) -> void :
	if character.current_health <= 0:
		dead_()
	pass

func _on_timer_timeout() -> void :
	attack()

func attack():
	var bullet: Area2D = bullet1.instantiate()
	bullet.global_position = marker_2d.global_position
	bullet.attack_object = character.attack_object
	bullet.z_index = character.row * 10 + 3
	Globalmanager.bullets.call_deferred("add_child", bullet)
	dead_()
