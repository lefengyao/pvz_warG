extends Area2D
class_name zombie_template
@export var character: general_character
@export var fall_sfx: AudioStream
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var attack_position: Marker2D = $attack_position

@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var skeleton_2d: Skeleton2D = $Skeleton2D
@onready var state_machine: StateMachine = $StateMachine

var level: Control
var animation_player_array: Array


var is_loot: bool = false


@export var loot_head: PackedScene
@export var loot_head_position: Sprite2D
@export var loot_node: Marker2D
@export var loot_tex: Texture2D
var loot_position: Vector2

var attack_type: int = 2

func _ready() -> void :
	level = get_tree().root.get_node_or_null("level")
	character.speed *= randf_range(1, 1.2)
	loot_position = loot_node.global_position
	be_attack.connect(be_attack_effect)
	state_machine.change_state("WALK")
	ready_armor()
	ready_effect()
func get_column():
	return level.get_pos(global_position - Vector2(0, level.cell_height))[2]

func ready_effect():
	animation_player_array = [animation_player]

func _physics_process(_delta: float) -> void :

	if character.current_health <= 0 and not is_loot:
		state_machine.change_state("DEAD")
		dead()


func dead():
	is_loot = true
	collision_shape_2d.disabled = true
	animation_player.play("dead")
	Audiomanager.play_sfx(fall_sfx)
	set_loot()
	await animation_player.animation_finished
	dead_effect()
	queue_free()

func dead_effect():
	pass

func set_loot():
	var loot_head1: PackedScene
	var loot_head2: RigidBody2D
	if loot_tex:
		loot_head1 = load("res://2d/scenes/objects/loot/auto_despawn_loot/loot_template.tscn")
		loot_head2 = loot_head1.instantiate()
		loot_head2.tex = loot_tex
	else:
		loot_head2 = loot_head.instantiate()
	loot_head2.global_position = loot_head_position.global_position
	loot_head2.loot_position = loot_position
	Globalmanager.loots.add_child(loot_head2)


@export var armor1: armor
@export var armor2: armor
var a1: Node2D
var a2: Node2D
@export var armor_target1: Marker2D
@export var armor_target2: Marker2D

func ready_armor() -> void :
	if armor1 != null:
		a1 = armor1.armor_scence.instantiate()
		a1.loot_position = loot_position
		armor_target1.add_child(a1)

signal be_attack

func take_damage(_attack, _ammo_type):
	if a1 != null:
		_attack = a1.take_damage(_attack, _ammo_type)
	elif a2 != null:
		_attack = a2.take_damage(_attack, _ammo_type)
	take_damage_effect()
	character.current_health -= _attack * character.damage_ratio
	be_attack.emit()

func be_attack_effect():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	var old_modulate = skeleton_2d.modulate
	tween.tween_property(skeleton_2d, "modulate", Color(255, 255, 255, 0.3), 0.01)
	tween.tween_property(skeleton_2d, "modulate", old_modulate, 0.01)

func take_damage_effect():
	pass

var slow_down_count: int = 0

func set_slow_down(time: float, set_slow_down_ratio: float):
	slow_down_count += 1
	character.speed_ratio = 1.0 - set_slow_down_ratio
	for i in animation_player_array:
		i.speed_scale = 1.0 - set_slow_down_ratio
	skeleton_2d.modulate = Color(0, 0, 128, 0.7)
	await get_tree().create_timer(time).timeout
	slow_down_count -= 1
	if slow_down_count == 0:
		character.speed_ratio = 1.0
		for i in animation_player_array:
			i.speed_scale = 1.0
		skeleton_2d.modulate = Color(1, 1, 1, 1)




func check_attack_ray(ray: RayCast2D, object: String = character.attack_object) -> Array:
	if ray.is_colliding():
		var body = ray.get_collider()
		if body != null:

			if body.global_position.x < Globalmanager.right_boder_x and body.is_in_group(object):
				return [true, body]
	return [false, null]
