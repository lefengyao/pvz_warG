class_name EcsTransformSyncSystem
extends EcsSystem

## Optional Godot 2D presentation adapter. Copies ECS transform components to the
## [Node2D] instances explicitly bound through [EcsNodeSync]. ECS remains authoritative.[br][br]
## [codeblock]
## var sync := EcsNodeSync.new(world)
## sync.bind(entity, $Player)
## world.add_system(EcsTransformSyncSystem.new(sync))
## [/codeblock]
##
## @tutorial(Node2D): https://docs.godotengine.org/en/stable/classes/class_node2d.html

## Component key for the [Vector2] copied to [member Node2D.position].
const POSITION: StringName = &"position"
## Optional component key for the [float] copied to [member Node2D.rotation].
const ROTATION: StringName = &"rotation"
## Optional component key for the [Vector2] copied to [member Node2D.scale].
const SCALE: StringName = &"scale"

## Binding table used to find the visual [Node2D] for an ECS entity.
var sync: EcsNodeSync


## Creates the adapter for [param node_sync] and schedules it late at priority 1000,
## after gameplay systems have finished updating ECS state.
func _init(node_sync: EcsNodeSync) -> void:
	sync = node_sync
	priority = 1000


## Copies [code]position[/code] for every bound entity; also copies [code]rotation[/code]
## and [code]scale[/code] when those optional components exist. Unbound entities are skipped.
func on_update(world: EcsWorld, _delta: float) -> void:
	for entity_id in world.query({"all": [POSITION]}).entities():
		var node := sync.get_node(entity_id)
		if node == null:
			continue
		node.position = world.get_component(entity_id, POSITION, Vector2.ZERO)
		if world.has_component(entity_id, ROTATION):
			node.rotation = world.get_component(entity_id, ROTATION, 0.0)
		if world.has_component(entity_id, SCALE):
			node.scale = world.get_component(entity_id, SCALE, Vector2.ONE)
