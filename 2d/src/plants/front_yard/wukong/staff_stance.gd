extends Node2D

@export var xuli3: AudioStream
@export var xuli: AudioStream


signal pigun_fired(gun_type: String, charged_phases: int)
signal chuogun_fired(gun_type: String, charged_phases: int)
signal gun


const PHASE_COSTS: Array[float] = [40.0, 60.0, 80.0]
const REGEN_RATE: float = 8.0


var current_phase: int = 0
var phase_energy: float = 0.0
var current_gun: String = "pigun"
var is_auto_charging: bool = true


@onready var pigun_node: TextureProgressBar = $pigun
@onready var pigun2_node: TextureProgressBar = $pigun2


@onready var phase_sprites: Array[Sprite2D] = [$Sprite2D, $Sprite2D2, $Sprite2D3]


@onready var pigun_button: TextureButton = $pigun / Sprite2D
@onready var chuogun_button: TextureButton = $pigun2 / Sprite2D4

func _ready() -> void :

	switch_state("pigun")
	_update_ui()


	if pigun_button: pigun_button.pressed.connect(_on_pigun_button_pressed)
	if chuogun_button: chuogun_button.pressed.connect(_on_chuogun_button_pressed)

func _process(delta: float) -> void :
	if is_auto_charging and current_phase < 3:
		add_energy(REGEN_RATE * delta)




func add_energy(amount: float) -> void :
	if current_phase >= 3:
		return

	phase_energy += amount
	_check_phase_progression()
	_update_ui()


func _check_phase_progression() -> void :

	while current_phase < 3 and phase_energy >= PHASE_COSTS[current_phase]:
		phase_energy -= PHASE_COSTS[current_phase]
		current_phase += 1


		if current_phase == 3:
			Audiomanager.play_sfx(xuli3)
		else:
			Audiomanager.play_sfx(xuli)



		if current_phase >= 3:
			phase_energy = 0.0
			break


func switch_state(state_name: String) -> void :
	current_gun = state_name
	pigun_node.visible = (state_name == "pigun")
	pigun2_node.visible = (state_name == "chuogun")


func toggle_gun() -> void :
	var next_state: String = "chuogun" if current_gun == "pigun" else "pigun"
	switch_state(next_state)


func _update_ui() -> void :
	var display_percentage: float = 0.0

	if current_phase < 3:

		display_percentage = (phase_energy / PHASE_COSTS[current_phase]) * 100.0
	else:

		display_percentage = 100.0


	pigun_node.value = display_percentage
	pigun2_node.value = display_percentage


	for i: int in range(phase_sprites.size()):
		phase_sprites[i].visible = (current_phase > i)



func _on_pigun_button_pressed() -> void :
	pigun_fired.emit(current_gun, current_phase)
	gun.emit(1)
	print("Pigun Fired! Phase: ", current_phase)

func _on_chuogun_button_pressed() -> void :
	chuogun_fired.emit(current_gun, current_phase)
	gun.emit(0)
	print("Chuogun Fired! Phase: ", current_phase)
