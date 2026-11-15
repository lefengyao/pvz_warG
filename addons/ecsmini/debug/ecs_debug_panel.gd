class_name EcsDebugPanel
extends PanelContainer

const DEBUG_CONTROLS = preload("res://addons/ecsmini/debug/ecs_debug_controls.gd")

## Optional runtime inspector for one ECS world. Add to a CanvasLayer or another UI
## parent, then assign runner_path or call set_world(). Does not listen for global input.
## The panel keeps a weak world reference and never enables profiling automatically.

## Optional path to an EcsRunner, resolved when the panel enters the scene tree.
@export var runner_path: NodePath
## Seconds between visible-panel refreshes. Call refresh_now() for an immediate update.
@export_range(0.05, 10.0, 0.05) var refresh_interval: float = 0.25:
	set(value):
		refresh_interval = maxf(0.05, value)
## Maximum entity rows to preview; summary counts always cover the whole world.
@export_range(0, 100000, 1) var max_entities: int = 100:
	set(value):
		max_entities = maxi(0, value)
## Recent trace rows shown; the World's trace_capacity independently bounds storage.
@export_range(0, 1000, 1) var max_trace_entries: int = 20:
	set(value):
		max_trace_entries = maxi(0, value)

var _world_ref: WeakRef
var _world_attached: bool = false
var _elapsed: float = 0.0
var _selected_entity: int = -1
var _world_status: Label
var _world_metrics: Label
var _component_counts: Label
var _entity_preview: Label
var _entity_list: ItemList
var _component_values: RichTextLabel
var _system_list: Tree
var _timing_status: Label
var _controls: EcsDebugControls
var _mutation_trace: RichTextLabel


func _ready() -> void:
	_build_ui()
	if not runner_path.is_empty():
		var runner := get_node_or_null(runner_path) as EcsRunner
		if runner != null:
			set_runner(runner)
	refresh_now()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _elapsed >= refresh_interval:
		_elapsed = 0.0
		refresh_now()


## Attaches or switches worlds. Null explicitly detaches and clears selection.
func set_world(world: EcsWorld) -> void:
	_build_ui()
	_world_ref = weakref(world) if world != null else null
	_world_attached = world != null
	_selected_entity = -1
	_controls.set_world(world)
	if is_node_ready():
		refresh_now()


## Runner binding enables pause/resume; direct World binding provides manual steps.
func set_runner(runner: EcsRunner) -> void:
	set_world(runner.world if runner != null else null)
	_controls.set_runner(runner)
	if is_node_ready():
		refresh_now()


## Returns the currently attached world, or null when it has been freed or detached.
func get_world() -> EcsWorld:
	return _world_ref.get_ref() as EcsWorld if _world_ref != null else null


## Refreshes summaries, capped entity rows, component values, and system timing rows.
func refresh_now() -> void:
	_build_ui()
	var world := get_world()
	if world == null:
		_show_unavailable("World unavailable" if _world_attached else "No world attached")
		return
	if world.is_disposed():
		_show_unavailable("World disposed")
		return
	var snapshot: Dictionary = world.get_debug_snapshot(max_entities)
	_controls.refresh_now()
	_world_status.text = "World active"
	_world_metrics.text = "Entities: %d   Queries: %d   Pending commands: %d" % [
		snapshot.get("entity_count", 0), snapshot.get("query_count", 0), snapshot.get("pending_command_count", 0)]
	var counts: Dictionary = snapshot.get("component_counts", {})
	var count_keys := counts.keys()
	count_keys.sort()
	var count_labels := PackedStringArray()
	for key in count_keys:
		count_labels.append("%s: %d" % [key, counts[key]])
	_component_counts.text = "Components: " + (", ".join(count_labels) if not count_labels.is_empty() else "none")
	var entity_rows: Array = snapshot.get("entities", [])
	_entity_preview.text = "Showing %d of %d entities" % [entity_rows.size(), snapshot.get("entity_count", 0)]
	_entity_list.clear()
	var selected_index := -1
	for entity_row in entity_rows:
		var entity_id: int = entity_row.get("id", -1)
		var index := _entity_list.add_item(str(entity_id))
		_entity_list.set_item_metadata(index, entity_id)
		if entity_id == _selected_entity:
			selected_index = index
	if selected_index >= 0:
		_entity_list.select(selected_index)
		_show_components(world.get_entity_components(_selected_entity))
	else:
		_selected_entity = -1
		_component_values.text = "Select an entity to view component values."
	_show_systems(snapshot.get("systems", []))
	_timing_status.text = "Last tick: %d us" % snapshot.get("last_tick_usec", 0) if world.profiling_enabled else "Timings disabled (enable world.profiling_enabled)"
	_show_trace(world)


## Selects an entity from the current capped preview. Returns false when it is absent.
func select_entity(entity_id: int) -> bool:
	refresh_now()
	for index in range(_entity_list.item_count):
		if int(_entity_list.get_item_metadata(index)) == entity_id:
			_entity_list.select(index)
			_on_entity_selected(index)
			return true
	return false


func _on_entity_selected(index: int) -> void:
	_selected_entity = int(_entity_list.get_item_metadata(index))
	var world := get_world()
	if world != null and not world.is_disposed():
		_show_components(world.get_entity_components(_selected_entity))


