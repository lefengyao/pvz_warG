class_name EcsMovementSystem
extends EcsSystem

## Optional 2D movement system that integrates [code]position[/code] from
## [code]velocity[/code]. Both components must contain [Vector2] values.
## This class never reads or writes a [Node], so it is suitable for headless simulation.[br][br]
## [codeblock]
## world.add_system(EcsMovementSystem.new())
## world.add_component(entity, &"position", Vector2.ZERO)
## world.add_component(entity, &"velocity", Vector2.RIGHT * 120.0)
## [/codeblock]
##
## @tutorial(2D movement overview): https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html

## Component key for the [Vector2] position updated by this system.
const POSITION: StringName = &"position"
## Component key for the [Vector2] velocity sampled by this system.
const VELOCITY: StringName = &"velocity"


## Configures movement to run after typical input systems at priority 100.
func _init() -> void:
	priority = 100


## Adds [code]velocity * delta[/code] to [code]position[/code] for every entity that
## has both required components. For example, velocity [code]Vector2(60, 0)[/code]
## moves an entity 30 pixels during a 0.5 second tick.
func on_update(world: EcsWorld, delta: float) -> void:
	for entity_id in world.query({"all": [POSITION, VELOCITY]}).entities():
		var position: Vector2 = world.get_component(entity_id, POSITION, Vector2.ZERO)
		var velocity: Vector2 = world.get_component(entity_id, VELOCITY, Vector2.ZERO)
		world.set_component(entity_id, POSITION, position + velocity * delta)
