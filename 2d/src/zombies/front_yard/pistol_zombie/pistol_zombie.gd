extends zombie_template

var first_special_done: bool = false
@onready var gun_position: Marker2D = $gun_position
@onready var ray_cast_2d_2: RayCast2D = $RayCast2D / RayCast2D2
@onready var timer: Timer = $Timer
@onready var gun_bullet: Area2D = $GunBullet

@export var gun_sfx: AudioStream

func play_gun_sfx():
	Audiomanager.play_sfx(gun_sfx)


func set_attack():
	var bullet: Area2D = gun_bullet.duplicate()
	bullet.global_position = gun_position.global_position
	bullet.attack_object = character.attack_object
	bullet.z_index = character.row * 10 + 3
	bullet.monitoring = true
	bullet.visible = true
	bullet.is_run = true
	Globalmanager.bullets.add_child(bullet)
