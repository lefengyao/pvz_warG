extends Control

## 庭院关卡选择的主控脚本。
##
## 交互：
##   1. 点格子 = **只选中**，不直接进关；标题显示所选关卡名
##   2. 右下「开始」按钮 = 真正进入所选关卡（未选中时不可点）
##   3. 进关时用 ScreenFade（shader 渐变）做转场
##
## 格子的生成、拼图裁切、状态推导都在 src/levels/front_yard/level_grid.gd。

## 关卡数据，顺序即格子顺序。场景里已内联了 4 关。
@export var level_resources: Array[LevelResource] = []

## 「返回」按钮回到的界面。
@export var back_scene: PackedScene = load("res://2d/scenes/levels/chose_map.tscn")

## 点击格子时的音效。
@export var tap_sfx: AudioStream

## 已通关的关卡数（临时占位，后续接存档）。
@export var cleared_count: int = 1

## 网格节点。用无类型声明，避免依赖 class_name 解析失败时整脚本编译不过。
@onready var grid = $Board/LevelGrid
@onready var title: Label = $Label
@onready var start_button: Button = $StartButton

## 当前选中的关卡下标，-1 表示没有选中。
var _selected_index: int = -1

func _ready() -> void :
	grid.level_selected.connect(_on_level_selected)
	grid.build(level_resources, cleared_count)
	_set_start_enabled(false)
	_update_title()

## 点格子：只记录选中，更新标题与按钮状态。
func _on_level_selected(index: int) -> void :
	_selected_index = index
	_update_title()
	_set_start_enabled(index >= 0 and index < level_resources.size())

## 标题：进度 + 当前选中的关卡名。
func _update_title() -> void :
	var total: int = level_resources.size()
	var done: int = clampi(cleared_count, 0, total)
	var caption := "庭院危机  %d / %d" % [done, total]
	if _selected_index >= 0 and _selected_index < total:
		var res: LevelResource = level_resources[_selected_index]
		if res != null:
			caption += "   ·   " + res.level_name
	title.text = caption

## 没有选中关卡时，开始按钮置灰且不可点。
func _set_start_enabled(p_enabled: bool) -> void :
	start_button.disabled = not p_enabled
	start_button.modulate.a = 1.0 if p_enabled else 0.5

## 「开始」按钮：进入当前选中的关卡。
func _on_start_pressed() -> void :
	if _selected_index < 0 or _selected_index >= level_resources.size():
		return
	var res: LevelResource = level_resources[_selected_index]
	if res == null or res.level_scene == null:
		return
	_start_level(res)

## 实例化关卡场景，塞入对应的关卡逻辑，然后以「开始」按钮为圆心做圆形扩散转场。
func _start_level(res: LevelResource) -> void :
	Audiomanager.play_sfx(tap_sfx)

	var level_instance = res.level_scene.instantiate()
	if res.logic_scene != null and "level_logic" in level_instance:
		level_instance.level_logic = res.logic_scene

	await SceneTransition.circle_to_node(level_instance, _button_center(start_button))

## 「返回」按钮：回到选关界面（以按钮为圆心圆形扩散）。
func _on_button2_pressed() -> void :
	await SceneTransition.circle_to_packed(back_scene, _button_center($Button))

## 取控件中心在屏幕像素坐标下的位置，作为圆形转场的圆心。
func _button_center(control: Control) -> Vector2 :
	var xform := control.get_global_transform_with_canvas()
	return xform * (control.size * 0.5)
