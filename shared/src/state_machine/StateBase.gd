extends Node
class_name StateBase

# 状态机管理器的引用
var state_machine: Node

func enter_state(_previous_state: StateBase) -> void:
	pass

func exit_state(_new_state: StateBase) -> void:
	pass

func process(_delta: float) -> void:
	pass

func physics_process(_delta: float) -> void:
	pass

# 辅助函数：请求切换状态，参数为状态名字符串
func request_state_change(new_state_name: String) -> void:
	if state_machine:
		state_machine.change_state(new_state_name)
