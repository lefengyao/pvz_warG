class_name EcsSystem
extends RefCounted

## Base class for behavior executed by [EcsWorld]. Subclass it to process entities
## that share a component shape. Lower [member priority] values run first; ties retain
## registration order.[br][br]
## [codeblock]
## class DamageSystem extends EcsSystem:
##     func on_update(world: EcsWorld, _delta: float) -> void:
##         for entity_id in world.query({"all": [&"health"]}).entities():
##             world.set_component(entity_id, &"health", 0)
## [/codeblock]
##
## @tutorial(GDScript documentation comments): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html

## Scheduling priority used by [EcsWorld]. Smaller values update first.
## [code]priority = 100[/code] places a movement system after input systems at priority 0.
var priority: int = 0


## Called exactly once when this system is added to a world.
## Override it to store world-specific references or initialize configuration.
func configure(_world: EcsWorld) -> void:
	pass


## Called when the owning [EcsWorld] starts, including immediately for systems
## added after the world has already started.
func on_start() -> void:
	pass


## Called once per [method EcsWorld.tick]. Override this method with system behavior.
## [code]world.query({"all": [&"position"]}).for_each(update_position)[/code]
func on_update(_world: EcsWorld, _delta: float) -> void:
	pass


## Called when the owning [EcsWorld] stops or immediately before the system is removed
## from a running world. Release external resources here.
func on_stop() -> void:
	pass
