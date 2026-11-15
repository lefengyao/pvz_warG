# ECSmini 0.3

Architecture and ownership boundaries: [technical guide](TECHNICAL.md).

ECSmini is a pure-GDScript ECS runtime for Godot 4.7. Entity IDs and component
data live in `EcsWorld`; optional adapters copy transforms to scene nodes. The
editor plugin stays lean, while runtime diagnostics are an explicit UI node.
The runtime does not implement plant, zombie, combat, or level rules.

## Install and run

Copy `addons/ecsmini` into a Godot project. Open the editor once so Godot imports
the scripts and registers their `class_name` declarations. Enable ECSmini under
Project Settings > Plugins if desired; runtime classes do not depend on the
editor plugin being enabled. No autoload or external package is required.

## New core and migration from 0.2

0.3 changes internal storage, query invalidation and scheduling. Use World
mutation methods: direct storage writes bypass generations, validation, indexes
and change tracking. Select storage before creating entities:

```gdscript
var world := ECSmini.create_world(EcsArchetypeStorage.new(256))
# Default: EcsSparseStorage, dense component values with sparse ID lookup.
var movement := EcsMovementSystem.new()
movement.compute_mode = &"parallel" # serial, parallel, auto
world.add_system(movement)
```

Archetype storage groups exact component signatures into bounded chunks and
migrates rows on structural changes. Sparse storage suits frequent shape
changes. Measure complete capture/compute/commit workloads before choosing.

Generation handles remain World-local and ephemeral. Entities also have stable
positive UIDs: `create_entity(uid = 0)`, `get_entity_uid(id)` and
`get_entity_by_uid(uid)`. Snapshots preserve UIDs and generate fresh handles;
2D/3D binding tables remap by UID after restoration. Declare handle components
with `register_reference_component(key)`; other integers remain ordinary data.

- [EXTENSIONS.md](EXTENSIONS.md): inherited Resource templates, staged event
  readers, relation destruction policies, group and spatial indexes.
- [PERSISTENCE.md](PERSISTENCE.md): versioned snapshots, disk migrations, fixed
  tick inputs, checkpoints, rewind and corrected-input rollback.
- [COMPUTE.md](COMPUTE.md): serial and isolated-worker computation, storage tradeoffs.
- [TECHNICAL.md](TECHNICAL.md): runtime architecture, ownership and persistence boundaries.

World, query and extension access belongs to the World's creating thread.
Compute orchestration sends copied packed vectors to workers, joins every task,
then commits on the main thread. Scene nodes remain presentation objects.

```gdscript
var world := ECSmini.create_world()
var entity := world.create_entity()
world.add_component(entity, &"position", Vector2.ZERO)
world.add_component(entity, &"velocity", Vector2(120, 0))
world.add_system(EcsMovementSystem.new())
world.tick(0.5)
assert(world.get_component(entity, &"position") == Vector2(60, 0))
world.dispose()
```

IDs are integers containing a storage slot and generation. Reusing a destroyed
slot does not make an old ID valid again. IDs belong to their creating world;
keep the world with any retained ID and do not use an ID in another world.
Components use application-defined `StringName` keys and arbitrary `Variant`
values. Prefer small values and application-owned component keys.

## Queries and structural changes

```gdscript
var movers := world.query({
    "all": [&"position", &"velocity"],
    "any": [&"enemy", &"player"],
    "none": [&"dead"],
})
for entity_id in movers.entities():
    var position: Vector2 = world.get_component(entity_id, &"position")
    var velocity: Vector2 = world.get_component(entity_id, &"velocity")
    world.set_component(entity_id, &"position", position + velocity * delta)
```

`all` requires every key, `any` requires at least one supplied key, and `none`
excludes every supplied key. Omitted or empty criteria impose no restriction.
Equivalent normalized criteria return the same cached query. `entities()`
returns a copy; changing that array cannot corrupt the query cache. `count()`
avoids copying the entity array when there are no pending destructions.
`refresh_count` helps detect unnecessary query
rebuilds; `candidate_checks` counts evaluated candidates. Incremental refresh
checks only affected entities. Query membership depends on relevant component memberships, while
queries with no positive criteria also depend on entity lifetime. Replacing a
component value does not rebuild membership.

