extends SceneTree

const MODULES := {
	"template": "res://addons/ecsmini/runtime/extensions/ecs_entity_template.gd",
	"events": "res://addons/ecsmini/runtime/extensions/ecs_event_queue.gd",
	"relations": "res://addons/ecsmini/runtime/extensions/ecs_relations.gd",
	"groups": "res://addons/ecsmini/runtime/extensions/ecs_group_index.gd",
	"spatial": "res://addons/ecsmini/runtime/extensions/ecs_spatial_index.gd",
}
var _checks := 0
var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for module: String in MODULES:
		_check(ResourceLoader.exists(MODULES[module]), "Missing extension module: " + module)
	if _failures == 0:
		_test_templates()
		_test_events()
		_test_relations()
		_test_indexes()
		_test_template_edge_cases()
		_test_event_edge_cases()
		_test_relation_edge_cases()
		_test_index_restore_and_extremes()
		_test_ownership()
	print("extension_checks=", _checks, " failures=", _failures)
	quit(1 if _failures > 0 else 0)

func _test_templates() -> void:
	var template_script: Script = load(MODULES.template)
	var base: Variant = template_script.new()
	base.components = {&"health": 100, &"inventory": {"items": [1, 2]}}
	var template: Variant = template_script.new()
	template.base_template = base
	template.components = {&"health": 120, &"position": Vector2.ZERO}
	var world := EcsWorld.new()
	var first: int = template.spawn(world, {&"health": 150})
	var second: int = template.spawn(world)
	_check(world.get_component(first, &"health") == 150 and world.get_component(second, &"health") == 120, "Template inheritance and overrides")
	world.get_component(first, &"inventory").items.append(3)
	_check(world.get_component(second, &"inventory").items == [1, 2] and base.components[&"inventory"].items == [1, 2], "Template nested values are isolated")
	var path := "user://ecsmini_template_test.tres"
	_check(ResourceSaver.save(template, path) == OK, "Template saves as Resource")
	var saved: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(saved != null and saved.spawn(world) > 0, "Template Resource reload spawns")
	DirAccess.remove_absolute(path)
	var before := world.entity_count()
	_check(template.spawn_many(world, 3, [{&"health": 1}, {&"health": 2}, {&"health": 3}]).size() == 3, "Batch per-instance overrides")
	world.validation_enabled = true
	world.register_component(&"health", TYPE_INT)
	before = world.entity_count()
	_check(template.spawn_many(world, 2, [{&"health": 1}, {&"health": "invalid"}]).is_empty() and world.entity_count() == before, "Invalid batch validates before changing world")
	template.base_template = template
	_check(template.spawn(world) == -1 and world.entity_count() == before, "Template inheritance cycle rejects spawn")
	template.base_template = null
	world.dispose()

func _test_events() -> void:
	var queue: Variant = load(MODULES.events).new(2)
	var payload := {"values": [1]}
	_check(queue.emit_event(&"hit", payload), "Queue accepts staged event")
	payload.values.append(2)
	_check(queue.read(&"one").events.is_empty(), "Staged events stay hidden")
	queue.advance()
	var one: Dictionary = queue.read(&"one")
	_check(one.events.size() == 1 and one.events[0].payload.values == [1], "Commit event isolates original payload")
	one.events[0].payload.values.append(3)
	_check(queue.read(&"two").events[0].payload.values == [1], "Independent readers and read isolation")
	_check(queue.read(&"one").events.is_empty(), "Each reader consumes once")
	queue.emit_event(&"miss", 1)
	queue.emit_event(&"hit", 2)
	queue.commit_stage()
	var filtered: Dictionary = queue.read(&"filter", &"hit")
	_check(filtered.events.size() == 1 and filtered.events[0].payload == 2, "Reader event filter")
	queue.emit_event(&"hit", 3)
	queue.advance()
	var overflow: Dictionary = queue.read(&"one")
	_check(overflow.overflow and overflow.missed == 1 and overflow.events.size() == 2, "Bounded queue explicitly reports lost committed events")
	var state: Dictionary = queue.capture()
	var restored: Variant = load(MODULES.events).new()
	_check(restored.restore(state) and restored.capture() == state, "Queue state restoration preserves cursors and stages")
	queue.clear()
	_check(queue.read(&"one").reset, "Clear reports reset to existing reader")
	_check(not queue.read(&"one").reset, "Reset consumed once")
	queue = null
	restored = null

