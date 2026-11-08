extends Control

## 主菜单。
##
## 结构（对应 chose_map.tscn）：
##   Title        标题 pvz_warG
##   MenuRoot     三个选项：闯关模式 / 创作者名单 / 开源声明
##   MapRoot      三张地图卡片，默认隐藏
##   BackButton   地图模式下左上角的返回
##   setting      右上角设置按钮 + 音频面板
##   ConfirmLayer 通用信息弹层（创作者名单 / 开源声明用）
##
## 交互：
##   点「闯关模式」→ 标题淡出、选项下落消失 → 地图卡片从下方升起
##   点「返回」    → 卡片落下 → 标题与选项回到原位

@onready var title: Label = $Title
@onready var menu_root: VBoxContainer = $MenuRoot
@onready var map_root: Control = $MapRoot
@onready var back_button: Button = $BackButton
@onready var setting_panel: NinePatchRect = $setting/setting
@onready var info_layer: Control = $ConfirmLayer
@onready var info_dim: ColorRect = $ConfirmLayer/Dim
@onready var info_panel: NinePatchRect = $ConfirmLayer/Panel
@onready var info_title: Label = $ConfirmLayer/Panel/Title
@onready var info_message: Label = $ConfirmLayer/Panel/Message
@onready var info_open_1: Button = $ConfirmLayer/Panel/OpenButton
@onready var info_open_2: Button = $ConfirmLayer/Panel/OpenButton2

@onready var story_button: Button = $MenuRoot/StoryButton
@onready var credits_button: Button = $MenuRoot/CreditsButton
@onready var license_button: Button = $MenuRoot/LicenseButton

## 菜单模式 / 地图模式
var _in_map_mode: bool = false

## 选项栏的原始 y，返回时要用它复位
var _menu_base_y: float = 0.0

## 设置面板 / 信息弹层未做动画时的原始位置
var _setting_base: Vector2 = Vector2.ZERO
var _info_panel_base: Vector2 = Vector2.ZERO

## 正在播放的弹出 / 收起动画，重复点击时先打断
var _setting_tween: Tween
var _info_tween: Tween

## 信息层当前要打开的链接（最多两个），点「查看」时用
var _info_url_1: String = ""
var _info_url_2: String = ""

func _ready() -> void :
	Audiomanager.fade_out_and_stop_current()

	_menu_base_y = menu_root.position.y
	_setting_base = setting_panel.position
	_info_panel_base = info_panel.position
	map_root.visible = false
	back_button.visible = false
	info_layer.visible = false

	story_button.pressed.connect(_on_story_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	license_button.pressed.connect(_on_license_pressed)
	back_button.pressed.connect(_on_back_pressed)

# —— 模式切换 ——

## 进入闯关：标题与选项淡出并下落，随后地图卡片升起。
func _on_story_pressed() -> void :
	if _in_map_mode:
		return
	_in_map_mode = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title, "modulate:a", 0.0, 0.28)
	tween.tween_property(menu_root, "modulate:a", 0.0, 0.24)
	tween.tween_property(menu_root, "position:y", _menu_base_y + 220.0, 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_show_map_cards)

