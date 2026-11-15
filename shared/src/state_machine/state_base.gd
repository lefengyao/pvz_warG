
extends Node
class_name State


var owner_root: Node

var state_machine: StateMachine


func enter(_msg: Dictionary = {}) -> void :
	pass


func update(_delta: float) -> void :
	pass


func physics_update(_delta: float) -> void :
	pass


func exit() -> void :
	pass
