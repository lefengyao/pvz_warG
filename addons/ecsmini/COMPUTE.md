# ECSmini storage and packed computation

ECSmini can use dense sparse component columns or exact-signature archetype
chunks. Both implement `EcsStorage`, while `EcsWorld` continues to own entity
generations, deferred mutations, validation and query lifetimes.

```gdscript
var world := EcsWorld.new()
world.set_storage_backend(EcsArchetypeStorage.new(256)) # Empty world only.
```

`EcsSparseStorage` is the default. Each component has an entity array, an aligned
value array and an entity-to-row index. Removing a value swaps the last row into
the removed row. Per-entity dictionaries hold membership rather than values.

`EcsArchetypeStorage` groups exact component signatures into columnar chunks.
Adding or removing a component migrates the entity to another signature and
preserves its other values. A length-prefixed signature avoids collisions between
component names. Swap removal compacts chunks; empty tables and chunks are
reclaimed. The constructor sets the chunk capacity, clamped to at least one.
Set the capacity before creating entities.

Both backends reject duplicate entity creation, duplicate components, empty
component keys and writes to absent components. Storage IDs are arbitrary integer
keys; IDs, generations and world ownership belong to `EcsWorld`.

`world.storage.diagnostics()` exposes the backend, entity and component counts,
value count, table count, chunk count and chunk capacity. In sparse storage,
tables are component columns and there are no archetype chunks.

## Capture, compute, commit

Capture and commit run on the main thread. Queries export aligned component
columns and opaque entity IDs; computation receives packed math data.

```gdscript
var query := world.query({"all": [&"position", &"velocity"]})
for batch: Dictionary in query.batches(256):
    var positions := PackedVector2Array(batch.columns[&"position"])
    var velocities := PackedVector2Array(batch.columns[&"velocity"])
    var output := EcsBatchCompute.integrate2d(positions, velocities, delta, &"serial")
    if output.size() == batch.entities.size():
        world.write_batch(&"position", batch.entities, output)
```

`integrate3d()` has the same API with `PackedVector3Array`. Both calculate
`position + velocity * delta` and return a new packed array. They reject different
array lengths, unknown modes, negative/nonfinite delta, nonfinite input vectors
and results that overflow to nonfinite values. Invalid input returns an empty
array and sets `EcsBatchCompute.last_error`. Empty input is valid and clears the
error. Use the diagnostic to distinguish an empty valid batch from rejection.

Modes:

| Requested mode | Behavior |
| --- | --- |
| `serial` | GDScript kernel on the main thread. |
| `parallel` | Isolated packed slices computed by `WorkerThreadPool`. |
| `auto` | Parallel at or above `parallel_threshold`; serial below it. |

`availability()` reports the supported execution modes and current thresholds.
`last_mode` reports the mode actually executed. Calling another valid compute
clears an earlier `last_error`.

The synchronous public orchestration methods must run on the main thread. Each
worker owns its packed slices and writes a separately allocated output. The main
thread joins **every** submitted task before reading results, including when a
worker rejects invalid input. Workers never share a writable packed buffer and
never access the world, nodes or resources. They never update global diagnostics.

`EcsStorage` also exposes two internal paths used by `EcsWorld` to keep lifecycle
and batch writes cheap:

```gdscript
# World-owned internal use; application code should keep using world.write_batch().
var component_keys: Array[StringName] = storage.keys_for(entity_id)
storage.set_values_unchecked(type_key, entities, values)
```

`keys_for(id)` returns component membership without copying component values. Both
built-in backends provide a direct implementation (the base contract has a safe
membership fallback), which lets entity destruction and snapshot capture enumerate
keys without materializing a full component dictionary. `set_values_unchecked()`
assumes the caller has already validated the entity IDs, duplicate rows, component
membership, array lengths, pending structural state and component schemas. It writes
the aligned values in place and performs no validation or ownership checks itself.
`EcsWorld.write_batch()` is the supported application API: it performs those checks,
handles deferred membership, and records mutation/trace entries before invoking the
unchecked storage path. These methods are main-thread internals and must not be
called directly by systems, worker tasks or game code.

The defaults are `parallel_threshold = 4096` and `worker_chunk_size = 2048`.
They are configurable positive thresholds; measure realistic batches before
choosing them. Tiny movement kernels often cost less than thread dispatch and
joining. Parallel computation is an available execution path, with no guaranteed
speed improvement.

Batch exports deeply duplicate arrays, dictionaries, packed arrays and nested
Resources with Godot's `DEEP_DUPLICATE_ALL` policy. Ordinary Object/Node identity
is retained; such values belong to the main thread and must never become worker
inputs. The computation API accepts packed Vector2/Vector3 data.

## Benchmarks and contracts

```powershell
godot --headless --path . --script addons/ecsmini/tests/storage_compute_test.gd
godot --headless --path . --script addons/ecsmini/benchmarks/advanced_benchmark.gd -- --counts=100,1000,10000 --samples=3 --iterations=10 --output=user://ecsmini-advanced.json
```

Storage contracts compare 1,200 deterministic random mutations per backend with
a reference model, including all/any/none filters and batch column alignment.
They also cover tags, arbitrary IDs, chunk migration, swap removal, componentless
entities, clear and deeply isolated mutable values. Compute contracts compare
serial, parallel and automatic 2D/3D kernels.

The advanced benchmark uses actual `EcsWorld` instances, both storage backends,
2D/3D columns, a frozen exclusion filter and varied signatures. It measures
capture/packing, computation, commit and total time separately. Every sample
creates an independent world, warms it up, checks every resulting entity and
disposes the world. World setup, correctness checking and disposal are excluded
from timings. `--modes=serial,parallel,auto`, `--chunk-size`, `--warmup`,
`--samples` and `--iterations` configure the workload.

The single JSON report has the prefix `ECSMINI_ADVANCED_BENCHMARK_JSON=`. Timing
samples and per-iteration medians are reported for each stage. These are current
backend comparisons on a specific machine, with no comparison to historical
baseline data and no general speedup claims.

Relevant Godot API documentation:
[WorkerThreadPool](https://docs.godotengine.org/en/4.7/classes/class_workerthreadpool.html),
[Resource duplication](https://docs.godotengine.org/en/4.7/classes/class_resource.html).
