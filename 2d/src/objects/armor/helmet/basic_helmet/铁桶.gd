extends Node2D

@export var sfx1: AudioStream
@export var sfx2: AudioStream
var sfx_group: Array
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var loot: PackedScene = load("res://2d/scenes/objects/loot/auto_despawn_loot/loot_template.tscn")
var l: RigidBody2D
@export var loot_tex: Texture2D
@export var max_health: int = 300
@export var current_health: int = 300:
	set(index):
		current_health = index
		if current_health > max_health * 0.66:
			animated_sprite_2d.play("初始状态")
		elif current_health > max_health * 0.33:
			animated_sprite_2d.play("轻度破损")
		elif current_health > 0:
			animated_sprite_2d.play("重度破损")
		else:
			visible = false
			l.global_position = global_position
			l.loot_position = loot_position
			Globalmanager.loots.call_deferred("add_child", l)
			queue_free()


@export var loot_position: Vector2
func _ready() -> void :
	l = loot.instantiate()
	sfx_group = [sfx1, sfx2]
	l.tex = loot_tex

func play_sfx():
	var a: int = randi_range(0, 1)
	Audiomanager.play_sfx(sfx_group[a])

func take_damage(_attack, _ammo_type):
	if _ammo_type == 1 or _ammo_type == 3:
		play_sfx()
		current_health -= _attack
		if current_health < 0:
			return - current_health
		else:
			return 0
	elif _ammo_type == 2:
		return _attack
	else:
		return 0
