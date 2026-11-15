extends Node

var musics: Array
@export var sfx1: AudioStream = load("res://shared/assets/audio/general_music_zombie/groan/groan.wav")
@export var sfx2: AudioStream = load("res://shared/assets/audio/general_music_zombie/groan/groan2.wav")
@export var sfx3: AudioStream = load("res://shared/assets/audio/general_music_zombie/groan/groan3.wav")
@export var sfx4: AudioStream = load("res://shared/assets/audio/general_music_zombie/groan/groan4.wav")
@export var sfx5: AudioStream = load("res://shared/assets/audio/general_music_zombie/groan/groan5.wav")
@export var sfx6: AudioStream = load("res://shared/assets/audio/general_music_zombie/groan/groan6.wav")
@onready var timer: Timer = $Timer

func _ready() -> void :
	musics = [sfx1, sfx2, sfx3, sfx4, sfx5, sfx6]
func music_play():
	var music = musics.pick_random()
	Audiomanager.play_sfx(music)

func _on_timer_timeout() -> void :
	var all_children = get_children()
	var timer_count = 0


	for child in all_children:
		if child is Timer:
			timer_count += 1


		if all_children.size() >= 2 and timer_count <= 1:
			music_play()

func start_game():
	timer.start()
