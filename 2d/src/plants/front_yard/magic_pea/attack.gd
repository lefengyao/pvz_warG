extends normal_attack

@export var attack_sfx: AudioStream

func attack_effect():
	Audiomanager.play_sfx(attack_sfx)
