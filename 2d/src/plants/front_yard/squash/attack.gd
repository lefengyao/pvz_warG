extends normal_attack
@onready var melee: Area2D = $Melee

var detect_sfx: AudioStream = load("res://shared/assets/audio/plants/front_yard/squash/squash_hmm.wav")
var break_sfx: AudioStream = load("res://shared/assets/audio/plants/front_yard/squash/gargantuar_thump.wav")

var target_x: float
func update(_delta: float) -> void :
	pass

func enter(_msg: Dictionary = {}) -> void :
	play_attack()
func play_attack():
	Audiomanager.play_sfx(detect_sfx)
	owner_root.animation_player_2.play("jump")
	await owner_root.animation_player_2.animation_finished
	target_x = owner_root.enemy.global_position.x
	if owner_root.enemy.global_position.x <= owner_root.global_position.x:
		owner_root.scale.x = -1
	owner_root.global_position.x = target_x
	owner_root.animation_player_2.play("fall")
	Audiomanager.play_sfx(break_sfx)
	await owner_root.animation_player_2.animation_finished
	owner_root.dead_()


func attack():
	var bullet = melee.duplicate()
	bullet.global_position = owner_root.marker_2d.global_position
	bullet.attack_object = owner_root.character.attack_object
	bullet.z_index = owner_root.character.row * 10 + 3
	bullet.monitoring = true
	bullet.visible = true
	Globalmanager.bullets.add_child(bullet)
	attack_effect()
