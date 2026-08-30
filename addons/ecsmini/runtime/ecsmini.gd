class_name ECSmini
extends RefCounted

## Stateless convenience entry point for creating ECSmini runtime objects.[br][br]
## [codeblock]
## var world := ECSmini.create_world()
## var player := world.create_entity()
## world.add_component(player, &"health", 100)
## [/codeblock]
##
## @tutorial(GDScript documentation comments): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html

## Runtime version exposed to scripts for diagnostics or compatibility checks.
const VERSION := "0.1.0"

## Creates an empty [EcsWorld]. The world is not attached to a [Node]; call
## [method EcsWorld.tick] manually or assign it to an [EcsRunner]-based workflow.
static func create_world() -> EcsWorld:
	return EcsWorld.new()
