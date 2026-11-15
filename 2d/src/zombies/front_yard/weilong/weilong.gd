extends zombie_template

@export var c_4: PackedScene
@export var jet_sfx: AudioStream
@export var weilong_voice: AudioStream
@onready var ray_cast_2d_2: RayCast2D = $RayCast2D2

var c4_num: int = 2
var self_type: String

func ready_effect():
	animation_player_array = [animation_player]

	if self.is_in_group("zombie"): self_type = "zombie"
	else: self_type = "plant"
	state_machine.change_state("JET")


func jet(x1: float, x2: float):
	animation_player.play("jet")
	Audiomanager.play_sfx(jet_sfx)
	var tween = create_tween()
	tween.tween_property(
		self, 
		"global_position:x", 
		global_position.x - randf_range(x1, x2), 
		1.0
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if state_machine.is_in_state("DEAD"): return
	state_machine.change_state("WALK")

func throw_c4(p):
	if c4_num > 0:
		c4_num -= 1
		var c4 = c_4.instantiate()
		c4.attack_object = character.attack_object
		p.add_child(c4)

func play_special_sfx():
	Audiomanager.play_sfx(weilong_voice)
