extends CanvasLayer

var in_game_setting: PackedScene = load("res://UI/InGameSetting.tscn")
var ingameset: Control

func _ready() -> void :
	layer = 10
	ingameset = in_game_setting.instantiate()
	add_child(ingameset)
	ingameset.visible = false
