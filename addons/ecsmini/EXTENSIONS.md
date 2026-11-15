# ECSmini data extensions

Extensions are reusable, world-local data tools. They do not listen to scene
input and do not depend on plants, zombies or the project's global EventBus.
All mutation and index operations belong on the world's owner thread.

## Entity templates

`EcsEntityTemplate` is a `Resource` with exported `base_template` and
`components: Dictionary` properties. It can be edited in the Inspector and
saved as a `.tres` resource.

```gdscript
var template := EcsEntityTemplate.new()
template.components = {&"health": 100, &"position": Vector2.ZERO}
var entity := template.spawn(world, {&"health": 150})
var entities := template.spawn_many(world, 2, [{&"health": 120}, {&"health": 90}])
```

Base values are merged first, then derived values, then instance overrides.
Each component override replaces the whole value. `resolve(overrides={})`
returns fresh values without spawning. Arrays, dictionaries, packed arrays and
Resources are deeply copied so instances cannot modify template defaults or
each other's data. Live Objects, Callables, Signals, RIDs and cyclic/deep
container data are rejected. Inheritance cycles are rejected.

`spawn` returns a generation-bearing entity ID or `-1`. `spawn_many(world,
count, per_instance_overrides=[])` returns IDs or an empty array. If supplied,
the overrides array must contain exactly `count` dictionaries. All schemas and
overrides are checked before creating entities. An unexpected rejected world
write rolls back only the entities created by that call; deferred destruction
commits at the world's usual iteration boundary. `last_error` explains failure.

## Staged events

`world.get_events()` lazily creates one `EcsEventQueue` for the world. A queue
can also be constructed directly with `EcsEventQueue.new(capacity=1024)`.
`emit_event(key, payload=null)` copies and stages a payload, returning `false`
and setting `last_error` for invalid data or a full staged queue.

`advance()` (alias `commit_stage()`) increments the stage and publishes staged
events. The world calls it at the start of a simulation tick. Events emitted
inside a tick are therefore read by systems in the following tick. A
presentation-only tick does not advance this queue.

```gdscript
world.get_events().emit_event(&"damage", {"amount": 10})
var result := world.get_events().read(&"damage_system", &"damage")
for event in result.events:
    print(event.sequence, event.stage, event.payload)
```

Named readers have independent cursors. The optional key filter still consumes
all committed keys since that reader's last read. New readers start with the
currently retained history. Reads return copied records, with this shape:

```text
{events: [{sequence, stage, key, payload}], stage, overflow, missed, reset}
```

Only the most recent `capacity` committed events are retained. Established
readers that lag behind receive `overflow=true` and an exact `missed` count.
Staged events have the same separate capacity and are rejected, never silently
lost, when full. `clear()` removes staged/committed events and resets stage and
sequences; existing readers observe `reset=true` once on their next read.
`forget_reader(name)` releases a cursor.

`capture()` and `restore(data)` preserve stage, event sequences, pending
payloads and reader cursors. `validate_snapshot(data)` checks version 1 and
the full structural schema before mutation. Runtime Resource payloads are
allowed; the snapshot codec controls which values can be saved to disk.

## Entity relationships

`world.get_relations()` lazily owns an `EcsRelations`. The registry holds only
a weak reference back to the world, with forward and inverse link maps.

```gdscript
var relations := world.get_relations()
relations.add(child, &"parent", parent, EcsRelations.DESTROY_SOURCE)
relations.add(projectile, &"owner", plant) # REMOVE_LINK is the default
relations.set_targets(selected, &"target", [zombie]) # replaces targets of this key
var children := relations.get_sources(parent, &"parent")
```

`add(source,key,target,policy=REMOVE_LINK)` rejects duplicate links;
`set_targets(source,key,targets:Array,policy=REMOVE_LINK)` replaces all targets
for the source/key after checking every distinct live replacement. An empty
array removes all targets.
`remove(source,key,target=-1)` removes one target or all targets for that key.
`get_targets(source,key)`, `get_sources(target,key=&"")` and
`query(key,target=-1)` return sorted current IDs, excluding pending destruction.

Policies apply to destruction of the **target**:

* `REMOVE_LINK`: remove the incoming link and keep its source alive.
* `DESTROY_SOURCE`: request destruction of the source after link cleanup.
* `RESTRICT`: reject regular destruction while a live source holds this link.

The world checks `can_destroy(entity)` before accepting normal destruction.
Source destruction always cleans outgoing links. Cascades use the world's
deferred command boundary and safely clean cyclic relationships. A restrictive
link on a cascading source can still block its own destruction. World clear
and disposal clear relations first, forcing full cleanup.

`clear()` removes links. `attach(world)` and `detach()` manage subscriptions.
For gameplay, use the world's registry so its destruction guard is active.

`capture()` has schema `{version:1,links:[{source_uid,target_uid,key,policy}]}`.
It excludes dead/pending entities and uses persistent entity UIDs, so runtime
generation IDs can change on restore. `restore(data,id_map={})` resolves those
UIDs, validates the whole state, and then replaces links atomically. The runtime
ID map is accepted for integration and is unnecessary for this UID schema.
Static `validate_snapshot(data,entity_uids:Array[int]=[])` optionally checks UID
membership; an empty UID array performs structural validation only.

## Group and spatial indexes

Both indexes weakly reference the world, listen to `mutation_committed`,
rebuild on `restored`, and clear on world clear/disposal. Query results are
copies and exclude stale generation IDs and pending destruction immediately.
Call `detach()` to stop updates or `reindex()` after deliberate bulk changes.
In-place mutable component edits must call `world.mark_component_changed`.

```gdscript
var rows := EcsGroupIndex.new(world, &"row")
var row_entities := rows.entities(2)
var spatial := EcsSpatialIndex.new(world, &"position", 64.0)
var nearby := spatial.radius(Vector2(100, 100), 32.0)
var closest := spatial.nearest(Vector2(100, 100), 3, 200.0)
```

`EcsGroupIndex.entities(value)` groups by component Variant equality;
`values()` returns copied group values. Scalar, vector, array, dictionary and
packed array data can be keys. Object/Resource identity and callback keys are
excluded. Values are copied when indexed, preventing later data mutation from
corrupting bucket keys. Entity IDs are sorted for deterministic iteration.

`EcsSpatialIndex` indexes finite `Vector2` and `Vector3` component values in
separate bucket maps. `cell_size` must be finite and positive; changing it
reindexes current entities. `radius(position,distance)` includes exact boundary
matches. `nearest(position,limit=1,max_distance=INF)` returns at most `limit`
IDs. Both return increasing exact squared distance, then increasing entity ID
for ties. Negative coordinates use floor-based buckets. Large radius searches
scan occupied buckets rather than iterating an enormous empty-cell volume.
Invalid positions or distances return an empty result.

Indexes are disposable caches and are rebuilt from restored components instead
of being serialized. World signal subscriptions retain indexes until detach or
world disposal, while weak world references prevent ownership cycles.