`query.batches(chunk_size)` returns copied aligned columns:
`{"entities": Array[int], "columns": Dictionary}`. Compute against these copies
and commit with `world.write_batch(key, entities, values)`. All rows, duplicate
IDs, memberships and schemas are validated before writing. Rejection leaves
component values unchanged. Validators must be pure; World mutations are
rejected during validation. Arbitrary Objects retain identity in batch snapshots
and must stay out of worker jobs.

`create_change_reader([keys])` enables bounded change tracking and starts an
independent cursor at the current state. `reader.read()` reports `changes`,
`overflow`, `reset`, `missed`, `unavailable`, `sequence` and `epoch`. Rebuild a
consumer from committed state on overflow/reset. Changing `change_capacity`
resets its epoch. This is a bounded journal, not a permanent audit log. Call
`mark_component_changed(id, key)` after editing a retained mutable value in
place so observers and indexes update. Tracking is disabled until a reader is
created unless `change_tracking_enabled` is enabled explicitly.

The world defers component additions, removals, and entity destruction during
system ticks and `query.for_each()` callbacks. Deferred commands apply in FIFO
order after the outer protected operation ends. Their Boolean results indicate
acceptance. Duplicate adds/removes are rejected against projected queued
membership, so a remove followed by an add of the same key is supported.
Reads expose committed component data until the queue is flushed. Setting an
existing, unchanged membership is immediate; writes that depend on queued
membership follow the command sequence. Entity creation returns a live ID
immediately, including inside a callback.

```gdscript
world.query({"all": [&"health"]}).for_each(func(entity_id: int) -> void:
    var health: int = world.get_component(entity_id, &"health")
    if health <= 0:
        world.destroy_entity(entity_id)
)
```

An entity accepted for deferred destruction is pending destruction: later
writes to it are rejected and query iteration skips it. Use
`is_entity_pending_destroy()` to distinguish this state from committed removal.
`flush()` applies commands only at a safe boundary; it cannot force a flush
inside an active tick or query callback. Mutations through a direct
`entities()` loop have no callback guard outside a tick; use `for_each()` when
the operation needs deferred structural changes.

## Systems, scheduling, and scene integration

Subclass `EcsSystem` and override `on_update(world, delta)`. Cache queries in
`configure(world)` if convenient. Systems run in dependency order, using phase,
ascending priority and registration order to resolve available choices.
`SIMULATION` is the default phase;
transform adapters use `PRESENTATION`. Disable a system with
`world.set_system_enabled(system, false)`. World priority/phase setters check
registration; changing system priority or phase directly also invalidates the
schedule through `schedule_changed`. Ordering is rebuilt before the next
execution. `resort_systems()` explicitly rebuilds it. `debug_name` supplies a
readable name in diagnostics. A system instance can belong to only one world.
`configure()` runs on registration, `on_start()`/`on_stop()` follow world
lifecycle, and `on_detach()` releases cached references on removal or disposal.
Removing and re-registering a system during a tick skips its old schedule entry;
the new registration updates on the next tick. Priority changes likewise use
the next rebuilt schedule.

While running, `add_system()` rejects invalid dependencies and registrations
that would place an unstarted system ahead of started systems. Rejection detaches
the registration; `configure()` must keep its work reversible in `on_detach()`.
Stop the World before inserting such a dependency, then restart it. Startup
callbacks may append systems; startup refreshes the schedule between callbacks.
An interrupted startup cannot update an unstarted system or advance simulation
time. Correct its declarations, or stop and restart before resuming.

Give systems unique `schedule_key` names and declare `before` / `after` keys
and `reads` / `writes` component keys. Missing dependencies, duplicate names,
cycles or contradictory phases make `validate_schedule()` false and prevent
ticking; inspect `last_schedule_error`. Conflicting reads/writes serialize
systems. `get_execution_batches()` exposes safe dependency/conflict stages;
ordinary callbacks still run sequentially on the owning thread. Assignments
notify the scheduler immediately; in-place array edits are detected before the
next schedule access. Metadata does not make Node or arbitrary GDScript access
thread safe.

```gdscript
class HealthSystem extends EcsSystem:
    func on_update(world: EcsWorld, _delta: float) -> void:
        world.query({"all": [&"health"]}).for_each(func(entity_id: int) -> void:
            if int(world.get_component(entity_id, &"health")) <= 0:
                world.destroy_entity(entity_id)
        )
```