func _show_components(components: Dictionary) -> void:
	var keys := components.keys()
	keys.sort()
	var lines := PackedStringArray(["Entity %d" % _selected_entity])
	for key in keys:
		var value_text := var_to_str(components[key])
		if value_text.length() > 2048:
			value_text = value_text.substr(0, 2048) + "... (preview truncated)"
		lines.append("\n%s\n%s" % [key, value_text])
	if keys.is_empty():
		lines.append("\nNo components.")
	_component_values.text = "\n".join(lines)


func _show_systems(systems: Array) -> void:
	_system_list.clear()
	var root_row := _system_list.create_item()
	for system in systems:
		var row := _system_list.create_item(root_row)
		row.set_text(0, str(system.get("name", "EcsSystem")))
		row.set_tooltip_text(0, row.get_text(0))
		row.set_text(1, "Yes" if system.get("enabled", true) else "No")
		row.set_text(2, str(system.get("priority", 0)))
		var phase := int(system.get("phase", EcsSystem.Phase.SIMULATION))
		row.set_text(3, "Presentation" if phase == EcsSystem.Phase.PRESENTATION else "Simulation")
		row.set_text(4, str(system.get("last_update_usec", 0)))


func _show_unavailable(status: String) -> void:
	_controls.refresh_now()
	_world_status.text = status
	_world_metrics.text = "Entities: 0   Queries: 0   Pending commands: 0"
	_component_counts.text = "Components: none"
	_entity_preview.text = "Showing 0 entities"
	_entity_list.clear()
	_selected_entity = -1
	_component_values.text = "Select an entity to view component values."
	_show_systems([])
	_timing_status.text = "No timing data"
	_mutation_trace.text = "No mutation trace available."


func _show_trace(world: EcsWorld) -> void:
	var entries: Array[Dictionary] = world.get_trace()
	var lines := PackedStringArray()
	for index in range(maxi(0, entries.size() - max_trace_entries), entries.size()):
		var entry: Dictionary = entries[index]
		lines.append("#%d %s UID %d %s [%s]" % [entry.get("sequence", 0), entry.get("op", ""),
			entry.get("uid", 0), entry.get("key", ""), entry.get("system", "external")])
	_mutation_trace.text = "\n".join(lines) if not lines.is_empty() else ("No recent mutations." if world.trace_enabled else "Trace disabled (enable Mutation trace above)")


func _build_ui() -> void:
	if _world_status != null:
		return
	custom_minimum_size = Vector2(560, 480)
	var diagnostics_margin := MarginContainer.new()
	diagnostics_margin.name = "DiagnosticsMargin"
	for edge in ["left", "right", "top", "bottom"]:
		diagnostics_margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(diagnostics_margin)
	var diagnostics_layout := VBoxContainer.new()
	diagnostics_layout.name = "DiagnosticsLayout"
	diagnostics_layout.add_theme_constant_override("separation", 10)
	diagnostics_margin.add_child(diagnostics_layout)
	var world_module := _create_module(diagnostics_layout, "WorldSummaryModule", "ECSmini World")
	_world_status = _create_label(world_module, "WorldStatus", "No world attached")
	_world_metrics = _create_label(world_module, "WorldMetrics", "")
	_component_counts = _create_label(world_module, "ComponentCounts", "")
	_component_counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls = DEBUG_CONTROLS.new()
	_controls.stepped.connect(refresh_now)
	_controls.trace_changed.connect(refresh_now)
	diagnostics_layout.add_child(_controls)
	var entity_module := _create_module(diagnostics_layout, "EntityModule", "Entities and Components")
	entity_module.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entity_preview = _create_label(entity_module, "EntityPreview", "")
	var entity_layout := HBoxContainer.new()
	entity_layout.name = "EntityDetailsLayout"
	entity_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entity_module.add_child(entity_layout)
	_entity_list = ItemList.new()
	_entity_list.name = "EntityList"
	_entity_list.custom_minimum_size = Vector2(150, 140)
	_entity_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entity_list.item_selected.connect(_on_entity_selected)
	entity_layout.add_child(_entity_list)
	_component_values = RichTextLabel.new()
	_component_values.name = "ComponentValues"
	_component_values.custom_minimum_size = Vector2(260, 140)
	_component_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_component_values.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_component_values.selection_enabled = true
	entity_layout.add_child(_component_values)
	var system_module := _create_module(diagnostics_layout, "SystemModule", "System Schedule")
	_system_list = Tree.new()
	_system_list.name = "SystemList"
	_system_list.custom_minimum_size.y = 110
	_system_list.columns = 5
	_system_list.hide_root = true
	_system_list.column_titles_visible = true
	var titles := PackedStringArray(["System", "Enabled", "Priority", "Phase", "Last us"])
	for index in range(titles.size()):
		_system_list.set_column_title(index, titles[index])
		_system_list.set_column_expand(index, index == 0 or index == 3)
		_system_list.set_column_custom_minimum_width(index, 70 if index > 0 else 150)
	system_module.add_child(_system_list)
	_timing_status = _create_label(system_module, "TimingStatus", "")
	var trace_module := _create_module(diagnostics_layout, "MutationTraceModule", "Recent Mutations")
	_mutation_trace = RichTextLabel.new()
	_mutation_trace.name = "MutationTrace"
	_mutation_trace.custom_minimum_size.y = 90
	_mutation_trace.selection_enabled = true
	trace_module.add_child(_mutation_trace)


func _create_module(parent: Node, module_name: String, title: String) -> VBoxContainer:
	var module := VBoxContainer.new()
	module.name = module_name
	parent.add_child(module)
	_create_label(module, "SectionHeader", title)
	return module


func _create_label(parent: Node, node_name: String, text_value: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	parent.add_child(label)
	return label
