extends TextureProgressBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var marker_2d: Marker2D = $Marker2D

@export var wave_node: PackedScene
var current_wave: int = 0:
	set(index):
		current_wave = index
		rest_of_time = 0
		if current_wave > max_wave:
			current_wave = max_wave
		if wave_type[current_wave] == 1:
			animation_player.play("red_flash")
		else:
			animation_player.play("green_flash")
		for i in wait_time.slice(current_wave):
			rest_of_time += i

		if current_time + rest_of_time <= time_sum:
			current_time = time_sum - rest_of_time
		wave_change.emit(current_wave)
var max_wave: int
var wave_type: Array
var wait_time: Array
var time_sum: float
var current_time: float = 0
var rest_of_time: float

var gaming: bool = false

signal wave_change
func _ready() -> void :
	visible = false

func ready_progress(num: int, num2: Array, num3: Array):
	max_wave = num
	wave_type = num2
	wait_time = num3.slice(1)
	for i in wait_time:
		time_sum += i

	rest_of_time = time_sum


	var init_x = marker_2d.position.x
	var y = marker_2d.position.y

	var value1: float = 0

	for i in range(wait_time.size()):
		value1 += wait_time[i]
		if wave_type[i] == 1 or (wave_type[-1] == 1 and i == wait_time.size() - 1):
			var textu = wave_node.instantiate()
			textu.position.y = y
			textu.position.x = init_x - value1 / time_sum * init_x * randf_range(0.99, 1.0)
			wave_change.connect(textu.detect)
			textu.trigger_wave = i
			add_child(textu)

func _process(delta: float) -> void :
	if gaming:
		if current_time <= time_sum:
			current_time += delta
			value = current_time / time_sum * 100

func wave_changed(wave):
	current_wave = wave
