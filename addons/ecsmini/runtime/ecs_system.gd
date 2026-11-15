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
enum Phase { SIMULATION, PRESENTATION }

signal schedule_changed

var enabled: bool = true
var debug_name: String = ""
var schedule_key: StringName = &"":
	set(value):
		schedule_key = value
		schedule_changed.emit()
var before: Array = []:
	set(value):
		before = value.duplicate()
		schedule_changed.emit()
var after: Array = []:
	set(value):
		after = value.duplicate()
		schedule_changed.emit()
var reads: Array = []:
	set(value):
		reads = value.duplicate()
		schedule_changed.emit()
var writes: Array = []:
	set(value):
		writes = value.duplicate()
		schedule_changed.emit()
var priority: int = 0:
	set(value):
		if priority != value:
			priority = value
			schedule_changed.emit()
var phase: int = Phase.SIMULATION:
	set(value):
		var normalized := clampi(value, Phase.SIMULATION, Phase.PRESENTATION)
		if phase != normalized:
			phase = normalized
			schedule_changed.emit()

# Prevent accidental sharing of one system instance by different worlds.
var _world_instance_id: int = 0


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


## Release cached queries and external references when removed or disposed.
func on_detach() -> void:
	pass
