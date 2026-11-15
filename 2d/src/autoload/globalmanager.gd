extends Node

var click_successful_sfx: AudioStream = load("res://shared/assets/audio/general_music/tap.wav")
var click_failed_sfx1: AudioStream = load("res://shared/assets/audio/general_music/buttonclick.wav")
var click_failed_sfx2: AudioStream = load("res://shared/assets/audio/general_music/buzzer.wav")


var plants: Node
var zombies: Node
var bullets: Node
var suns: Node
var lawnmowers: Node
var loots: Node

var right_boder_x: float
func play_click_successful_sfx():
	Audiomanager.play_sfx(click_successful_sfx)


func play_click_failed_sfx(n: int = 0):
	if n == 0:
		n = randi_range(1, 2)

	if n == 1:
		Audiomanager.play_sfx(click_failed_sfx1)
	elif n == 2:
		Audiomanager.play_sfx(click_failed_sfx2)
