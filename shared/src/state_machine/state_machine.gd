
extends Node
class_name StateMachine


var current_state: State = null


var states: Dictionary = {}


var previous_state_name: String = ""

signal finish

@export var owner_root: Node
func _ready() -> void :

	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.owner_root = owner_root

			child.process_mode = Node.PROCESS_MODE_DISABLED


	if states.has("IDLE"):
		change_state("IDLE")

	finish.emit()


func change_state(state_name: String, msg: Dictionary = {}) -> void :
	var new_state: State = states.get(state_name)
	if not new_state:
		push_error("状态机中没有状态: " + state_name)
		return


	if current_state == new_state:
		return


	if current_state:
		previous_state_name = current_state.name
		current_state.exit()
		current_state.process_mode = Node.PROCESS_MODE_DISABLED


	current_state = new_state
	current_state.process_mode = Node.PROCESS_MODE_INHERIT
	current_state.enter(msg)



func _process(delta: float) -> void :
	if current_state:
		current_state.update(delta)



func _physics_process(delta: float) -> void :
	if current_state:
		current_state.physics_update(delta)



func is_in_state(state_name: String) -> bool:
	return current_state and current_state.name == state_name
