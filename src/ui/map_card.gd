extends Control

## 单张地图卡片（模板场景：scenes/ui/map_card.tscn）。
##
## 职责：
##   1. 从 MapInfo 资源读取背景图 / 地图名 / 锁定状态，填到节点上；
##   2. 鼠标悬停时显示高亮层并播放音效；
##   3. 点击时跳转到这张地图对应的关卡（锁定的卡片不跳转）；
##   4. 用正弦函数做漂浮动画，三张卡各自随机相位/频率/幅度，互不同步。
##
## 节点结构：
##   MapCard（本节点，由 HBoxContainer 管理位置）
##   └── Body（动画层，_process 只动它的 position / rotation）
##       ├── Frame       九宫格外框底板
##       ├── CardButton  地图背景按钮，接收鼠标事件
##       └── Hover       悬停高亮层，名字和状态文字都挂在它下面
##
## 为什么动画作用在 Body 而不是 MapCard 本身：
##   MapCard 在 HBoxContainer 里，容器会接管子节点位置，直接改它的 position
##   会被容器下一次排序覆盖；Body 不受容器管理，可以自由移动。

## 这张卡片对应的地图数据。在主场景里把对应的 .tres 拖进来即可，
## 模板本身不保存任何具体地图信息。
@export var info: MapInfo

## 鼠标移入时播放的音效（当前三张卡都指向 tap.wav）。
@export var tap_sfx: AudioStream

## 纵向漂浮幅度，单位是场景单位（屏幕上约为 ×1.334）。
## 数值越大上下浮动越明显，6.0 大约是 8 像素。
@export var float_amplitude: float = 6.0

## 漂浮整体速度倍数。三个轴的基础角速度都会乘以它，改这一个就能整体调快慢。
@export var float_speed: float = 0.9

## 横向摆动幅度（场景单位）。设 0 就完全不左右晃，只剩上下浮动。
@export var sway_amplitude: float = 1.8

## 倾斜角度（度）。设 0 则只做平移、不旋转。
@export var tilt_degrees: float = 0.5

## 动画层与它的子节点引用。
@onready var body: Control = $Body
@onready var card_button: TextureButton = $Body/CardButton
@onready var hover: TextureRect = $Body/Hover
@onready var name_label: Label = $Body/Hover/NameLabel
@onready var status_label: Label = $Body/Hover/StatusLabel

# —— 动画状态 ——
# 每个卡片实例在 _ready 时各随机一份，所以三张卡的运动轨迹不会同步。
var _time: float = 0.0        # 累计时间（秒），每帧累加 delta
var _phase_x: float = 0.0     # 横向初相，决定起始位置
var _phase_y: float = 0.0     # 纵向初相
var _phase_r: float = 0.0     # 旋转初相
var _speed_x: float = 1.0     # 横向角速度（弧度/秒）
var _speed_y: float = 1.0     # 纵向角速度
var _speed_r: float = 1.0     # 旋转角速度
var _amp_x: float = 3.0       # 横向实际幅度
var _amp_y: float = 6.0       # 纵向实际幅度
var _tilt: float = 0.0        # 实际倾斜幅度（弧度，由 tilt_degrees 换算）

func _ready() -> void :
	# 高亮层默认隐藏，鼠标移上去才显示
	hover.visible = false
	card_button.pressed.connect(_on_pressed)
	card_button.mouse_entered.connect(_on_mouse_entered)
	card_button.mouse_exited.connect(_on_mouse_exited)
	# 卡片尺寸由容器决定，尺寸变化时要重新设置旋转中心
	resized.connect(_refresh_pivot)

	# 用时间做种子：每张卡、每次进游戏拿到的参数都不一样
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_phase_x = rng.randf_range(0.0, TAU)
	_phase_y = rng.randf_range(0.0, TAU)
	_phase_r = rng.randf_range(0.0, TAU)
	# 横向速度刻意比纵向慢：两轴频率不同，才会走出椭圆 / 8 字轨迹，
	# 而不是一条上下直来直去的线
	_speed_x = rng.randf_range(0.45, 0.85) * float_speed
	_speed_y = rng.randf_range(0.7, 1.3) * float_speed
	_speed_r = rng.randf_range(0.6, 1.1) * float_speed
	_amp_x = rng.randf_range(0.6, 1.4) * sway_amplitude
	_amp_y = rng.randf_range(0.6, 1.2) * float_amplitude
	_tilt = deg_to_rad(tilt_degrees)
	# 起始时间也错开，避免第一帧三张卡完全同步
	_time = rng.randf_range(0.0, 10.0)

	_refresh_pivot()

	if info == null:
		push_warning("MapCard 没有配置 MapInfo")
		return

	# 所有展示内容都来自资源，模板本身不含具体地图数据
	card_button.texture_normal = info.background
	name_label.text = info.display_name
	status_label.text = info.locked_text if info.locked else "进入"

## 旋转必须绕卡片中心，否则会绕左上角转，看起来像歪倒。
## Body 由锚点铺满卡片，尺寸要等容器排版后才确定，所以在 resized 里同步。
func _refresh_pivot() -> void :
	body.pivot_offset = body.size * 0.5

func _process(delta: float) -> void :
	_time += delta
	# 横纵两个方向用不同频率的正弦叠加 → 轨迹是缓慢的椭圆 / 8 字
	body.position = Vector2(
		sin(_time * _speed_x + _phase_x) * _amp_x,
		sin(_time * _speed_y + _phase_y) * _amp_y
	)
	# 再叠一点微幅倾斜，让卡片像是悬在空中随气流摆动
	body.rotation = sin(_time * _speed_r + _phase_r) * _tilt

## 鼠标移入：显示高亮层（名字 / 状态文字都在里面）+ 播放悬停音效。
func _on_mouse_entered() -> void :
	hover.visible = true
	if tap_sfx != null:
		Audiomanager.play_sfx(tap_sfx)

## 鼠标移出：收起高亮层。
func _on_mouse_exited() -> void :
	hover.visible = false

## 点击卡片：只有「未锁定 + 配了目标场景」的卡片才跳转。
## 锁定卡片（森林 / 森林深处）点了没有任何反应。
func _on_pressed() -> void :
	if info == null or info.locked or info.target_scene == null:
		return
	# 以卡片中心作为圆心的屏幕像素坐标
	var xform := get_global_transform_with_canvas()
	var focus: Vector2 = xform * (size * 0.5)
	await SceneTransition.circle_to_packed(info.target_scene, focus)
