@tool
class_name EcsminiEditorPlugin
extends EditorPlugin

## Editor plugin entry script. ECSmini currently registers no editor panels or custom
## inspectors; its runtime classes are available through their [code]class_name[/code] declarations.[br][br]
## [codeblock]
## var world := ECSmini.create_world()
## world.tick(1.0 / 60.0)
## [/codeblock]
##
## @tutorial(Making plugins): https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html


## Called when Godot enables the plugin. Reserved for future editor-side setup.
func _enter_tree() -> void:
	pass


## Called when Godot disables the plugin. Reserved for future editor-side cleanup.
func _exit_tree() -> void:
	pass
