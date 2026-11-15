extends plant_template

@export var sun: PackedScene
@onready var timer: Timer = $Timer


@export var spawn_radius: float = 15.0
@export var spawn_potition: Marker2D

var is_first_time: bool = true

func _ready() -> void :
	animated_sprite_2d.play("idle")
	timer.start(6)
	pass

func spawn_sun():
	animated_sprite_2d.play("attack")
	await get_tree().create_timer(0.8).timeout

	var sun1 = sun.instantiate()
	var random_angle = randf() * PI * -1
	var offset_x = cos(random_angle) * randf() * spawn_radius
	var offset_y = sin(random_angle) * randf() * spawn_radius
	var spawn_position = spawn_potition.global_position + Vector2(offset_x, offset_y)
	sun1.global_position = spawn_position
	Globalmanager.suns.add_child(sun1)
	animated_sprite_2d.play("idle")
func _process(_delta: float) -> void :
	if character.current_health <= 0:
		dead_()

func _on_timer_timeout() -> void :
	if is_first_time:
		timer.wait_time = 23
		is_first_time = false
	spawn_sun()
