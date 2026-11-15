extends Node2D
@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar

signal update_hp

func _ready() -> void :
	update_hp.connect(texture_progress_bar.update)
	pass
