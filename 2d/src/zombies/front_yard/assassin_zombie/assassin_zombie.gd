extends zombie_template
@onready var animation_player_2: AnimationPlayer = $AnimationPlayer
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

@export var slay_sfx: AudioStream

func ready_effect():
	attack_type = 1
	animation_player_array = [animation_player, animation_player_2]


func dead():
	is_loot = true
	collision_shape_2d.disabled = true
	animation_player_2.play("dead")
	death_walk()
	Audiomanager.play_sfx(fall_sfx)
	await animation_player_2.animation_finished
	queue_free()

func death_walk():
	var tween = create_tween()
	tween.tween_property(
		self, 
		"global_position:x", 
		global_position.x + 150, 
		1.5
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
