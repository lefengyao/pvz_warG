extends plant_template

@onready var shadow: Sprite2D = $shadow
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var timer: Timer = $Timer

@export var bullet1: PackedScene
var idle2: bool = false
func _ready() -> void :
	timer.wait_time = character.attack_speed_constant_value
	timer.start()
	shadow.visible = false
	animated_sprite_2d.play("idle1")

func _process(_delta: float) -> void :
	if character.current_health <= 0:
		dead_()

func attack():
	var bullet: Area2D = bullet1.instantiate()
	bullet.global_position = marker_2d.global_position
	bullet.attack_object = character.attack_object
	bullet.z_index = character.row * 10 + 3
	Globalmanager.bullets.call_deferred("add_child", bullet)
	dead_()

func _on_timer_timeout() -> void :
	collision_shape_2d.visible = false
	animated_sprite_2d.play("ermerge")
	await get_tree().create_timer(0.5).timeout

	shadow.visible = true
	idle2 = true
	collision_shape_2d.visible = true
	animated_sprite_2d.play("idle2")

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(character.attack_object) and idle2:
		attack()