func _test_relations() -> void:
	var world := EcsWorld.new()
	if not world.has_method("get_relations"):
		_check(false, "World relation hook is required")
		return
	var relations: Variant = world.call("get_relations")
	var owner := world.create_entity()
	var child := world.create_entity()
	var guard := world.create_entity()
	_check(relations.add(child, &"parent", owner, 1), "Create cascading relation")
	_check(relations.add(guard, &"protect", owner, 2), "Create restrictive relation")
	_check(relations.get_targets(child, &"parent") == [owner] and relations.get_sources(owner, &"parent") == [child], "Inverse relation lookup")
	_check(not world.destroy_entity(owner), "Restrict blocks target destruction")
	_check(relations.remove(guard, &"protect", owner), "Remove relation")
	var state: Dictionary = relations.capture()
	_check(relations.restore(state), "Relations restore by persistent UID")
	_check(world.destroy_entity(owner), "Remove restriction permits target destruction")
	world.flush()
	_check(not world.is_entity_alive(child) and relations.query(&"parent").is_empty(), "Target destruction cascades source and cleans inverse links")
	var target := world.create_entity()
	_check(relations.set_targets(guard, &"target", [target]) and relations.query(&"target", target) == [guard], "Set and query relation")
	world.clear()
	_check(relations.capture().links.is_empty(), "Clear forces restrictive relation cleanup")
	world.dispose()

func _test_indexes() -> void:
	var world := EcsWorld.new()
	if not world.has_signal("mutation_committed"):
		_check(false, "Committed mutation signal is required")
		return
	var groups: Variant = load(MODULES.groups).new(world, &"row")
	var spatial: Variant = load(MODULES.spatial).new(world, &"position", 10.0)
	var first := world.create_entity()
	var second := world.create_entity()
	world.add_component(first, &"row", 1)
	world.add_component(second, &"row", 1)
	world.add_component(first, &"position", Vector2(9, 0))
	world.add_component(second, &"position", Vector2(11, 0))
	_check(groups.entities(1) == [first, second], "Group cache updates on committed adds")
	_check(spatial.radius(Vector2(10, 0), 1.0) == [first, second], "Radius crosses bucket boundary and uses exact inclusive distance")
	_check(spatial.nearest(Vector2(10, 0), 1) == [first], "Nearest distance ties use deterministic entity IDs")
	world.set_component(first, &"row", 2)
	world.set_component(first, &"position", Vector2(-11, 0))
	_check(groups.entities(1) == [second] and groups.entities(2) == [first], "Group changes invalidate previous membership")
	_check(spatial.radius(Vector2(-10, 0), 1.0) == [first] and spatial.radius(Vector2(10, 0), 1.0) == [second], "Spatial movement crosses positive and negative buckets")
	world.query().for_each(func(entity: int) -> void:
		world.destroy_entity(entity)
		_check(not groups.entities(world.get_component(entity, &"row")).has(entity) and not spatial.radius(world.get_component(entity, &"position"), 1).has(entity), "Indexes exclude pending destruction")
	)
	var third := world.create_entity()
	world.add_component(third, &"position", Vector3(0, 0, 5))
	_check(spatial.radius(Vector3(0, 0, 4), 1).has(third) and spatial.radius(Vector2.ZERO, 100).is_empty(), "Spatial indexes separate 2D and 3D values")
	world.clear()
	_check(groups.values().is_empty() and spatial.nearest(Vector3.ZERO, 10).is_empty(), "Clear removes all cached entries")
	groups.detach()
	spatial.detach()
	world.dispose()

