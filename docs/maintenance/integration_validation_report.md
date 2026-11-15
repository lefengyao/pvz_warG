# 2D / 3D integration validation

Date: 2026-11-13. Engine: Godot 4.7.1, Windows, D3D12 Forward Plus, NVIDIA GeForce RTX 5060 Laptop GPU.

## Delivered layout

The single project root is `E:/生产项目/项目/GodotProject/pvz_warG`.

| Area | Entry or responsibility |
|---|---|
| 2D main / F5 | `2d/scenes/levels/chose_map.tscn` |
| 3D FrontYard / F6 | `3d/scenes/maps/front_yard/FrontYard.tscn` |
| 3D ECS demo / F6 | `3d/scenes/maps/front_yard/EcsFrontYardDemo.tscn` |
| 3D cards | `3d/scenes/cards_box/CardsBox.tscn` |
| Shared services | Audio, fonts, event bus, character base, both existing state machine APIs, transitions and reusable settings |
| Plugins | Root `addons/ecsmini`, `addons/pixel_art_filter`; optional local MCP bridge in ignored `override.cfg` |

The branch is `codex/integrate-2d-3d`, based on `a2720ef`. The original nested 3D repository was at `89a0036`. No integration commit or push was created. Existing untracked component/entity specifications were retained.

## Preservation and provenance

- Before integration, both repositories and untracked content were backed up outside the active project at `E:/生产项目/项目/GodotProject/_project_backups/pvz_warG_before_integration_20261113_164917`.
- The integration manifest records 1,003 source-file mappings to 915 copied active files. 88 alias records reuse identical resources rather than creating competing owners. Two different media UIDs were mapped explicitly to their canonical owners.
- Original `src`, `scenes`, `assets`, `resources` are preserved in the backup's `archived_*` directories. The original 3D repository, Git history and accidental nested 2D copy are preserved in `archived_pvz_warG`.
- All 855 non-cache files in that accidental 2D copy matched the corresponding pre-integration root files. There were no unique or differing files.
- 1,048 original/archive hash comparisons passed with no mismatch: 1,003 mapped files plus 45 archived-only 3D files. No original content was deleted to resolve collisions.
- A separate comparison of 288 active runtime scripts, shaders, scenes and resources against the mapped originals found exactly two intended behavior changes: the 2D audio-save migration and shared settings bus-state restoration. Other checked runtime content matches the originals after path/UID rewriting, including FrontYard lighting, grass, hierarchy and shaders.
- Windows holds the previous nested workspace directory open. Its contents were archived using native PowerShell moves; the active project's `pvz_warG/` directory is empty and contains no project configuration.

The earlier `migration_manifest.json` remains unchanged. Its paths are composed through the integration map. Two `map_button.gd` history paths had already been deleted by menu refactor `721ccab`; the verifier records these exact retired paths rather than permitting missing resources generally.

## Validation commands and results

Executed from the delivered root with explicit installed executable paths:

```powershell
./tools/verify_integration.ps1 -GodotPath 'E:/生产项目/项目/Godot/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' -PythonPath 'C:/Users/15610/AppData/Local/Programs/StudyIsle/runtime/python/python.exe' -Capture
```

Result: exit 0, final output `PASS: integration (14 FrontYard contracts)`.

| Check | Result |
|---|---|
| Strict editor import and configured main scene | Passed, no resource/script errors or warnings |
| Static references | 795 resource links, 531 registered UIDs locally, no errors |
| Integration layout | 5 tests passed: one project, entries, singleton/main, unique global classes, optional MCP |
| Original integrity through both manifests | 295 historical media/sidecar records and 356 historical UID records preserved; 439 integrated media/sidecar records and 709 integrated UID-bearing records preserved |
| 2D headless gameplay flow | 717 checks, 384 loaded resources, all 4 levels reached battle, no failures |
| 2D real renderer | 721 checks including captures, all 4 levels reached battle, no failures |
| FrontYard PowerShell contracts | All 14 passed |
| Grass runtime | 6 chunks; 1,756 instances after the test's density change; transformed AABB, wind margins, shadow toggles and density rebuilds passed |
| Shared settings structure and navigation | Passed |
| 3D / 2D scene round trips | 34 headless checks; 42 graphical checks including captures; no failures |
| ECSmini | All 11 test scripts, 2D/3D examples and host FrontYard smoke passed |
| ECSmini benchmarks | Four runtime correctness scenarios and all 24 advanced storage/dimension/compute configurations passed |
| Final whitespace diff | `git diff --check` passed |

Images were captured and inspected: `tools/logs/main_menu.png`, `first_level_battle.png`, `front_yard.png`, `ecs_front_yard.png`, `shared_settings.png`, `cards_box.png`. The front yard, grass, directional shadows, model dependencies, scene camera, menus and settings rendered successfully. Capture viewport is 1920 x 1080, displayed in a 960 x 540 window.

Before integration, the menu smoke used removed APIs and was corrected to exercise the existing menu/map/level buttons. Its corrected baseline passed all four levels. Two preexisting FrontYard contract failures were aligned with the actual baseline: the missing optimization checklist was supplied at its maintenance location, and ambient-light expectation was corrected from 0.4 to the existing 0.6. Scene lighting was preserved.

## Review findings fixed

1. Audio save migration now accepts both legacy serialized script paths and runs in the parent's `_enter_tree`, before child sliders read settings. Four fixtures cover both paths with/without an existing backup, saved values, byte preservation, absent saves, idempotence and temporary-file cleanup.
2. A 3D Master mute originally persisted into 2D. A new test reproduced the failure before the fix. The shared settings module now snapshots Master/music/sfx volume and mute before its children initialize, then restores them on exit. The test uses the real Master slider without saving changes to the user's JSON file and checks restoration after returning to 2D.
3. Ignored local MCP files no longer appear as mandatory dependencies in `project.godot`. Local registration remains in ignored `override.cfg`; shipped plugins remain trackable. A layout contract protects this boundary.

An independent read-only reviewer checked the integration and the two runtime/configuration fixes. The initial findings were resolved.

## Clean-copy verification

A separate project copy at `E:/生产项目/项目/GodotProject/_project_backups/pvz_warG_clean_validation_20261113` excludes Git, caches, MCP and `override.cfg`.

- Clean editor import, F5 main scene and 34 scene-round-trip checks passed without MCP.
- The full headless `verify_integration.ps1` also passed in that copy, including static integrity (479 registered UIDs without local MCP), all 4 levels, 14 contracts and ECSmini.
- Godot's first cold-cache import initializes the configured project font before generating `.fontdata`. The first pass reported only that font-cache condition. `verify_project.ps1` retains that log and allows a single retry only for the exact cache path read from `Silver.ttf.import` with the matching custom-font diagnostic. All unrelated errors/warnings fail immediately; the second import must be strictly clean.
- After narrowing that retry rule during review, the cache was moved aside and the clean-copy import/reference/main/2D flow gate was rerun successfully from a cold cache.

## Limits

These checks cover loading, scene interfaces, startup battles, input routing and visual inspection on the installed Windows GPU. They do not prove complete level playthroughs, game balance, export builds, other operating systems, other GPU/rendering backends or long-session performance. The ECS front yard retains its existing placeholder visuals and demonstration behavior.

Local verification logs and screenshots are ignored artifacts. The project-independent original backup and the clean validation copy remain available outside the delivered project.
