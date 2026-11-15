# 2D / 3D Integration Implementation Plan

> For agentic workers: execute the tasks in order and run the verification gates before delivery. Preserve uncommitted user files and do not create commits without a new instruction.

**Goal:** Produce one runnable project at `E:/生产项目/项目/GodotProject/pvz_warG` with `2d`, `3d`, `shared` and root-level plugins.

**Architecture:** Preserve the existing 2D scene flow and the 3D FrontYard node hierarchy. Relocate dependency groups using an explicit old/new resource map. Share only dimension-independent services and identical base classes; preserve the distinct state machine and settings interfaces.

**Tech stack:** Godot 4.7.1, GDScript, PowerShell and Python 3.12.

## Task 1: Preserve the baseline

- [x] Record root and nested Git status, commits and all resource hashes.
- [x] Back up both repositories and their untracked files outside the Godot project, excluding only regenerable caches.
- [x] Work on `codex/integrate-2d-3d` in the user-selected target directory.
- [x] Compare the accidental nested 2D copy against the root 2D sources. All 855 compared files are identical; archive the complete copy.
- [x] Run the existing 2D validation and 3D contracts as baseline; record stale test failures separately.

## Task 2: Define and check the migration map

- [x] Move 2D `src`, `scenes`, `assets`, `resources` to `2d/` except the shared services listed below.
- [x] Share audio, fonts, audio bus resources, dimension-independent event bus and transition code under `shared/`.
- [x] Move 3D `Map/FrontYard` to `3d/scenes/maps/front_yard`, preserving its internal grass module and node paths.
- [x] Move 3D managers to `3d/src/managers`; card preview to `3d/scenes/cards_box`; assets to `3d/assets`.
- [x] Move reusable 3D settings to `shared/scenes/settings` and dimension-independent state machine code to `shared/src/state_machine`.
- [x] Share the byte-identical `general_character` class and UID under `shared/src/characters`.
- [x] Bring ECSmini and pixel_art_filter into root `addons/` without modifying their public paths.
- [x] Inventory every UID collision and retain one active owner for identical resources; remap different collisions explicitly.

## Task 3: Perform mapped relocation

- [x] Add a migration script using an explicit per-file manifest, collision rejection and byte-preserving media copies.
- [x] Add a contract test for one project root, exclusive global class/UID ownership, shared singleton registration and resource existence; run it before migration and confirm it fails on the nested layout.
- [x] Rewrite only known `res://` prefixes and mapped resource paths in runtime source, scenes, import metadata and tests. Preserve UID sidecars.
- [x] Preserve the original manifests under maintenance history; write an integration manifest with original hashes and canonical targets.
- [x] Archive the original nested project outside the active import tree after copies and hashes have been verified. Retain the empty cwd held by Windows.

## Task 4: Merge project interfaces

- [x] Update root `project.godot`: use the 2D F5 main scene, register shared Audiomanager once and preserve existing 2D singleton names. Register ECSmini/pixel_art_filter; keep the optional local MCP registration in ignored `override.cfg`.
- [x] Use Forward Plus with Jolt Physics and preserve the 2D viewport/stretch behavior; verify with a real GPU.
- [x] Update old `.tres` audio-save migration to accept both historical paths and preserve backup contents and stored values.
- [x] Separate 2D pause/settings from FrontYard's reusable settings panel; restore audio bus state when leaving the 3D module.
- [x] Keep the user's local-plugin ignore intent; narrow ignoring to the MCP bridge and its local override so project plugins are trackable.

## Task 5: Verify and document

- [x] Update `tools/verify_references.py` for the new roots and integration manifest, preserving legacy integrity checks through composed path mappings.
- [x] Update FrontYard contracts, ECSmini example smoke references and the 2D smoke resource scan for relocated resources.
- [x] Run editor import, static references, all 2D flow checks, FrontYard contracts, grass runtime checks, settings structure and all ECSmini contracts/benchmarks.
- [x] Run actual graphical 2D and 3D scenes; capture and inspect screenshots for grass, shadows, camera framing and UI scaling.
- [x] Review the final diff and shared singleton side effects; fix the two review findings and verify a clean copy without the MCP bridge or caches.
- [x] Leave the complete change uncommitted for user review; record entry paths, backup and limitations in README and the validation report.
