# ECSmini persistence, replay and debug controls

Persistence is optional and independent of gameplay. The application owns systems,
component schemas, command handlers and visual nodes. Snapshots contain data only;
loading a file never loads scripts, instantiates Objects or evaluates Variant text.

## Snapshots

```gdscript
world.register_reference_component(&"target")
var saved := EcsSnapshot.capture(world)
if saved.ok:
    var result := EcsSnapshot.restore(world, saved.snapshot)
    if result.ok:
        var new_handle: int = result.id_map[old_handle]
```

| API | Result |
| --- | --- |
| `EcsSnapshot.capture(world)` | `{ok, error, snapshot}` |
| `EcsSnapshot.validate(snapshot, world = null)` | Validated independent data copy, `{ok, error, snapshot}` |
| `EcsSnapshot.restore(world, snapshot)` | `{ok, error, id_map}`; map old handles to fresh generation handles |
| `EcsSnapshot.digest(world)` | `{ok, error, digest}`; SHA-256 of canonical simulation data |
| `world.get_entity_uid(handle)` | Persistent positive integer UID, or `0` if unavailable |
| `world.get_entity_by_uid(uid)` | Current generation handle, or `-1` if unavailable |

Schema version 1 contains `entities`, `reference_keys`, `metadata`, `relations` and
`events`. Each entity contains its old `id`, persistent `uid`, and a component
dictionary keyed by nonempty `StringName`. Metadata includes the next UID,
simulation tick/time and the World's RNG seed/state. Relations store source and
target UIDs. The event queue preserves committed/staged events and reader cursors.

Capture and restore require the World's owner thread at a safe boundary outside
ticks, query iteration, lifecycle callbacks and pending structural commands.
Validation copies and checks the complete snapshot before clearing any entity.
Malformed versions, duplicate IDs/UIDs, allocator collisions, invalid references,
unsupported values, component validator rejection and invalid extension snapshots
return `ok = false` with the existing entities unchanged.

Restore preserves registered systems, component definitions, reference schemas and
cached query objects. It replaces entity data and emits `world.restored(id_map)`
once; it does not emit per-entity destruction or the ordinary `cleared` callback.
Change readers receive a reset epoch. Use `restored` to rebuild scene bindings or
resolve persistent UIDs. Old entity handles must be discarded.

Register the same reference keys in the application before restoring. A registered
reference component supports a scalar entity handle or `Array` of integer handles;
nonpositive sentinel values are preserved. Only these explicit fields are remapped.
Every other integer remains its original value. Persistent UIDs are convenient for
references in nested application data and replay commands.

Component schemas and validators are application code. Register them before load;
validators should be pure and must not mutate the World. Snapshot validation checks
registered schemas even when runtime `validation_enabled` is false. Unregistered
component keys follow `require_registered_components`.

## Safe Variant codec and files

`EcsVariantCodec.encode(value)`, `decode(wire)` and `copy(value)` return
`{ok, error, value}`. The encoded value is JSON-compatible, using explicit type tags.
Supported values are nil, bool, int64, finite floats, String, StringName, Array,
Dictionary, Vector2/3/4, Vector2i/3i, Quaternion, Color, Basis, Transform3D and all
Godot 4 packed array types. Float64 values use eight-byte hex encoding; integers use
canonical decimal strings, including inside packed arrays. Array/Dictionary typed
container annotations are not serialized; element Variant types are preserved.

Objects (including Resources and Nodes), Callable, RID, signals, unknown tags,
non-finite floats and cyclic containers reject. Nesting is limited to 64 levels and
one million decoded/encoded values. Shared acyclic containers become independent
copies. The codec does not call `str_to_var` or allow Object deserialization.

```gdscript
var store := EcsSnapshotStore.new()
var saved := store.save(world, "user://game.json")
var loaded := store.load_into(world, "user://game.json")
if not loaded.ok:
    push_warning(loaded.error)
```

`save(world, path)` validates first, writes a sibling `.tmp` file, closes it and
renames it over the destination. `load_snapshot(path)` returns validated data
without altering a World. `load_into(world, path)` validates against the application
schemas before restore. Files use the `ecsmini.snapshot` format envelope with an
explicit version and tagged payload; the file size limit is 64 MiB. Save/load are
synchronous owner-thread operations; use separate filenames for concurrent writers.

Migrations are explicit callbacks supplied by the application:

```gdscript
store.register_migration(0, func(data: Dictionary) -> Dictionary:
    # Fill the version-1 data fields required by this application's old format.
    data.version = 1
    return data)
```

`register_migration(from_version, callback)` refuses duplicate, invalid or future
versions. `migrate(snapshot)` applies one version at a time and validates the final
data. Each callback receives an independent dictionary and must return a safe
dictionary with exactly `from_version + 1`. Missing migrations and unknown newer
versions reject. No callback or executable path is read from the file.

## Controlled replay and rollback

```gdscript
var replay := EcsReplay.new(world, 1.0 / 60.0, 120)
replay.register_command(&"damage", func(target: EcsWorld, payload: Dictionary) -> void:
    var handle := target.get_entity_by_uid(payload.uid)
    target.set_component(handle, &"health",
        target.get_component(handle, &"health") - payload.amount))
replay.queue_command(world.simulation_tick + 1, &"damage", {"uid": enemy_uid, "amount": 5})
replay.step(true) # Simulation once, then explicit presentation.
```

