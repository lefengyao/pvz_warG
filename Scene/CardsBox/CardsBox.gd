extends Node3D


const CARD_DATA := {
	"king": {
		"type": "植物卡牌",
		"name": "向日葵",
		"ability": "持续生产阳光，为其他植物提供种植资源。",
		"story": "面向阳光绽放，是庭院中最可靠的能量来源。",
	},
	"queen": {
		"type": "植物卡牌",
		"name": "豌豆射手",
		"ability": "向前方发射豌豆，持续攻击来袭的僵尸。",
		"story": "一颗豌豆，一份勇气，守住身后的每一寸草坪。",
	},
	"bishop": {
		"type": "植物卡牌",
		"name": "坚果",
		"ability": "用坚硬外壳阻挡僵尸，为后排植物争取时间。",
		"story": "沉默地站在最前方，把每一次啃咬都挡在身外。",
	},
	"swordsman": {
		"type": "植物卡牌",
		"name": "土豆地雷",
		"ability": "埋入草坪后等待触发，对靠近的僵尸造成爆炸伤害。",
		"story": "先在地下耐心等待，再用一次爆炸扭转战局。",
	},
}

const ACTIVE_COLOR := Color("d3a45a")
const INACTIVE_COLOR := Color("9faeb0")

@onready var selection_marker: ColorRect = $CanvasLayer/CardCollectionUI/Sidebar/SelectionMarker
@onready var card_list: VBoxContainer = $CanvasLayer/CardCollectionUI/Sidebar/CardList
@onready var type_label: Label = $CanvasLayer/CardCollectionUI/DetailsPanel/TypeLabel
@onready var card_name_label: Label = $CanvasLayer/CardCollectionUI/DetailsPanel/CardNameLabel
@onready var ability_label: Label = $CanvasLayer/CardCollectionUI/DetailsPanel/AbilityLabel
@onready var story_label: Label = $CanvasLayer/CardCollectionUI/DetailsPanel/StoryLabel
@onready var king_button: Button = $CanvasLayer/CardCollectionUI/Sidebar/CardList/KingButton
@onready var queen_button: Button = $CanvasLayer/CardCollectionUI/Sidebar/CardList/QueenButton
@onready var bishop_button: Button = $CanvasLayer/CardCollectionUI/Sidebar/CardList/BishopButton
@onready var swordsman_button: Button = $CanvasLayer/CardCollectionUI/Sidebar/CardList/SwordsmanButton
@onready var king_card: Node3D = $CardStage/PreviewCards/KingCard
@onready var queen_card: Node3D = $CardStage/PreviewCards/QueenCard
@onready var bishop_card: Node3D = $CardStage/PreviewCards/BishopCard
@onready var swordsman_card: Node3D = $CardStage/PreviewCards/SwordsmanCard

var buttons: Dictionary
var preview_cards: Dictionary
var selected_card := "queen"


func _ready() -> void:
	buttons = {
		"king": king_button,
		"queen": queen_button,
		"bishop": bishop_button,
		"swordsman": swordsman_button,
	}
	preview_cards = {
		"king": king_card,
		"queen": queen_card,
		"bishop": bishop_card,
		"swordsman": swordsman_card,
	}
	for card: Node3D in preview_cards.values():
		card.visible = false
	_select_card("queen")
	call_deferred("_refresh_selection_marker")


func _select_card(card_key: String) -> void:
	if not CARD_DATA.has(card_key):
		return

	selected_card = card_key
	var data: Dictionary = CARD_DATA[card_key]
	type_label.text = data["type"]
	card_name_label.text = data["name"]
	ability_label.text = data["ability"]
	story_label.text = data["story"]

	for preview_key: String in preview_cards:
		var card: Node3D = preview_cards[preview_key]
		var is_selected := preview_key == card_key
		card.call("set_default_tilt")
		card.call("set_inspection_enabled", is_selected)
		card.visible = is_selected
	for button_key: String in buttons:
		var button: Button = buttons[button_key]
		button.add_theme_color_override(
			"font_color",
			ACTIVE_COLOR if button_key == card_key else INACTIVE_COLOR,
		)
	_refresh_selection_marker()


func _refresh_selection_marker() -> void:
	if not buttons.has(selected_card):
		return

	var selected_button: Button = buttons[selected_card]
	selection_marker.position.y = card_list.position.y + selected_button.position.y + (selected_button.size.y - selection_marker.size.y) * 0.5


func _on_king_button_pressed() -> void:
	_select_card("king")


func _on_queen_button_pressed() -> void:
	_select_card("queen")


func _on_bishop_button_pressed() -> void:
	_select_card("bishop")


func _on_swordsman_button_pressed() -> void:
	_select_card("swordsman")