func _show_map_cards() -> void :
	menu_root.visible = false
	map_root.visible = true
	map_root.modulate.a = 0.0
	map_root.position.y = 320.0
	back_button.visible = true
	back_button.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(map_root, "modulate:a", 1.0, 0.3)
	tween.tween_property(map_root, "position:y", 0.0, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(back_button, "modulate:a", 1.0, 0.3)

## 返回菜单：卡片落下，标题与选项复位。
func _on_back_pressed() -> void :
	if not _in_map_mode:
		return
	_in_map_mode = false

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(map_root, "modulate:a", 0.0, 0.22)
	tween.tween_property(map_root, "position:y", 260.0, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(back_button, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(_show_menu)

func _show_menu() -> void :
	map_root.visible = false
	back_button.visible = false
	menu_root.visible = true
	menu_root.position.y = _menu_base_y + 120.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(menu_root, "modulate:a", 1.0, 0.28)
	tween.tween_property(menu_root, "position:y", _menu_base_y, 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "modulate:a", 1.0, 0.28)

# —— 信息弹层 ——

## 创作者名单：两个链接，分别给「查看」按钮。
func _on_credits_pressed() -> void :
	_show_info(
		"创作者名单",
		"作者：恋梓里\nhttps://space.bilibili.com/1986364363\n美术：石英suartz\nhttps://space.bilibili.com/169529553",
		"https://space.bilibili.com/1986364363?spm_id_from=333.1007.0.0", "作者",
		"https://space.bilibili.com/169529553?spm_id_from=333.337.0.0", "美术")

## 开源声明：源码仓库 + 许可证。
func _on_license_pressed() -> void :
	_show_info(
		"开源声明",
		"本项目使用 Godot Engine 开发，基于 Apache License 2.0 开源。\n源码仓库：\nhttps://github.com/lefengyao/pvz_warG-2",
		"https://github.com/lefengyao/pvz_warG-2", "源码")

## 打开通用信息层。url 为空时对应按钮隐藏，只用「关闭」。
func _show_info(p_title: String, p_text: String, p_url_1: String, p_label_1: String,
		p_url_2: String = "", p_label_2: String = "") -> void :
	info_title.text = p_title
	info_message.text = p_text

	_info_url_1 = p_url_1
	_info_url_2 = p_url_2

	info_open_1.text = p_label_1
	info_open_1.visible = not p_url_1.is_empty()
	info_open_2.text = p_label_2
	info_open_2.visible = not p_url_2.is_empty()

	# 信息层：遮罩淡入 + 面板弹跳升起
	info_layer.visible = true
	if _info_tween != null and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = create_tween()
	info_dim.modulate.a = 0.0
	_info_tween.tween_property(info_dim, "modulate:a", 1.0, 0.25)
	_pop_in(info_panel, _info_panel_base, 90.0, 0.5)

func _on_info_open_1_pressed() -> void :
	if not _info_url_1.is_empty():
		OS.shell_open(_info_url_1)

func _on_info_open_2_pressed() -> void :
	if not _info_url_2.is_empty():
		OS.shell_open(_info_url_2)

## 信息层「关闭」：面板下落 + 遮罩淡出后隐藏。
func _on_info_close_pressed() -> void :
	_info_url_1 = ""
	_info_url_2 = ""
	if _info_tween != null and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = create_tween()
	_info_tween.set_parallel(true)
	_info_tween.tween_property(info_panel, "position", _info_panel_base + Vector2(0, 60), 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_info_tween.tween_property(info_dim, "modulate:a", 0.0, 0.2)
	_info_tween.chain().tween_callback(_hide_info_layer)

func _hide_info_layer() -> void :
	info_layer.visible = false
	info_panel.position = _info_panel_base
	info_dim.modulate.a = 1.0

# —— 设置 ——

## 右上角「设置」：面板弹跳升起。
func _on_button3_pressed() -> void :
	_pop_in(setting_panel, _setting_base, 90.0, 0.5)

## 音频面板里的「返回」：面板下落收起。
func _on_button_2_pressed() -> void :
	if _setting_tween != null and _setting_tween.is_valid():
		_setting_tween.kill()
	_setting_tween = create_tween()
	_setting_tween.set_parallel(true)
	_setting_tween.tween_property(setting_panel, "position", _setting_base + Vector2(0, 60), 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_setting_tween.tween_property(setting_panel, "modulate:a", 0.0, 0.2)
	_setting_tween.chain().tween_callback(_hide_setting_panel)

func _hide_setting_panel() -> void :
	setting_panel.visible = false
	setting_panel.position = _setting_base
	setting_panel.modulate.a = 1.0

# —— 通用：弹跳出现 ——

## 和地图卡片同一套曲线：从下方升起、TRANS_BACK 回弹、同时淡入。
## base 是这个控件"静止时"的位置，只捕获一次，反复打开不会漂移。
func _pop_in(node: Control, base: Vector2, rise: float = 90.0, duration: float = 0.5) -> void :
	var tween := create_tween()
	tween.set_parallel(true)

	node.visible = true
	node.position = base + Vector2(0, rise)
	node.modulate.a = 0.0

	tween.tween_property(node, "modulate:a", 1.0, duration * 0.55)
	tween.tween_property(node, "position", base, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 记录是哪条动画，收起时可以打断
	if node == setting_panel:
		_setting_tween = tween
	elif node == info_panel:
		_info_tween = tween