| API | Behavior |
| --- | --- |
| `new(world, fixed_delta = 1.0/60.0, checkpoint_capacity = 120)` | Weak World binding; initial checkpoint; capacity minimum 2 |
| `register_command(key, handler)` | Application Callable `(world, payload)`; returns bool |
| `queue_command(tick, key, payload = null)` | Copied safe input for an absolute future simulation tick; returns sequence |
| `step(present = false)` | One fixed simulation tick |
| `rewind(target_tick, present = false)` | Restore nearest retained checkpoint and simulate to target |
| `replay_to(target_tick, present = false)` | Simulate forward from current tick |
| `rollback_and_resimulate(from_tick, corrections, final_tick = -1, present = false)` | Restore before correction and replay to final tick |
| `get_history_range()` | Oldest/latest tick, checkpoint count and capacity |
| `state_digest()` | Handle-independent simulation digest |

Every command record in `corrections` is `{tick: int, key: StringName, payload}`.
All commands at each supplied tick are replaced in array order; commands at other
ticks remain. An empty correction array removes inputs at `from_tick`.
`final_tick = -1` uses the latest recorded tick. Commands in a tick execute by stable
FIFO sequence before simulation systems. Handlers receive another data copy.

Checkpoints use a bounded ring. Inputs older than the oldest retained checkpoint are
pruned. Rewinding to an evicted tick returns an explicit error. Malformed corrections
reject before mutation. A step producing unsupported snapshot state rolls back its
World data; a failed multi-step resimulation restores the preceding final snapshot
and replay history. Such restoration generates fresh handles, even on failure;
retain UIDs and listen for `restored` when rebinding references.

Only `SIMULATION` systems run during resimulation. `world.is_replaying` is true
during restoration/replay; optional presentation runs once after the final state and
after that flag is restored. Simulation systems can gate direct audio, networking,
achievements and other external side effects using the flag. Presentation consumers
also need the event policy below because their final call observes the restored flag.
Data rollback cannot undo external side effects. Handlers must not dispose, clear,
change schemas, alter clocks, or otherwise close the World. Systems must keep all
mutable simulation state in snapshot data and use `world.rng`; instance-local
mutable caches/state, OS time, external RNG and uncontrolled input are not replayed.

### Presentation events and external side effects

`present = true` does not run presentation while the replay is in progress. The
replay operation restores `world.is_replaying` first, then calls one presentation
phase for the final state. In the normal case the presentation system therefore
observes `world.is_replaying == false`, even though its event data was produced by a
resimulation. A presentation system cannot use that flag alone to decide whether an
event is safe to send to an external service.

Event snapshots include both committed/staged events and named reader cursors.
Restoring a checkpoint restores those cursors too. A later presentation read can
therefore return the same committed event sequence again after `rewind()` or
`rollback_and_resimulate()`. `EcsEventQueue.read()` advances a named reader over all
committed events even when a key filter is supplied, so use one dedicated reader for
the presentation consumer. `advance()` moves the event stage and is not a reader
discard operation; `forget_reader()` starts a reader at retained history rather than
skipping it.

Choose an application-level policy for every external consumer:

```gdscript
# A stable id in the payload makes a replayed event idempotent for this consumer.
var report := world.get_events().read(&"presentation")
for event: Dictionary in report.events:
    var event_id: String = String(event.payload.event_id)
    if already_applied.has(event_id):
        continue
    already_applied[event_id] = true
    send_audio_or_network_effect(event.payload)
```

For a consumer that must suppress all effects from a resimulation, call `read()` on
that same presentation reader after a successful replay with `present = false` and
discard the returned events before the next presentation phase. This uses the
existing cursor API and preserves future events. Calling `clear()` is a global queue
reset and also removes staged events, so reserve it for an intentional world reset.
For corrected input, an unchanged payload ID can be deduplicated; a changed payload
needs an idempotent upsert or an application-specific compensation because ECS data
rollback cannot undo an effect already sent outside the World.

The contract test `tests/replay_side_effects_test.gd` verifies that presentation sees
`is_replaying == false` after normal and corrected replay, that restored cursors
re-read historical sequences, and that payload IDs or an explicit `read()` discard
prevent duplicate side effects.

The digest normalizes entity handles and explicit references to UIDs, sorts
dictionary keys and entities, and excludes event reader/reset observation metadata.
It includes simulation metadata, components, relations and queued events. This is
controlled determinism on one engine/platform; cross-platform network lockstep is
not guaranteed.

## Debug UI

Add `EcsDebugPanel` to UI and assign `runner_path`, or call `set_runner(runner)`.
`set_world(world)` also supports a manually driven external World. Bindings are weak.
Existing summary/entity/system modules remain, alongside `SimulationControlModule`
and `MutationTraceModule`.

Pause/Resume changes the bound Runner's `enabled` property. Step calls
`runner.step(delta)` and leaves it paused; direct World binding runs simulation then
presentation once, without owning any automatic update loop. Pause is unavailable
for a World-only binding. Controls use their own button signals and never listen to
global gameplay input.

Tracing is opt-in through the Mutation trace switch or `world.trace_enabled = true`.
`world.trace_capacity` bounds stored entries; `panel.max_trace_entries` bounds the
display. Rows show sequence, operation, persistent UID, component key and responsible
system. `world.get_trace()` returns copied entries and `clear_trace()` clears them.
The panel never enables profiling automatically. `refresh_now()` updates immediately;
otherwise visible panels refresh at the configured interval.

## Verification

Run the headless editor import first, then:

```powershell
godot --headless --path . --script addons/ecsmini/tests/persistence_test.gd
godot --headless --path . --script addons/ecsmini/tests/diagnostics_test.gd
```

The contracts cover exact integer/Variant round trips, invalid snapshots remaining
atomic, schema validation, fresh handles and UID/reference remapping, staged events
and relationships, migrations, RNG/input replay, corrected rollback, ring eviction,
failed resimulation restoration, pause/step, and bounded responsible-system trace.
