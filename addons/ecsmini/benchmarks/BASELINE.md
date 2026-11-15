# ECSmini 0.2.0 local baseline

Measured on 2026-10-01 with Godot 4.7.1 stable (official console build),
Windows 11, and an Intel Core i7-14650HX. This is a headless debug runtime
measurement with profiling disabled. It excludes renderer/GPU work, world
setup, correctness checks, and disposal. All 12 scenario/population combinations
passed their correctness checks.

Run from the project root:

```powershell
godot --headless --path . --script res://addons/ecsmini/benchmarks/runtime_benchmark.gd -- --counts=100,1000,10000 --samples=5 --iterations=30 --warmup=1 --output=user://ecsmini_benchmark.json
```

Each recorded sample covers 30 iterations; the table is the sample median
divided by 30. Spawn/destroy processes a batch of 10% of the steady population
per iteration. Cached query counts have already warmed their membership cache.

| Steady entities | Movement tick (ms) | Cached count (us) | Unrelated add/remove + two counts (us) | Spawn/destroy batch (ms) | Batch size |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | 0.443 | 1.233 | 10.467 | 0.079 | 10 |
| 1,000 | 4.690 | 1.167 | 10.000 | 0.755 | 100 |
| 10,000 | 77.813 | 1.400 | 24.433 | 18.015 | 1,000 |

The 10,000-entity movement samples ranged from 48.3 to 109.6 ms per iteration
in this run. Background load, power/thermal state, and debug-versus-exported
execution can materially change results. Retain the emitted JSON raw samples
when comparing a later implementation on the same machine.

The cache checks confirm that unrelated component memberships do not rebuild
the movement/query membership. Cached `count()` therefore avoids traversing
the population. Moving every entity still performs GDScript callbacks and
Variant/Dictionary component access for every entity; this baseline does not
establish a 60 FPS target for 10,000 movers. Measure a release export and the
actual gameplay workload before selecting large-scale entity/rendering budgets.
There is no before/after speedup claim or comparison with another ECS library.
