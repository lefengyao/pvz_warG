extends Control

## 游戏内「暂停 / 设置」面板（场景：scenes/ui/in_game_setting.tscn）。
##
## 这个面板不会自己出现在场景里，而是由全局单例 Settings 在启动时实例化，
## 挂在 canvas layer 下并隐藏：
##   /root/Settings (CanvasLayer)
##   └── InGameSetting (本脚本)
##
## 关卡在进入时把自己的根节点通过 game_control 注入进来，
## 面板再通过切换 game_control 的 process_mode 来实现暂停 / 恢复。

## 被暂停的对象，通常由关卡在 _ready 阶段注入关卡根节点。
## 暂停时把它的 process_mode 设为 DISABLED，整棵关卡子树都会停止处理
## （物理、动画、计时器全部冻结），而不是只挡住输入。
@export var game_control: Control

## 点「返回主菜单」时跳转的场景。默认指向选关界面。
@export var main_menu_scene: PackedScene = load("res://scenes/levels/chose_map.tscn")

## 暂停：冻结关卡并显示面板。
## 注意 game_control 可能还没注入（比如直接从主菜单打开），所以要先判空。
func pause_game() -> void :
	if game_control:
		game_control.process_mode = PROCESS_MODE_DISABLED
	visible = true

## 返回主菜单：
##   1. 先把关卡恢复成正常处理状态（否则换了场景它还停在 DISABLED）；
##   2. 再切换到主菜单场景；
##   3. 最后隐藏自己，避免切换过程中面板残留在画面上。
func go_to_main_menu() -> void :

	if game_control:
		game_control.process_mode = PROCESS_MODE_INHERIT


	if main_menu_scene:
		get_tree().change_scene_to_packed(main_menu_scene)
	else:
		push_error("主菜单场景未设置！")
	visible = false

## 继续游戏：恢复关卡处理状态并隐藏面板。
func resume_game() -> void :
	if game_control:
		game_control.process_mode = PROCESS_MODE_INHERIT
	visible = false


## 面板上「返回主菜单」按钮的回调（场景里已连线）。
func _on_button_pressed() -> void :
	go_to_main_menu()


## 面板上「返回游戏」按钮的回调（场景里已连线）。
func _on_button_2_pressed() -> void :
	resume_game()