`EcsRunner` is an optional scene-tree clock. Add one node and register systems
through `runner.add_system()`. With `separate_presentation = false`, its selected
clock runs both phases: `_process()` by default or `_physics_process()` when
`use_physics_process = true`. Changing the clock at runtime updates processing
callbacks. With `separate_presentation = true`, physics runs simulation and
render frames run presentation. `enabled` pauses ticking and `time_scale`
scales the delta passed to systems. The runner does not add transform
interpolation. Assign a different `world` before adding the runner to the tree.
Leaving the tree stops its world; freeing it also disposes the world by default.
Set `dispose_world_on_free = false` when an externally owned world must survive
the runner. The application then owns final disposal.

When paused (`enabled = false`), `runner.step(delta)` advances one simulation
tick and one presentation update. Simulation advances `simulation_tick` /
`simulation_time` and commits staged events at tick start. Presentation does
not advance that clock. The World owns `rng`, initially seeded with 1; replayable
systems must use that generator and store mutable state in components. A replay
driver must exclusively own simulation ticking.

```gdscript
var runner := EcsRunner.new()
runner.separate_presentation = true
runner.add_system(EcsMovement3DSystem.new())
add_child(runner)
var world := runner.world
var sync := EcsNodeSync3D.new(world)
var entity := world.create_entity()
world.add_component(entity, &"position3d", $Actor.position)
world.add_component(entity, &"velocity3d", Vector3(1, 0, 0))
sync.bind(entity, $Actor)
runner.add_system(EcsTransformSync3DSystem.new(sync))
```

2D equivalents are `EcsNodeSync`, `EcsMovementSystem`, and
`EcsTransformSyncSystem`. Movement requires `position` and `velocity` values
of type `Vector2`. The 2D transform adapter copies `position` and optional
`rotation` (`float`) and `scale` (`Vector2`). 3D movement requires `position3d`
and `velocity3d` (`Vector3`). The 3D adapter also copies optional `rotation3d`
(Euler radians) and `scale3d`, both `Vector3`.

Both transform systems expose `use_global_transform = false`. Local transforms
are the default; enable this field when ECS positions and rotations are in
world space. Binding tables enforce one entity to one node, observe entity
destruction and world disposal, and use weak references to worlds and nodes.
Destroying an entity unbinds its node; it does not free the node. Freeing nodes
does not destroy entities. The application owns spawning, node cleanup, and
gameplay input. Call `sync.attach_world(null)` to detach an adapter explicitly.

## Validation and world lifecycle

Component validation is opt-in and disabled by default. Registration describes
a key's Variant type and/or a callable accepting the candidate value. The
validator returns `true` for a valid value. Validation failures reject the
write, update `last_validation_error`, and emit `validation_failed`.
`variant_type = -1` accepts any Variant type; `TYPE_NIL` defines a null-valued
tag. Duplicate schema registration returns `false`. Strict registration is
enforced on writes when both `validation_enabled` and
`require_registered_components` are enabled.

```gdscript
world.validation_enabled = true
world.require_registered_components = true
world.register_component(&"health", TYPE_INT, func(value: Variant) -> bool:
    return int(value) >= 0
)
world.validation_failed.connect(func(entity_id: int, key: StringName, message: String) -> void:
    print("Rejected %s on %d: %s" % [key, entity_id, message])
)
```

Use `start()`/`stop()` for system lifecycle hooks. `tick()` starts automatically.
`clear()` removes entities and queued work while preserving registered systems,
component schemas, and entity generations. Cached query objects remain usable.
Use it to reset a session without rebuilding system configuration.
`dispose()` permanently closes the world, stops and detaches systems, removes
entities, clears query ownership, and emits `disposed`. It is safe to call
again; a disposed world cannot restart. Retained queries do not keep the world
alive and return empty results after disposal or world destruction.

Lifecycle transitions are guarded against re-entry. A stop requested during
startup cancels remaining start hooks and then stops the systems already
started. Starting or ticking from a stop hook is ignored; call `start()` after
the stop operation returns. Ticking from a start hook is also ignored. Commands
or disposal requested by lifecycle notifications finish at the same outer safe
boundary. A `cleared` listener may initialize fresh entities; a recursive
`clear()` from that listener is ignored. During disposal, creation and writes
remain rejected through all notifications.

## Runtime diagnostics

