extends RigidBody2D


@export var min_speed: float = 280.0
@export var max_speed: float = 480.0

@export var loot_position: Vector2
@onready var sprite_2d: TextureRect = $Sprite2D
@export var tex: Texture2D
var rotate_signal: bool = false:
	set(index):
		rotate_signal = index
		if rotate_signal:
			rotate1()
func _ready() -> void :
	var speed = randf_range(min_speed, max_speed)

	var min_angle = - PI / 6
	var max_angle = -5 * PI / 6
	var movement_angle = randf_range(min_angle, max_angle)
	linear_velocity = Vector2(cos(movement_angle), sin(movement_angle)) * speed
	sprite_2d.texture = tex
func rotate1():
	var tween = create_tween()
	tween.tween_property(
		self, 
		"rotation", 
		rotation - deg_to_rad(360), 
		0.5
	)

func _process(_delta: float) -> void :
	if global_position.y > loot_position.y:
		freeze = true

func _on_timer_timeout() -> void :
	queue_free()
	pass
