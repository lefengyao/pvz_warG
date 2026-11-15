extends Node

enum Bus{
	MASTER, 
	MUSIC, 
	SFX, 
}

const MUSIC_BUS = "music"
const SFX_BUS = "sfx"




var music_audio_player_count: int = 2

var current_music_player_index: int = 0

var music_players: Array[AudioStreamPlayer]

var music_fade_duration: float = 1.0


var sfx_audio_player_count: int = 12
var sfx_players: Array[AudioStreamPlayer]

func _ready() -> void :
	init_music_audio_manager()
	init_sfx_audio_manager()
	pass


func init_music_audio_manager():
	for i in music_audio_player_count:
		var audio_player: = AudioStreamPlayer.new()
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		audio_player.bus = MUSIC_BUS
		audio_player.finished.connect(_on_music_finished)
		add_child(audio_player)
		music_players.append(audio_player)
	pass


func play_music(_audio: AudioStream):
	var current_audio_player: = music_players[current_music_player_index]
	if current_audio_player.stream == _audio:
		return
	var empty_audio_player_index = 0 if current_music_player_index == 1 else 1
	var empty_audio_player: = music_players[empty_audio_player_index]

	empty_audio_player.stream = _audio
	play_and_fade_in(empty_audio_player)

	fade_out_and_stop(current_audio_player)
	current_music_player_index = empty_audio_player_index


func play_same_music():
	var current_audio_player: = music_players[current_music_player_index]
	play_and_fade_in(current_audio_player)

func play_and_fade_in(_audio_player: AudioStreamPlayer):
	_audio_player.play()
	var tween: Tween = create_tween()
	tween.tween_property(_audio_player, "volume_db", 0, music_fade_duration)


func fade_out_and_stop(_audio_player: AudioStreamPlayer):
	var tween: Tween = create_tween()
	tween.tween_property(_audio_player, "volume_db", -40, music_fade_duration)
	await tween.finished
	_audio_player.stop()
	_audio_player.stream = null


func fade_out_and_stop_current(_audio_player = music_players[current_music_player_index]):
	var tween: Tween = create_tween()
	tween.tween_property(_audio_player, "volume_db", -40, music_fade_duration)
	await tween.finished
	_audio_player.stop()
	_audio_player.stream = null

func _on_music_finished():
	play_same_music()
	pass

func init_sfx_audio_manager():
	for i in sfx_audio_player_count:
		var audio_player: = AudioStreamPlayer.new()
		audio_player.bus = SFX_BUS
		add_child(audio_player)
		sfx_players.append(audio_player)

	pass

func play_sfx(_audio: AudioStream):
	var same_audio_playing_count: int = 0
	for i in sfx_audio_player_count:
		var sfx_audio_player: = sfx_players[i]
		if sfx_audio_player.playing and sfx_audio_player.stream == _audio:
			same_audio_playing_count += 1
			if same_audio_playing_count > 3:
				return
		if not sfx_audio_player.playing:
			sfx_audio_player.stream = _audio
			sfx_audio_player.play()
			return
	var target_player = create_temp_audio_player()
	target_player.stream = _audio
	target_player.play()
	await target_player.finished
	target_player.queue_free()


func create_temp_audio_player() -> AudioStreamPlayer:

	var temp_player = AudioStreamPlayer.new()

	add_child(temp_player)
	return temp_player


func set_volume(bus_index: Bus, v: float):
	var db = linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
