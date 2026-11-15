# Pixel Art Filter

This Godot editor plugin applies `BaseMaterial3D.TEXTURE_FILTER_NEAREST` to the current edited scene.

The plugin automatically rescans the edited scene when you switch scenes or add nodes. Newly added `Sprite3D` nodes and materials are therefore updated without pressing a button. Use `Pixel Art: Set Nearest Texture Filter` from the editor `Project > Tools` menu when you want to manually rescan the current scene or repair an imported resource.

It scans recursively for:

- `Sprite3D.texture_filter`
- `GeometryInstance3D.material_override` when it is a `BaseMaterial3D`
- Every `MeshInstance3D` surface material when it is a `BaseMaterial3D`

The operation is recorded in Godot's UndoRedo history. It changes the material resource itself, so shared materials used by multiple nodes are updated consistently.
