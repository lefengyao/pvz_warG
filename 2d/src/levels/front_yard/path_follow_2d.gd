
extends PathFollow2D



@export var move_speed: float = 0.4


var tween: Tween = null


var is_moving_forward: bool = true


signal forward_completed
signal back_completed




func move_forward() -> void :
	stop_current_tween()
	is_moving_forward = true

	var duration: float = 1.0 / move_speed


	tween = create_tween()
	tween.tween_property(self, "progress_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_move_completed)
	await tween.finished
	forward_completed.emit()



func move_backward() -> void :
	stop_current_tween()
	is_moving_forward = false

	var duration: float = 1.0 / move_speed


	tween = create_tween()
	tween.tween_property(self, "progress_ratio", 0.0, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_move_completed)
	await tween.finished
	back_completed.emit()

func toggle_move_direction() -> void :
	if is_moving_forward:
		move_backward()
	else:
		move_forward()


func pause_move() -> void :
	if tween.is_running():
		tween.pause()


func resume_move() -> void :
	if tween.is_paused():
		tween.play()


func reset_to_start() -> void :
	stop_current_tween()
	progress_ratio = 0.0
	is_moving_forward = true


func stop_current_tween() -> void :
	if tween != null and tween.finished.is_connected(_on_move_completed):
		tween.finished.disconnect(_on_move_completed)
	if tween != null and tween.is_running():
		tween.kill()
	tween = null


func _on_move_completed() -> void :
	if is_moving_forward:
		print("✅ 向前移动完成！已到达路径终点（progress_ratio=1.0）")
	else:
		print("✅ 向后移动完成！已回到路径起点（progress_ratio=0.0）")
