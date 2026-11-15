extends Sprite2D

@export var c4_sfx: AudioStream
@export var bullet: PackedScene
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var attack_object: String
func _ready() -> void :
	global_position += Vector2(randf_range(5, 15), -50)
	Audiomanager.play_sfx(c4_sfx)

func dead():
	var b: Area2D = bullet.instantiate()
	b.global_position = global_position
	b.attack_object = attack_object
	Globalmanager.bullets.add_child(b)
	queue_free()
