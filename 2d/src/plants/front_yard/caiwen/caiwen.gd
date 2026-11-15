extends plant_template

@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2
@onready var melee_挂场景上调整使用_: Area2D = $"AnimatedSprite2D/Marker2D/Melee（挂场景上调整使用）"
@onready var gpu_particles_2d_2: GPUParticles2D = $GPUParticles2D2
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D


func parry():
	gpu_particles_2d.slay()
