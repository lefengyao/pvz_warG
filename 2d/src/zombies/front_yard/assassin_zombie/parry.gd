extends State

signal pull
@export var parry_sfx: AudioStream
func pull_back(distance: int = 200, duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(
		owner_root, 
		"global_position:x", 
		owner_root.global_position.x + distance, 
		duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	pull.emit()

func enter(_msg: Dictionary = {}) -> void :
	var distance: int = _msg.get("distance", 0)
	var duration: int = _msg.get("duration", 0)
	Audiomanager.play_sfx(parry_sfx)
	owner_root.animation_player_2.play("parry")
	pull_back(distance, duration)
	await pull
	state_machine.change_state("WALK")