func _test_ownership() -> void:
	var world: EcsWorld = EcsWorld.new()
	var reference := weakref(world)
	var groups: Variant = load(MODULES.groups).new(world, &"row")
	var spatial: Variant = load(MODULES.spatial).new(world)
	var relations: Variant = load(MODULES.relations).new(world)
	world = null
	_check(reference.get_ref() == null, "Extensions do not own their world")
	_check(groups.entities(1).is_empty() and spatial.nearest(Vector2.ZERO).is_empty() and relations.query(&"x").is_empty(), "Retained extensions handle freed world")
	groups.detach()
	spatial.detach()
	relations.detach()

func _test_template_edge_cases() -> void:
	var world := EcsWorld.new()
	var template: Variant = load(MODULES.template).new()
	var typed_values: Dictionary[StringName, Array] = {&"items": [1, 2]}
	var gradient := Gradient.new()
	template.components = {&"typed": typed_values, &"resource": gradient}
	var first: int = template.spawn(world)
	var second: int = template.spawn(world)
	_check(world.get_component(first, &"typed").is_typed(), "Template copy preserves typed Dictionary metadata")
	world.get_component(first, &"resource").set_color(0, Color.RED)
	_check(world.get_component(second, &"resource").get_color(0) != Color.RED and gradient.get_color(0) != Color.RED, "Template Resource subvalues are isolated")
	var cyclic: Array = []
	cyclic.append(cyclic)
	_check(template.spawn(world, {&"bad": cyclic}) == -1, "Cyclic component container rejected")
	cyclic.clear()
	_check(template.spawn_many(world, -1).is_empty() and not template.last_error.is_empty(), "Negative template batch rejected")
	_check(template.spawn_many(world, 2, [{}]).is_empty(), "Mismatched override batch rejected")
	var calls: Array[int] = [0]
	world.validation_enabled = true
	world.register_component(&"health", TYPE_INT, func(_value: Variant) -> bool:
		calls[0] += 1
		return calls[0] < 4
	)
	template.components = {&"health": 100}
	var before := world.entity_count()
	_check(template.spawn_many(world, 2).is_empty() and world.entity_count() == before, "Unexpected write rejection rolls back all template batch entities")
	world.dispose()
	_check(template.spawn(world) == -1, "Disposed world rejects template spawn")
	world = EcsWorld.new()
	world.validation_enabled = true
	var validation_mutations: Array[int] = []
	world.register_component(&"health", TYPE_INT, func(_value: Variant) -> bool:
		validation_mutations.append(world.create_entity())
		return true
	)
	var entity: int = template.spawn(world)
	_check(entity > 0 and validation_mutations == [-1, -1] and world.entity_count() == 1, "Template schema validation cannot reenter world mutation")
	world.dispose()

func _test_event_edge_cases() -> void:
	var queue: Variant = load(MODULES.events).new(1)
	_check(queue.emit_event(&"a", 1) and not queue.emit_event(&"b", 2) and not queue.last_error.is_empty(), "Staged queue overflow explicitly rejects event")
	var state: Dictionary = queue.capture()
	state.readers[&"bad"] = {"cursor": 1, "epoch": state.reset_epoch}
	_check(not queue.validate_snapshot(state), "Event snapshot rejects readers advanced past committed events")
	state = queue.capture()
	state.capacity = 0
	_check(not queue.restore(state) and queue.capture().capacity == 1, "Malformed queue restore leaves previous state unchanged")
	queue.advance()
	var events: Dictionary = queue.read(&"reader")
	_check(events.events.size() == 1 and not events.overflow, "Rejected staged event does not skip sequences")
	_check(queue.forget_reader(&"reader") and queue.read(&"reader").events.size() == 1, "Forgetting reader restarts retained history")
	_check(not queue.emit_event(&"", null) and not queue.emit_event(&"object", RefCounted.new()), "Invalid keys and live objects rejected")
	queue.clear()
	_check(queue.emit_event(&"new", 3), "New events accepted after clear")
	queue.advance()
	var reset: Dictionary = queue.read(&"reader")
	_check(reset.reset and not reset.overflow and reset.events[0].payload == 3, "Queue reset separates old cursor from new event sequences")

