extends Control

@onready var plant_cards: Control = $UI / card_selection / HBoxContainer
@onready var chan = $UI / card_selection / shovel / TextureRect
@onready var top_left: Marker2D = $plant_logic / positioning_device / TopLeft
@onready var bottom_left: Marker2D = $plant_logic / positioning_device / BottomLeft
@onready var top_right: Marker2D = $plant_logic / positioning_device / TopRight
@onready var lawnmowers_line: Marker2D = $plant_logic / positioning_device / lawnmowers_line
@onready var enemy_line: Marker2D = $plant_logic / positioning_device / enemy_line
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var progress_bar: TextureProgressBar = $UI / TextureProgressBar
@onready var path_follow_2d: PathFollow2D = $Path2D / PathFollow2D
@onready var music: Node = $manager / music
@onready var general_sun: Node = $manager / general_sun
@onready var card_selection: Control = $UI / card_selection
@onready var ui_all_cards: Control = $UI / ui_all_cards
@onready var right_border: Marker2D = $plant_logic / positioning_device / right_border
@onready var returnmenu: TextureRect = $UI / returnmenu
@onready var win: Label = $UI / returnmenu / win
@onready var lose: Label = $UI / returnmenu / lose
@onready var manager: Node = $manager


func _ready() -> void :
	var plants = create_child_node("plants")
	var zombies = create_child_node("zombies")

	var timer = Timer.new()
	timer.wait_time = 6.0
	timer.one_shot = false

	zombies.add_child(timer)

	zombies.script = load("res://2d/src/special/zombie_groan.gd")

	var suns = create_child_node("suns")
	suns.script = load("res://2d/src/special/suns.gd")
	var bullets = create_child_node("bullets")
	var lawnmowers = create_child_node("lawnmowers")
	var loots = create_child_node("loots")

	Globalmanager.plants = plants
	Globalmanager.zombies = zombies
	Globalmanager.suns = suns
	Globalmanager.bullets = bullets
	Globalmanager.lawnmowers = lawnmowers
	Globalmanager.loots = loots

	Globalmanager.right_boder_x = right_border.global_position.x
	ready_plant_logic()
	ready_level_logic()
	prepare_game()
	set_setting()

func create_child_node(node_name: String) -> Node:

	var new_node = Node.new()

	new_node.name = node_name

	manager.add_child(new_node)

	return new_node

var plant_sfx: AudioStream = load("res://shared/assets/audio/general_music/plant.wav")
@export var cell_row: int
@export var cell_column: int
@export var lawnmover: PackedScene


var relative_position

var cell_height: float
var cell_width: float
var lawn_height: float
var lawn_width: float

var two_d_array = []

var ready_plant: bool = false
var last_wave: bool = false:
	set(index):
		last_wave = index
		if last_wave:
			returnmenu.visible = true
			win.visible = true
var chosen_plant

func get_cards():
	var all_plant_cards = plant_cards.get_children()
	for card1 in all_plant_cards:
		card1.is_clicked.connect(get_card)
	chan.chan.connect(chan_plant)
func get_card(card1):
	chosen_plant = card1
	ready_plant = true
	pass

func del_card(row, column):

	two_d_array[row][column]["plant"] = null
	pass
func ready_plant_logic() -> void :
	lawn_height = bottom_left.global_position.y - top_left.global_position.y
	lawn_width = top_right.global_position.x - top_left.global_position.x
	cell_height = lawn_height / cell_row
	cell_width = lawn_width / cell_column
	for i in range(cell_row):
		two_d_array.append([])
		for j in range(cell_column):
			two_d_array[i].append({"block": 0, "shell": null, "plant": null})

