extends Area2D
@onready var timer: Timer = $Timer

@export var attack: int = 20
@export var bite_sfx: AudioStream
var attack_object: String
var is_attacked: bool = false


@export var attack_type: int = 1

@export var is_aoe: bool = false

func _on_area_entered(area: Area2D) -> void :
	if area.is_in_group(attack_object) and not is_attacked:
		timer.start()
		if is_aoe: pass
		else: is_attacked = true
		area.take_damage(attack, attack_type)
		Audiomanager.play_sfx(bite_sfx)
		await get_tree().create_timer(0.1).timeout
		queue_free()


func _on_timer_timeout() -> void :
	queue_free()
	pass