func _test_relation_edge_cases() -> void:
	var world := EcsWorld.new()
	var relations: Variant = world.get_relations()
	var first := world.create_entity()
	var second := world.create_entity()
	_check(relations.add(first, &"cycle", second, relations.DESTROY_SOURCE) and relations.add(second, &"cycle", first, relations.DESTROY_SOURCE), "Cascade cycle links created")
	_check(world.destroy_entity(first) and not world.is_entity_alive(second), "Cascade cycles terminate safely")
	first = world.create_entity()
	second = world.create_entity()
	var third := world.create_entity()
	relations.add(first, &"links", second)
	_check(not relations.set_targets(first, &"links", [third, -1]) and relations.get_targets(first, &"links") == [second], "Invalid target replacement preserves old links")
	_check(not relations.add(first, &"links", second), "Duplicate links rejected")
	var saved: Dictionary = relations.capture()
	var invalid: Dictionary = saved.duplicate(true)
	invalid.links[0].target_uid = 99999999
	_check(not relations.restore(invalid) and relations.capture() == saved, "Unknown relationship UID rejects atomic restore")
	invalid = saved.duplicate(true)
	invalid.links.append(invalid.links[0].duplicate())
	_check(not relations.validate_snapshot(invalid), "Duplicate relationship snapshot records rejected")
	relations.set_targets(first, &"links", [second, third])
	world.destroy_entity(first)
	_check(relations.get_sources(second).is_empty() and relations.get_sources(third).is_empty(), "Source destruction cleans every inverse link")
	relations.add(second, &"restrict", third, relations.RESTRICT)
	world.clear()
	_check(world.entity_count() == 0 and relations.capture().links.is_empty(), "World clear overrides restrictions")
	world.dispose()

func _test_index_restore_and_extremes() -> void:
	var world := EcsWorld.new()
	var groups: Variant = load(MODULES.groups).new(world, &"data")
	var spatial: Variant = load(MODULES.spatial).new(world, &"position", 10.0)
	var first := world.create_entity()
	world.add_component(first, &"data", {"row": 1})
	world.add_component(first, &"position", Vector2.ZERO)
	_check(groups.entities({"row": 1}) == [first], "Dictionary component values can be grouping keys")
	world.get_component(first, &"data").row = 2
	_check(groups.entities({"row": 1}) == [first], "Mutable group value does not corrupt indexed key before touch")
	world.mark_component_changed(first, &"data")
	_check(groups.entities({"row": 1}).is_empty() and groups.entities({"row": 2}) == [first], "Explicit touch updates mutable grouping value")
	var snapshot := EcsSnapshot.capture(world)
	_check(snapshot.ok, "Index restoration source snapshot captures")
	world.set_component(first, &"data", {"row": 3})
	var restored := EcsSnapshot.restore(world, snapshot.snapshot)
	var restored_id: int = restored.id_map.get(first, -1)
	_check(restored.ok and restored_id != first and groups.entities({"row": 2}) == [restored_id] and spatial.radius(Vector2.ZERO, 0) == [restored_id], "Restored signal rebuilds indexes with fresh generation IDs")
	world.set_component(restored_id, &"position", Vector2(1e20, 0))
	_check(spatial.radius(Vector2(1e20, 0), 0) == [restored_id], "Finite extreme positions retain exact spatial lookup")
	world.set_component(restored_id, &"position", Vector2.ZERO)
	_check(spatial.radius(Vector2(1e20, 0), 1e30) == [restored_id], "Huge finite spatial radius avoids overflowing buckets and distances")
	_check(spatial.radius(Vector2.ZERO, -1).is_empty() and spatial.radius(Vector2(NAN, 0), 1).is_empty(), "Invalid radius inputs rejected")
	world.remove_component(restored_id, &"position")
	world.remove_component(restored_id, &"data")
	_check(groups.values().is_empty() and spatial.nearest(Vector2.ZERO).is_empty(), "Committed removals clear indexes")
	groups.detach()
	spatial.detach()
	world.dispose()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)