func get_pos(_position: Vector2 = get_global_mouse_position()):
	relative_position = _position - top_left.global_position
	var row: int = floor(relative_position.y / cell_height)
	var column: int = floor(relative_position.x / cell_width)
	return [two_d_array[row][column], row, column]

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ready_plant:
			var pos = get_pos()
			var row: int = pos[1]
			var column: int = pos[2]
			var plant1 = chosen_plant.plant_card.instantiate()
			if two_d_array[row][column]["plant"] == null and (0 <= row and row <= cell_row) and (0 <= column and column <= cell_column):
				plant1.global_position.x = column * cell_width + top_left.global_position.x + cell_width * 0.5
				plant1.global_position.y = (row + 1) * cell_height + top_left.global_position.y - cell_height * 0.2
				plant1.character.row = row
				plant1.character.column = column
				plant1.z_index = row * 10 + 1
				plant1.dead.connect(del_card)
				two_d_array[row][column]["plant"] = plant1.character.character_name

				Globalmanager.plants.add_child(plant1)
				Audiomanager.play_sfx(plant_sfx)
				Globalmanager.suns.sun_num -= chosen_plant.sun_num
				ready_plant = false
				chosen_plant.already_plant()

func set_lawnmover():
	for i in range(cell_row):
		var lawnmover1 = lawnmover.instantiate()
		lawnmover1.global_position.x = lawnmowers_line.global_position.x
		lawnmover1.global_position.y = top_left.global_position.y + cell_height * (i + 1)
		lawnmover1.z_index = i * 10 + 3
		Globalmanager.lawnmowers.add_child(lawnmover1)

func chan_plant():
	relative_position = get_global_mouse_position() - top_left.global_position
	var row: int = floor(relative_position.y / cell_height)
	var column: int = floor(relative_position.x / cell_width)
	if (0 <= row and row <= cell_row) and (0 <= column and column <= cell_column):


		for i in Globalmanager.plants.get_children():
			if i.character.row == row and i.character.column == column:

				Audiomanager.play_sfx(plant_sfx)
				del_card(row, column)
				i.emit_dead()
				i.queue_free()

func start_game():
	get_cards()

@export var level_logic: PackedScene
var level_logic1: Control
func ready_level_logic():
	level_logic1 = level_logic.instantiate()
	level_logic1.plant_logic = self
	level_logic1.animation_player = animation_player
	level_logic1.enemy_line = enemy_line
	level_logic1.progress_bar = progress_bar
	add_child(level_logic1)
	level_logic1.visible = false
	pass

func prepare_game():
	ui_all_cards.visible = false


	GameProgressBus.game_started.connect(card_selection.start_game)
	GameProgressBus.game_started.connect(general_sun.start_game)
	GameProgressBus.game_started.connect(music.start_game)
	GameProgressBus.game_started.connect(start_game)
	GameProgressBus.game_started.connect(level_logic1.start_game)

	music.play_chose_plant()
	path_follow_2d.forward_completed.connect(set_selecting_cards_true)
	path_follow_2d.back_completed.connect(set_after_card_selection)
	ui_all_cards.card_acquired.connect(card_selection.get_cards)
	ui_all_cards.card_acquired.connect(set_selecting_cards_false)
	await get_tree().create_timer(1).timeout
	path_follow_2d.move_forward()



func set_selecting_cards_true():
	ui_all_cards.visible = true

func set_selecting_cards_false(_acquired_card = null):
	Audiomanager.fade_out_and_stop_current()
	ui_all_cards.queue_free()
	set_lawnmover()
	path_follow_2d.move_backward()

var ready_set_plant_sfx: AudioStream = load("res://shared/assets/audio/general_music/readysetplant.wav")
func set_after_card_selection():
	card_selection.visible = true
	Audiomanager.play_sfx(ready_set_plant_sfx)
	animation_player.play("ready_set_plant")
	await animation_player.animation_finished
	GameProgressBus.game_started.emit()

func set_setting():
	Settings.ingameset.game_control = self

func _on_button_pressed() -> void :
	Settings.ingameset.pause_game()
	pass

var game_over: bool = false
func _on_deadzone_area_entered(area: Area2D) -> void :
	if area.is_in_group("zombie"):
		game_over = true
		manager.process_mode = PROCESS_MODE_DISABLED
		returnmenu.visible = true
		lose.visible = true
	pass


func _on_button3_pressed() -> void :
	var m: PackedScene = load("res://2d/scenes/levels/chose_map.tscn")
	get_tree().change_scene_to_packed(m)
	pass
