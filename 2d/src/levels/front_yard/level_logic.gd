extends BoxContainer
@onready var animation_player: AnimationPlayer

@onready var timer: Timer = $Timer
@onready var timer_2: Timer = $Timer2
@onready var plant_logic: Control
@onready var enemy_line: Marker2D
@onready var progress_bar: TextureProgressBar

var big_wave_sfx: AudioStream = load("res://shared/assets/audio/general_music/hugewave.wav")

var zombies: Array
var wait_time: Array
var wave: int = -1:
	set(index):
		wave = index
		wave_change.emit(wave)
		if wave == 0:
			progress_bar.gaming = true
			progress_bar.visible = true
var wave_type: Array
var max_wave: int
var is_spawned: bool = false

var is_spawning_enemies: bool = false
var init_x: float
var cell_height: float
var map_row: int
var init_y: float

var wave_zombie: Array
var total_health: float = 0
var current_health: float = 0

signal ready_
signal wave_change
func _ready() -> void :
	ready_.connect(progress_bar.ready_progress)
	wave_change.connect(progress_bar.wave_changed)
	init_x = enemy_line.global_position.x
	cell_height = plant_logic.cell_height
	map_row = plant_logic.cell_row
	init_y = plant_logic.top_left.global_position.y

	visible = false
	var box = get_children()
	for i in box:
		if i is not Timer:
			if i.is_big_wave:
				wave_type.append(1)
			else:
				wave_type.append(0)
			zombies.append(i.zombies)
			wait_time.append(i.cool_time)
			i.queue_free()
	max_wave = zombies.size() - 1

	timer.wait_time = 18
	ready_.emit(max_wave, wave_type, wait_time)
func spawn_enemies(n: int):

	if wave <= max_wave:
		is_spawning_enemies = true
		if wave_type[wave] == 1 or wave == max_wave:
			animation_player.play("speaker")
			await animation_player.animation_finished
			animation_player.play("zombie_wave")
			Audiomanager.play_sfx(big_wave_sfx)

		timer.stop()
		if wave <= max_wave: timer.wait_time = wait_time[wave]

		timer.start()
		total_health = 0

		wave_zombie = zombies[n]
		for w in wave_zombie:
			var zombie1 = w[0].instantiate()
			zombie1.global_position.x = init_x
			zombie1.global_position.y = init_y + cell_height * (w[1] + 1)
			zombie1.z_index = w[1] * 10 + 2
			zombie1.character.row = w[1]
			total_health += zombie1.character.max_health
			Globalmanager.zombies.add_child(zombie1)
			await get_tree().create_timer(1).timeout
		is_spawning_enemies = false
	else:
		timer.stop()

func _on_timer_2_timeout() -> void :
	timer.paused = true

	if not is_spawning_enemies:
		var nodes = Globalmanager.zombies.get_children()
		var timer_count = 0

		for child in nodes:
			if child is Timer:
				timer_count += 1
		if nodes.size() == 1 and timer_count <= 1:
			if wave > max_wave:
				plant_logic.last_wave = true
				timer_2.stop()
		else:

			current_health = 0
			for i in nodes:
				if i is not Timer:
					if i.character.current_health >= 0:
						current_health += i.character.current_health
			if current_health < total_health * 0.33:
				wave += 1


				if wave <= max_wave:
					spawn_enemies(wave)
	timer.paused = false
	pass


func _on_timer_timeout() -> void :
	wave += 1
	spawn_enemies(wave)

func start_game():
	timer.start()
	timer_2.start()
