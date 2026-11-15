extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_binding_lifetime_2d()
	_test_world_ownership_2d()
	_test_restore_bindings(false)
	_test_restore_bindings(true)
	_test_movement_and_transform_2d()
	_test_3d_adapters()
	_test_example_scenes()
	print("ECS adapter checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures else 0)


func _require(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _test_binding_lifetime_2d() -> void:
	var world := EcsWorld.new()
	var sync := EcsNodeSync.new(world)
	var first := world.create_entity()
	var second := world.create_entity()
	var first_node := Node2D.new()
	var second_node := Node2D.new()
	_require(sync.bind(first, first_node), "2D binding accepts a live entity and node")
	_require(sync.bind(second, first_node), "2D node can be rebound")
	_require(sync.get_node(first) == null, "2D node maps to only one entity")
	_require(sync.bind(second, second_node), "2D entity can be rebound")
	_require(sync.get_entity(first_node) == -1, "2D entity maps to only one node")
	world.destroy_entity(second)
	_require(sync.get_node(second) == null, "2D entity destruction clears mapping")
	_require(is_instance_valid(second_node), "2D binding never owns the visual node")
	first_node.free()
	second_node.free()
	var freed_lookup := Node2D.new()
	sync.bind(first, freed_lookup)
	freed_lookup.free()
	_require(sync.get_node(first) == null, "2D freed node lookup returns null safely")
	var freed_unbind := Node2D.new()
	sync.bind(first, freed_unbind)
	freed_unbind.free()
	sync.unbind(first)
	_require(sync.get_node(first) == null, "2D unbind works after node is freed")
	sync.attach_world(null)
	_require(not world.entity_destroyed.is_connected(sync._on_entity_destroyed), "2D detach disconnects destruction signal")


func _test_world_ownership_2d() -> void:
	var world := EcsWorld.new()
	var world_ref := weakref(world)
	var sync := EcsNodeSync.new(world)
	var entity := world.create_entity()
	var node := Node2D.new()
	sync.bind(entity, node)
	world = null
	_require(world_ref.get_ref() == null, "2D adapter must not keep an abandoned world alive")
	_require(sync.get_node(entity) == null, "2D abandoned world invalidates bindings")
	node.free()
	var disposed_world := EcsWorld.new()
	sync.attach_world(disposed_world)
	var disposed_entity := disposed_world.create_entity()
	var disposed_node := Node2D.new()
	sync.bind(disposed_entity, disposed_node)
	_require(disposed_world.has_method("dispose"), "World exposes disposal")
	if disposed_world.has_method("dispose"):
		disposed_world.call("dispose")
		_require(sync.get_node(disposed_entity) == null, "2D disposal clears mapping")
		_require(not disposed_world.entity_destroyed.is_connected(sync._on_entity_destroyed), "2D disposal detaches adapter")
		_require(not sync.bind(disposed_entity, disposed_node), "2D disposed world rejects bindings")
	disposed_node.free()
	sync.attach_world(null)


func _test_restore_bindings(is_3d: bool) -> void:
	var dimension := "3D" if is_3d else "2D"
	var sync_path := "res://addons/ecsmini/integrations/godot_3d/ecs_node_sync_3d.gd" if is_3d else "res://addons/ecsmini/integrations/godot_2d/ecs_node_sync.gd"
	var sync_script: Script = load(sync_path)
	var snapshot_script: Script = load("res://addons/ecsmini/runtime/persistence/ecs_snapshot.gd")
	var source_world := EcsWorld.new()
	source_world.create_entity()
	var snapshot_entity := source_world.create_entity(7001)
	var captured: Dictionary = snapshot_script.capture(source_world)
	_require(captured.ok, dimension + " binding restore fixture captures a snapshot")
	var world := EcsWorld.new()
	var sync: RefCounted = sync_script.new(world)
	var bound_entity := world.create_entity(7001)
	var absent_entity := world.create_entity()
	var bound_node: Node = Node3D.new() if is_3d else Node2D.new()
	var absent_node: Node = Node3D.new() if is_3d else Node2D.new()
	_require(snapshot_entity != bound_entity, dimension + " fixture uses different handles for the same persistent UID")
	_require(sync.call("bind", bound_entity, bound_node), dimension + " persistent entity binds before restore")
	_require(sync.call("bind", absent_entity, absent_node), dimension + " transient entity binds before restore")
	if captured.ok:
		var restored: Dictionary = snapshot_script.restore(world, captured.snapshot)
		_require(restored.ok, dimension + " adapter world restores the snapshot")
		if restored.ok:
			var restored_entity := world.get_entity_by_uid(7001)
			_require(restored_entity == restored.id_map[snapshot_entity], dimension + " restored UID resolves to the snapshot entity")
			_require(restored_entity != bound_entity and not world.is_entity_alive(bound_entity), dimension + " restore invalidates the previous handle")
			_require(sync.call("get_node", restored_entity) == bound_node, dimension + " restore rebinds the existing node by persistent UID")
			_require(sync.call("get_entity", bound_node) == restored_entity, dimension + " restore updates the reverse node mapping")
			_require(sync.call("get_node", bound_entity) == null, dimension + " restore drops the old entity mapping")
			_require(sync.call("get_entity", absent_node) == -1 and sync.call("get_node", absent_entity) == null, dimension + " restore unbinds an entity absent from the snapshot")
			_require(is_instance_valid(bound_node) and is_instance_valid(absent_node), dimension + " restore leaves both visual nodes alive")
			var repeated: Dictionary = snapshot_script.restore(world, captured.snapshot)
			_require(repeated.ok, dimension + " repeated restore succeeds")
			if repeated.ok:
				var repeated_entity := world.get_entity_by_uid(7001)
				_require(repeated_entity != restored_entity and sync.call("get_node", repeated_entity) == bound_node and sync.call("get_entity", bound_node) == repeated_entity, dimension + " repeated restore advances the handle and preserves both mapping directions")
	world.dispose()
	source_world.dispose()
	bound_node.free()
	absent_node.free()


func _test_movement_and_transform_2d() -> void:
	var world := EcsWorld.new()
	var sync := EcsNodeSync.new(world)
	var entity := world.create_entity()
	var parent_node := Node2D.new()
	parent_node.position = Vector2(100.0, 50.0)
	parent_node.rotation = 0.25
	parent_node.scale = Vector2(1.5, 1.5)
	root.add_child(parent_node)
	var node := Node2D.new()
	parent_node.add_child(node)
	sync.bind(entity, node)
	world.add_component(entity, &"position", Vector2(4.0, 6.0))
	world.add_component(entity, &"velocity", Vector2(8.0, -4.0))
	world.add_component(entity, &"rotation", 0.5)
	world.add_component(entity, &"scale", Vector2(2.0, 3.0))
	var transform_system := EcsTransformSyncSystem.new(sync)
	world.add_system(transform_system)
	world.add_system(EcsMovementSystem.new())
	world.tick(0.5)
	_require(node.position.is_equal_approx(Vector2(8.0, 4.0)), "2D movement precedes presentation and uses local position")
	_require(is_equal_approx(node.rotation, 0.5), "2D sync applies rotation")
	_require(node.scale.is_equal_approx(Vector2(2.0, 3.0)), "2D sync applies scale")
	var has_global_option: bool = "use_global_transform" in transform_system
	_require(has_global_option, "2D sync offers explicit global coordinate mode")
	if has_global_option:
		transform_system.set("use_global_transform", true)
		world.tick(0.0)
		_require(node.global_position.is_equal_approx(Vector2(8.0, 4.0)), "2D global coordinate mode ignores parent position")
		_require(is_equal_approx(node.global_rotation, 0.5), "2D global rotation ignores parent rotation")
		_require(node.global_scale.is_equal_approx(Vector2(2.0, 3.0)), "2D global scale ignores parent scale")
	world.set_component(entity, &"velocity", "invalid")
	world.tick(1.0)
	_require(world.get_component(entity, &"position") == Vector2(8.0, 4.0), "2D movement ignores invalid vector component")
	world.set_component(entity, &"position", "invalid")
	world.tick(0.0)
	_require(node.global_position.is_equal_approx(Vector2(8.0, 4.0)) if has_global_option else node.position.is_equal_approx(Vector2(8.0, 4.0)), "2D presentation ignores invalid vector component")
	if world.has_method("dispose"):
		world.call("dispose")
	sync.attach_world(null)
	parent_node.free()


func _test_3d_adapters() -> void:
	var paths := [
		"res://addons/ecsmini/integrations/godot_3d/ecs_node_sync_3d.gd",
		"res://addons/ecsmini/integrations/godot_3d/transform_sync_3d_system.gd",
		"res://addons/ecsmini/systems/3d/movement_3d_system.gd",
	]
	for path in paths:
		_require(ResourceLoader.exists(path), "3D adapter exists: " + path)
		if not ResourceLoader.exists(path):
			return
	var sync_script: Script = load(paths[0])
	var transform_script: Script = load(paths[1])
	var movement_script: Script = load(paths[2])
	var world := EcsWorld.new()
	var sync: RefCounted = sync_script.new(world)
	var entity := world.create_entity()
	var other_entity := world.create_entity()
	var parent_node := Node3D.new()
	parent_node.position = Vector3(10.0, 20.0, 30.0)
	parent_node.rotation = Vector3(0.0, 0.3, 0.0)
	parent_node.scale = Vector3(1.5, 1.5, 1.5)
	root.add_child(parent_node)
	var node := Node3D.new()
	parent_node.add_child(node)
	sync.call("bind", entity, node)
	sync.call("bind", other_entity, node)
	_require(sync.call("get_node", entity) == null, "3D node maps to only one entity")
	sync.call("bind", entity, node)
	_require(sync.call("get_node", other_entity) == null, "3D node rebinding clears former entity")
	world.add_component(entity, &"position3d", Vector3(1.0, 2.0, 3.0))
	world.add_component(entity, &"velocity3d", Vector3(2.0, -2.0, 4.0))
	world.add_component(entity, &"rotation3d", Vector3(0.0, 0.5, 0.0))
	world.add_component(entity, &"scale3d", Vector3(2.0, 3.0, 4.0))
	world.add_component(entity, &"position", Vector2(99.0, 99.0))
	var transform_system: EcsSystem = transform_script.new(sync)
	world.add_system(transform_system)
	world.add_system(movement_script.new())
	world.tick(0.5)
	_require(node.position.is_equal_approx(Vector3(2.0, 1.0, 5.0)), "3D movement and local transform sync")
	_require(node.rotation.is_equal_approx(Vector3(0.0, 0.5, 0.0)), "3D rotation sync")
	_require(node.scale.is_equal_approx(Vector3(2.0, 3.0, 4.0)), "3D scale sync")
	_require(world.get_component(entity, &"position") == Vector2(99.0, 99.0), "3D system keeps 2D components separate")
	transform_system.set("use_global_transform", true)
	parent_node.remove_child(node)
	world.tick(0.0)
	_require(node.position.is_equal_approx(Vector3(2.0, 1.0, 5.0)), "3D global mode skips detached visuals")
	parent_node.add_child(node)
	world.tick(0.0)
	_require(node.global_position.is_equal_approx(Vector3(2.0, 1.0, 5.0)), "3D global position sync")
	_require(node.global_rotation.is_equal_approx(Vector3(0.0, 0.5, 0.0)), "3D global rotation sync")
	_require(node.global_transform.basis.get_scale().is_equal_approx(Vector3(2.0, 3.0, 4.0)), "3D global scale sync")
	var expected_rotation := Vector3(0.35, -0.6, 0.2)
	var expected_scale := Vector3(0.75, 2.0, 1.25)
	var expected_position := Vector3(-7.0, 3.0, 11.0)
	var expected_basis := Basis.from_euler(expected_rotation) * Basis.from_scale(expected_scale)
	world.set_component(entity, &"position3d", expected_position)
	world.set_component(entity, &"rotation3d", expected_rotation)
	world.set_component(entity, &"scale3d", expected_scale)
	parent_node.scale = Vector3(0.5, 2.0, 3.0)
	world.tick(0.0)
	_require(node.global_position.is_equal_approx(expected_position), "3D global position ignores nonuniform parent scale")
	_require(node.global_transform.basis.is_equal_approx(expected_basis), "3D global mode applies the complete expected basis under nonuniform parent scale")
	parent_node.transform = Transform3D(Basis(Vector3(2.0, 0.1, 0.0), Vector3(0.7, 1.5, 0.2), Vector3(0.2, 0.4, 0.75)), Vector3(4.0, -2.0, 8.0))
	world.tick(0.0)
	_require(node.global_position.is_equal_approx(expected_position), "3D global position ignores parent shear")
	_require(node.global_transform.basis.is_equal_approx(expected_basis), "3D global mode applies the complete expected basis under parent shear")
	world.set_component(entity, &"position3d", Vector3(2.0, 1.0, 5.0))
	world.set_component(entity, &"velocity3d", Vector2.ONE)
	world.tick(1.0)
	_require(world.get_component(entity, &"position3d") == Vector3(2.0, 1.0, 5.0), "3D movement ignores non Vector3 velocity")
	world.set_component(entity, &"position3d", Vector2.ZERO)
	world.tick(0.0)
	_require(node.global_position.is_equal_approx(Vector3(2.0, 1.0, 5.0)), "3D sync ignores non Vector3 position")
	node.free()
	_require(sync.call("get_node", entity) == null, "3D freed node lookup is safe")
	var unbound_node := Node3D.new()
	sync.call("bind", entity, unbound_node)
	unbound_node.free()
	sync.call("unbind", entity)
	_require(sync.call("get_node", entity) == null, "3D unbind after node free is safe")
	var alive_node := Node3D.new()
	sync.call("bind", entity, alive_node)
	world.destroy_entity(entity)
	_require(sync.call("get_entity", alive_node) == -1, "3D destruction clears reverse mapping")
	alive_node.free()
	if world.has_method("dispose"):
		var disposed_entity := world.create_entity()
		var disposed_node := Node3D.new()
		sync.call("bind", disposed_entity, disposed_node)
		world.call("dispose")
		_require(sync.call("get_node", disposed_entity) == null, "3D disposal clears mapping")
		_require(sync.call("get_entity", disposed_node) == -1, "3D disposal clears reverse mapping")
		_require(world.entity_destroyed.get_connections().is_empty(), "3D disposal disconnects adapter callbacks")
		disposed_node.free()
	sync.call("attach_world", null)
	parent_node.free()
	var abandoned_world := EcsWorld.new()
	var abandoned_ref := weakref(abandoned_world)
	var abandoned_sync: RefCounted = sync_script.new(abandoned_world)
	var abandoned_entity := abandoned_world.create_entity()
	var abandoned_node := Node3D.new()
	abandoned_sync.call("bind", abandoned_entity, abandoned_node)
	abandoned_world = null
	_require(abandoned_ref.get_ref() == null, "3D adapter does not own world")
	_require(abandoned_sync.call("get_node", abandoned_entity) == null, "3D abandoned world invalidates bindings")
	abandoned_node.free()


func _test_example_scenes() -> void:
	var example_paths: Array[String] = [
		"res://addons/ecsmini/examples/2d/Movement2D.tscn",
		"res://addons/ecsmini/examples/3d/Movement3D.tscn",
	]
	var host_demo_path := "res://3d/scenes/maps/front_yard/EcsFrontYardDemo.tscn"
	if ResourceLoader.exists(host_demo_path):
		example_paths.append(host_demo_path)
	for path in example_paths:
		_require(ResourceLoader.exists(path), "Runnable ECS example exists: " + path)
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path)
		_require(scene != null, "Runnable ECS example loads: " + path)
