extends Node
class_name StateMachineManager

# 使用字符串作为键储存状态节点
var states: Dictionary = {}
# 初始状态为空
var current_state: StateBase = null
var previous_state: StateBase = null

func _ready() -> void:
	# 1. 读取子节点并注册为状态
	for child in get_children():
		if child is StateBase:
			# 直接使用节点的名字作为状态名（字符串）
			var state_name = child.name
			states[state_name] = child
			child.state_machine = self

func _process(delta: float) -> void:
	# 判空保护，如果没有初始状态则不执行
	if current_state:
		current_state.process(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

# 状态切换逻辑（参数为字符串）
func change_state(new_state_name: String) -> void:
	# 如果传入空字符串，可以选择退出当前状态回到空状态
	if new_state_name == "":
		if current_state:
			current_state.exit_state(null)
			previous_state = current_state
			current_state = null
		return
		
	# 检查目标状态是否存在
	if not states.has(new_state_name):
		push_warning("状态机错误: 找不到状态 -> " + new_state_name)
		return
	
	var new_state: StateBase = states[new_state_name]
	
	# 如果目标状态就是当前状态，不重复切换
	if current_state == new_state:
		return
		
	# 调用旧状态退出函数
	if current_state:
		current_state.exit_state(new_state)
		previous_state = current_state
		
	# 更新当前状态并调用进入函数
	current_state = new_state
	if previous_state == null:
		previous_state = current_state
	current_state.enter_state(previous_state)