Add `EcsDebugPanel` under a `CanvasLayer` or another UI parent. Set its Inspector
`runner_path` to an `EcsRunner`, or call `panel.set_world(world)`. The panel shows
whole-world counts, a capped entity list with selectable component values, and
the system schedule. Its semantic modules are `WorldSummaryModule`,
`EntityModule`, and `SystemModule`. It does not handle global gameplay input.
`refresh_interval` defaults to 0.25 seconds and `max_entities` to 100. A freed,
disposed, or missing world displays an explicit empty state. The world
reference is weak.

Pause/resume, single step and a bounded `MutationTraceModule` are available.
Trace records retain the responsible system for deferred commands. Without UI,
use `trace_enabled`, `trace_capacity`, `get_trace()` and `clear_trace()`.

```gdscript
var panel := EcsDebugPanel.new()
$DebugCanvas.add_child(panel)
panel.set_world(runner.world)
runner.world.profiling_enabled = true
panel.refresh_now()
```

Profiling is opt-in. `profiling_enabled` records world tick duration and each
system's last update duration in microseconds; this adds measurement overhead.
Reading `get_debug_snapshot(max_entities)` or showing a panel never enables it.
Snapshots contain `entity_count`, `component_counts`, `entities`, `systems`,
`query_count`, `pending_command_count`, `last_tick_usec`, and `disposed`.
Entity rows contain `id` and `components`, ordered by ID and capped by the
argument. System rows contain `name`, `enabled`, `priority`, `phase`, and
`last_update_usec`. Snapshots also expose `profiling_enabled`,
`validation_enabled`, and `last_validation_error`. Array and Dictionary
component values are copied for inspection; Object values retain their normal
reference semantics. Component values are diagnostic data, not a save-game
serialization format.

## API reference

Public runtime classes are registered with `class_name`. Underscore-prefixed
methods and fields are implementation details.

| Class | Public methods and fields |
| --- | --- |
| `ECSmini` | `VERSION`, `create_world(backend = null) -> EcsWorld` (null if backend is owned or nonempty) |
| `EcsWorld`: entities | `create_entity() -> int`, `destroy_entity(id) -> bool`, `is_entity_alive(id) -> bool`, `is_entity_pending_destroy(id) -> bool`, `has_pending_destructions() -> bool`, `entity_count() -> int`, `get_entities() -> Array[int]` |
| `EcsWorld`: components | `add_component(id, key, value = null) -> bool`, `remove_component(id, key) -> bool`, `has_component(id, key) -> bool`, `get_component(id, key, default_value = null) -> Variant`, `set_component(id, key, value) -> bool`, `get_entity_components(id) -> Dictionary` |
| `EcsWorld`: schemas | `register_component(key, variant_type = -1, validator = Callable()) -> bool`, `unregister_component(key) -> bool`, `component_registry`, `validation_enabled`, `require_registered_components`, `last_validation_error`, signal `validation_failed(id, key, message)` |
| `EcsWorld`: systems | `add_system(system) -> bool`, `remove_system(system) -> bool`, `set_system_priority(system, priority) -> bool`, `set_system_phase(system, phase) -> bool`, `set_system_enabled(system, enabled) -> bool`, `resort_systems()` |
| `EcsWorld`: lifetime | `query(criteria = {}) -> EcsQuery`, `start()`, `stop()`, `tick(delta)`, `tick_phase(delta, phase_filter)`, `flush()`, `clear()`, `dispose()`, `is_disposed() -> bool`, signals `entity_destroyed(id)`, `cleared()`, and `disposed()` |
| `EcsWorld`: diagnostics | `profiling_enabled`, `get_debug_snapshot(max_entities = 100) -> Dictionary`, `get_component_version(key) -> int`, `get_entity_version() -> int` (query invalidation counters) |
| `EcsComponentRegistry` | `register_component(key, variant_type = -1, validator = Callable()) -> bool`, `unregister_component(key) -> bool`, `has_component(key) -> bool`, `validate(key, value, require_registered = false) -> bool`, `definitions() -> Dictionary` (key to Variant type), `clear()`, `last_error` |
| `EcsQuery` | `get_world() -> EcsWorld`, `entities() -> Array[int]`, `count() -> int`, `for_each(callback)`, `batches(chunk_size = 256)`, counters `refresh_count`, `candidate_checks` |
| `EcsSystem` | `Phase.SIMULATION`, `Phase.PRESENTATION`, `enabled`, `priority`, `phase`, `debug_name`, signal `schedule_changed()`, hooks `configure(world)`, `on_start()`, `on_update(world, delta)`, `on_stop()`, `on_detach()` |
| `EcsRunner` | `world`, `use_physics_process`, `separate_presentation`, `enabled`, `time_scale`, `dispose_world_on_free`, `add_system(system) -> bool` |
| `EcsNodeSync` / `EcsNodeSync3D` | `new(world = null)`, `attach_world(world)`, `bind(id, node) -> bool`, `unbind(id)`, `get_node(id)`, `get_entity(node) -> int`, `clear()` |
| `EcsMovementSystem` / `EcsMovement3DSystem` | `POSITION`, `VELOCITY`; inherit `EcsSystem` |
| `EcsTransformSyncSystem` / `EcsTransformSync3DSystem` | `new(sync)`, `sync`, `use_global_transform`, `POSITION`, `ROTATION`, `SCALE`; inherit `EcsSystem` |
| `EcsDebugPanel` | `runner_path`, `refresh_interval`, `max_entities`, `set_world(world)`, `get_world()`, `refresh_now()`, `select_entity(id) -> bool` |
| `EcsSparseStorage` / `EcsArchetypeStorage` | `EcsStorage` implementations; application writes go through World APIs |

