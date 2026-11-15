extends Node

@onready var timer: Timer = $Timer
@onready var marker_2d_2: Marker2D = $Marker2D2
@onready var marker_2d: Marker2D = $Marker2D

var sun: PackedScene = load("res://2d/scenes/objects/loot/sun/sun.tscn")

func _on_timer_timeout() -> void :
	var sun1 = sun.instantiate()
	sun1.isflower = false
	var y = randf_range(marker_2d.global_position.y, marker_2d_2.global_position.y)
	var x = randf_range(marker_2d.global_position.x, marker_2d_2.global_position.x)
	sun1.global_position.x = x
	sun1.global_position.y = y
	Globalmanager.suns.add_child(sun1)

func start_game():
	timer.start()
