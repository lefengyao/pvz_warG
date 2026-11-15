extends TextureButton


@export var plant_card: PackedScene = load("res://2d/scenes/plants/template/plant_template_card.tscn")
var p: plant_template_card
@export var sun_num: int
var all_cards_slot: GridContainer
var flow_cards_slot: HBoxContainer
var root_node: Control
var has_been_clicked: bool = false
@onready var label: Label = $Label

signal back
signal is_clicked
func _ready() -> void :
	label.text = str(sun_num)

func init(n, i: PackedScene):
	sun_num = n.sun_num
	p = plant_card.instantiate()
	p.sun_num = n.sun_num
	p.cool_time = n.cool_time
	p.cooling = n.cooling
	p.texture_normal = n.tex
	p.plant_card = i

	p.texture1 = n.tex2
	texture_normal = n.tex
	pass

func _on_button_down() -> void :
	if get_parent() == all_cards_slot:
		if not has_been_clicked:
			if root_node.is_it_click():
				Globalmanager.play_click_successful_sfx()
				has_been_clicked = true
				modulate = Color8(100, 100, 100, 255)
				is_clicked.emit(self)
				return
		Globalmanager.play_click_failed_sfx(2)
	elif get_parent() == flow_cards_slot:
		Globalmanager.play_click_successful_sfx()
		back.emit()
		root_node.current_num -= 1
		queue_free()
	pass

func reset():
	has_been_clicked = false
	modulate = Color8(255, 255, 255, 255)
