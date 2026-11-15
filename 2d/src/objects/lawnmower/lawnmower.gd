extends Area2D

var speed: int = 500
var is_run: bool = false
var attack: int = 150000

var attack_type: int = 3

@export var attack_sfx: AudioStream
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _process(delta: float) -> void :
	if is_run: global_position.x += delta * speed
	if global_position.x > 2200:
		queue_free()
func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group("zombie"):
		animation_player.play("attack")
		play_sfx()
		is_run = true
		area.take_damage(attack, attack_type)

func play_sfx():
	Audiomanager.play_sfx(attack_sfx)
	await get_tree().create_timer(2).timeout
	play_sfx()
