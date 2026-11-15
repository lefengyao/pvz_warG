class_name EcsLabSimulation
extends RefCounted

## World-local simulation setup for the advanced ECS lab.
## This object does not own a clock; EcsReplay owns every simulation step.
const MOVEMENT_SYSTEM = preload("res://addons/ecsmini/systems/2d/movement_system.gd")

class LabEventSystem extends EcsSystem:
	func _init() -> void:
		priority = 200
		schedule_key = &"lab_events"
		debug_name = "Lab events"

	func on_update(world: EcsWorld, delta: float) -> void:
		var events := world.get_events()
		if events != null:
			events.emit_event(&"lab_tick", {"tick": world.simulation_tick, "delta": delta})

var world: EcsWorld
var movement_system: EcsMovementSystem
var event_system: EcsSystem
var compute_mode: StringName = &"serial"

func configure(target_world: EcsWorld, mode: StringName) -> bool:
	if target_world == null or target_world.is_disposed():
		return false
	world = target_world
	compute_mode = mode
	movement_system = MOVEMENT_SYSTEM.new()
	movement_system.compute_mode = mode
	event_system = LabEventSystem.new()
	if not world.add_system(movement_system):
		shutdown()
		return false
	if not world.add_system(event_system):
		shutdown()
		return false
	world.start()
	return true

func set_velocity(uid: int, velocity: Vector2) -> bool:
	if world == null or world.is_disposed() or not velocity.is_finite():
		return false
	var entity := world.get_entity_by_uid(uid)
	if entity < 0 or not world.has_component(entity, &"velocity"):
		return false
	return world.set_component(entity, &"velocity", velocity)

func shutdown() -> void:
	if world != null and not world.is_disposed():
		if movement_system != null:
			world.remove_system(movement_system)
		if event_system != null:
			world.remove_system(event_system)
	world = null
	movement_system = null
	event_system = null
