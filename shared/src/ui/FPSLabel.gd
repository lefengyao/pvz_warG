extends Label

@export_range(0.1, 2.0, 0.1) var refresh_interval: float = 0.5

var _time_since_refresh: float = 0.0

func _ready() -> void:
	_update_fps()

func _process(delta: float) -> void:
	_time_since_refresh += delta
	if _time_since_refresh < refresh_interval:
		return
	_time_since_refresh = 0.0
	_update_fps()

func _update_fps() -> void:
	text = "FPS: %d" % roundi(Engine.get_frames_per_second())
