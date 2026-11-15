extends GPUParticles2D

@export var slay_sfx: AudioStream
func slay():
	emitting = true
	Audiomanager.play_sfx(slay_sfx)
	await get_tree().create_timer(0.8).timeout
	emitting = false
