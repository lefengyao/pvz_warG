extends Control

@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var label: Label = $sun_slot / Label

func get_cards(cards: Array):
	label.text = str(Globalmanager.suns.sun_num)
	for i in cards:
		h_box_container.add_child(i)

func start_game():
	visible = true
	for i in h_box_container.get_children():
		i.start_game = true

func _process(_delta: float) -> void :
	label.text = str(Globalmanager.suns.sun_num)
