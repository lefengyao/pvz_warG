extends normal_attack
@export var laser_sfx: AudioStream

func attack_effect():
	Audiomanager.play_sfx(laser_sfx)
