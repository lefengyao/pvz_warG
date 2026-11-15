extends Control
@onready var label: Label = $slot / sun_slot / Label
@export var all_cards_slot: GridContainer
@export var flow_cards_slot: HBoxContainer
@export var sun_num: int = 100
signal card_acquired
var cards: Array

var chosen_card: PackedScene = load("res://2d/scenes/plants/template/chose_card_template.tscn")
var max_num: int = 11
var current_num: int = 0
func _ready() -> void :
	label.text = str(sun_num)
	for i in GenerateCards.plant_cards:
		var j: PackedScene = load(i)
		var n = j.instantiate()
		var c = chosen_card.instantiate()
		c.init(n, j)
		# Only the card data is needed; this plant instance never enters the tree.
		n.free()
		all_cards_slot.add_child(c)
		c.all_cards_slot = all_cards_slot
		c.flow_cards_slot = flow_cards_slot
		c.root_node = self
		c.is_clicked.connect(chose_card)

func _exit_tree() -> void:
	# Selected cards are reparented into the battle UI. Dispose only the
	# unselected card instances that were created without a parent.
	for card in all_cards_slot.get_children():
		var preview_card = card.get("p")
		if is_instance_valid(preview_card) and preview_card.get_parent() == null:
			preview_card.free()

func chose_card(card1: Control):
	for i in all_cards_slot.get_children():
		if i == card1:
			var node_copy = i.duplicate()
			node_copy.p = i.p
			node_copy.modulate = Color8(255, 255, 255, 255)
			node_copy.back.connect(i.reset)
			node_copy.all_cards_slot = all_cards_slot
			node_copy.flow_cards_slot = flow_cards_slot
			node_copy.root_node = i.root_node
			flow_cards_slot.add_child(node_copy)
			current_num += 1

func _on_texture_button_button_down() -> void :
	Globalmanager.play_click_successful_sfx()
	for i in flow_cards_slot.get_children():
		cards.append(i.p)
	card_acquired.emit(cards)
	pass

func is_it_click():
	return current_num < max_num
