extends Node

@export var bg_1: AudioStream
@export var chose_your_plant: AudioStream

func play_chose_plant():
	Audiomanager.play_music(chose_your_plant)

func play_bg_1():
	Audiomanager.play_music(bg_1)

func start_game():
	play_bg_1()
