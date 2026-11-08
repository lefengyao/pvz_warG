extends CanvasLayer

## 全局转场（autoload 名：ScreenFade）。
##
## 三种模式：
##   fade_to_*     纯渐变（整块遮罩渐隐）
##   circle_to_*   圆形扩散：实心圆从点击处长大包住旧画面 → 切场景 → 从圆心挖洞散开
##                 （这是当前主要使用的转场）
##   zoom_to_*     推镜：把当前场景根节点朝点击处放大后淡出（保留备用）
##
## 遮罩在 layer = 128，mouse_filter = IGNORE，不挡点击。

@onready var rect: ColorRect = $Rect
@onready var circle: ColorRect = $Circle

var _mat: ShaderMaterial
var _circle_mat: ShaderMaterial

## 圆形转场默认时长（收拢 / 散开）
const CIRCLE_COVER := 0.8
const CIRCLE_REVEAL := 1.0

## 圆的边缘抗锯齿宽度（像素）。2 左右即可，越大越糊
const CIRCLE_EDGE_PX := 2.0

## 推镜默认参数
const ZOOM_DURATION := 0.55
const ZOOM_FACTOR := 1.9

func _ready() -> void :
	layer = 128
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# material 的静态类型是 Material，必须显式转成 ShaderMaterial
	_mat = rect.material as ShaderMaterial
	_circle_mat = circle.material as ShaderMaterial
	_set_progress(0.0)
	rect.visible = false
	circle.visible = false

func _set_progress(v: float) -> void :
	if _mat != null:
		_mat.set_shader_parameter("progress", v)

# —— 纯渐变 ——

## 渐变遮住屏幕。
func fade_out(duration: float = 0.45) -> void :
	rect.visible = true
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	await tween.finished

## 渐变露出屏幕。
func fade_in(duration: float = 0.45) -> void :
	rect.visible = true
	var tween := create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, duration)
	await tween.finished
	rect.visible = false

## 遮住 → 切换场景 → 露出。
func change_scene_to_packed(scene: PackedScene, duration: float = 0.45) -> void :
	if scene == null:
		return
	await fade_out(duration)
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await fade_in(duration)

## 同上，但接受已实例化的节点（关卡需要先注入 level_logic）。
func change_scene_to_node(node: Node, duration: float = 0.45) -> void :
	if node == null:
		return
	await fade_out(duration)
	get_tree().change_scene_to_node(node)
	await get_tree().process_frame
	await fade_in(duration)

# —— 圆形扩散（主要转场） ——
#
# focus 是屏幕像素坐标，作为圆心。

## 圆形收放到 PackedScene：画面收拢成点 → 换场景 → 从点散开。
func circle_to_scene_packed(scene: PackedScene, focus: Vector2,
		cover_duration: float = CIRCLE_COVER, reveal_duration: float = CIRCLE_REVEAL) -> void :
	if scene == null:
		return
	_setup_circle(focus)
	await _circle_collapse(cover_duration)
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await _circle_expand(reveal_duration)

## 圆形收放到已实例化的节点。
func circle_to_scene_node(node: Node, focus: Vector2,
		cover_duration: float = CIRCLE_COVER, reveal_duration: float = CIRCLE_REVEAL) -> void :
	if node == null:
		return
	_setup_circle(focus)
	await _circle_collapse(cover_duration)
	get_tree().change_scene_to_node(node)
	await get_tree().process_frame
	await _circle_expand(reveal_duration)

## 按视口与焦点初始化圆形遮罩的参数。
func _setup_circle(focus: Vector2) -> void :
	rect.visible = false
	if _circle_mat == null:
		return

	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)
	var ratio: float = vp_size.x / max(vp_size.y, 1.0)

	_circle_mat.set_shader_parameter("screen_ratio", ratio)
	# 焦点到四角的最大距离（归一化空间），保证圆能覆盖整个屏幕
	_circle_mat.set_shader_parameter("max_radius", sqrt(ratio * ratio + 1.0))
	_circle_mat.set_shader_parameter("focus_uv", Vector2(focus.x / vp_size.x, focus.y / vp_size.y))
	# 边缘抗锯齿宽度：由 shader 用 fwidth 换算成恒定像素宽度
	_circle_mat.set_shader_parameter("edge_width", CIRCLE_EDGE_PX)
	# hole = 1 时完全不遮挡，从这里开始收拢
	_circle_mat.set_shader_parameter("hole", 1.0)

	circle.visible = true

## 阶段一：把画面收拢进一个不断缩小的圆，直到只剩一个点。
func _circle_collapse(duration: float) -> void :
	var tween := create_tween()
	tween.tween_method(_set_circle_hole, 1.0, 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

## 阶段二：圆从这个点长大，把新画面散开。
func _circle_expand(duration: float) -> void :
	var tween := create_tween()
	tween.tween_method(_set_circle_hole, 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	circle.visible = false

func _set_circle_hole(v: float) -> void :
	if _circle_mat != null:
		_circle_mat.set_shader_parameter("hole", v)

# —— 推镜（备用） ——

## 推镜到 PackedScene：把当前场景根节点朝 focus 放大并淡出。
func zoom_to_scene_packed(scene: PackedScene, focus: Vector2,
		duration: float = ZOOM_DURATION, zoom: float = ZOOM_FACTOR) -> void :
	if scene == null:
		return
	await _zoom_out_current(focus, duration, zoom)
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await _fade_in_current(duration * 0.8)

## 推镜到已实例化的节点。
func zoom_to_scene_node(node: Node, focus: Vector2,
		duration: float = ZOOM_DURATION, zoom: float = ZOOM_FACTOR) -> void :
	if node == null:
		return
	await _zoom_out_current(focus, duration, zoom)
	get_tree().change_scene_to_node(node)
	await get_tree().process_frame
	await _fade_in_current(duration * 0.8)

func _zoom_out_current(focus: Vector2, duration: float, zoom: float) -> void :
	var root := get_tree().current_scene
	if root == null:
		return

	if root is Control:
		var c: Control = root
		var inv: Transform2D = c.get_global_transform_with_canvas().affine_inverse()
		c.pivot_offset = inv * focus

		var target_scale: Vector2 = c.scale * zoom
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(c, "scale", target_scale, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(c, "modulate:a", 0.0, duration)
		await tween.finished
		return

	await fade_out(duration)

func _fade_in_current(duration: float) -> void :
	var root := get_tree().current_scene
	if root != null and "modulate" in root:
		root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(root, "modulate:a", 1.0, duration)
		await tween.finished