## Examples

Open these scenes in Godot and press F6:

- `addons/ecsmini/examples/2d/Movement2D.tscn`: ECS movement with explicit Node2D bindings.
- `addons/ecsmini/examples/3d/Movement3D.tscn`: fixed simulation and Node3D presentation.
- `addons/ecsmini/examples/advanced/AdvancedEcsLab.tscn`: paused, button-driven
  storage/replay lab with sparse/archetype backends, four row groups, follower
  relations, spatial highlighting and snapshot/rollback controls. The lab
  controller owns the sole `EcsReplay` clock; its UI modules do not listen to
  global gameplay input.

The host project may provide additional game-specific integration scenes.
Gameplay input, plant and zombie rules, damage, and waves belong to the application.

## Tests and benchmarks

Run from the project root. Replace `godot` with the full path to your installed
Godot console executable when it is not on `PATH`.

```powershell
godot --headless --editor --path . --quit
python addons/ecsmini/tests/run_tests.py --godot godot
godot --headless --path . --script addons/ecsmini/tests/diagnostics_test.gd
godot --headless --path . --script addons/ecsmini/examples/example_smoke_test.gd
godot --headless --path . --script addons/ecsmini/benchmarks/runtime_benchmark.gd -- --counts=100,1000,10000 --samples=5 --iterations=30 --warmup=1 --output=user://ecsmini_benchmark.json
```

The Python runner needs only the standard library. It imports project scripts,
executes every `addons/ecsmini/tests/*_test.gd` contract, and runs a small
benchmark contract plus bounded example scene smoke checks. Godot script
errors and leaked ObjectDB instances fail the runner even if Godot exits
with code zero. Each standalone GDScript test also returns a nonzero exit code
when assertions fail.

The benchmark first checks each scenario's deterministic behavior, warms up,
then collects samples. Defaults cover 100, 1000, and 10000 entities. The timed
region excludes setup, correctness checks, and disposal. World profiling stays
off during measurements. Scenarios are:

| Scenario | Work per iteration | Correctness check |
| --- | --- | --- |
| `movement` | One 0.25 second tick integrating all positions | Every position equals its expected value |
| `static_query` | One cached query `count()` | Result count and cache refresh count stay stable |
| `unrelated_changes` | Add/remove an unrelated key and query after both | Membership and relevant-query refresh count stay stable |
| `spawn_destroy` | Create, add a component, and destroy a batch of `max(1, population / 10)` entities | Steady population remains; temporary IDs and components are removed |

`--counts`, `--samples`, `--iterations`, and `--warmup` configure workload.
`--output` optionally writes JSON to an existing writable location, including
Godot's `user://` directory. Standard output always contains one report prefixed
with `ECSMINI_BENCHMARK_JSON=`. Results include raw sample microseconds, median,
mean, per-iteration median, engine version, and correctness failures. No wall
time threshold is asserted. Compare runs with the same Godot build, hardware,
workload, and system load; these scripts do not claim a speed advantage over
Godot nodes or other ECS implementations.

The historical pre-0.3 measurement is recorded in
[benchmarks/BASELINE.md](benchmarks/BASELINE.md). It is not a performance baseline
for the current storage and compute implementation or a target frame-rate claim.
