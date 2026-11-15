extends TextureButton

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var ismove: bool = false
var isflower: bool = true
var collect_sfx: AudioStream = load("res://shared/assets/audio/general_music/points.wav")

@export var move_speed: float = randf_range(2000, 3200)
@export var angular_speed: float = 90.0

var t: Tween

func move_to(pos: Vector2, duration: float):
	stop_move()
	t = create_tween()
	t.tween_property(self, "position", pos, duration)

func stop_move():
	if t:
		t.kill()

var target_position = Vector2(-150, -150)

func _ready():

	if isflower:
		move_to(get_random_upper_circle_point(), 1.0)
	else:
		move_to(global_position + Vector2(0, randi_range(300, 600)), 6)


func _process(delta: float) -> void :

	rotation_degrees += angular_speed * delta
	if ismove:
		var direction = (target_position - self.global_position).normalized()
		self.global_position += direction * move_speed * delta

		if self.global_position.x < -50:
			on_arrived()


func on_arrived():

	Globalmanager.suns.sun_num += 50
	Audiomanager.play_sfx(collect_sfx)

	queue_free()


func get_random_upper_circle_point() -> Vector2:
	var angle = randf_range(0, PI)
	var radius = 50
	return position + Vector2.from_angle(angle) * radius


func _on_pressed() -> void :
	stop_move()
	ismove = true
	pass


func _on_timer_timeout() -> void :
	animation_player.play("will_del")
	await get_tree().create_timer(6).timeout
	queue_free()
	pass
