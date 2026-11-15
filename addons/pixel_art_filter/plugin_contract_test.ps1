$ErrorActionPreference = 'Stop'
$pluginRoot = $PSScriptRoot
$cfg = Get-Content -Raw (Join-Path $pluginRoot 'plugin.cfg')
$source = Get-Content -Raw (Join-Path $pluginRoot 'plugin.gd')

if ($cfg -notmatch 'name="Pixel Art Filter"') { throw 'Plugin name is missing' }
if ($cfg -notmatch 'script="plugin.gd"') { throw 'Plugin script entry is missing' }
if ($source -notmatch 'extends EditorPlugin') { throw 'Plugin must extend EditorPlugin' }
if ($source -notmatch 'add_tool_menu_item') { throw 'Plugin menu action is missing' }
if ($source -notmatch 'scene_changed') { throw 'Plugin must react to scene changes' }
if ($source -notmatch 'node_added') { throw 'Plugin must react to newly added nodes' }
if ($source -notmatch 'call_deferred') { throw 'Plugin must defer automatic scans until nodes are configured' }
if ($source -notmatch 'get_edited_scene_root') { throw 'Plugin must operate on the edited scene' }
if ($source -notmatch 'Sprite3D') { throw 'Plugin must scan Sprite3D nodes' }
if ($source -notmatch 'BaseMaterial3D') { throw 'Plugin must scan BaseMaterial3D resources' }
if ($source -notmatch 'TEXTURE_FILTER_NEAREST') { throw 'Plugin must apply nearest filtering' }
if ($source -notmatch 'add_do_property') { throw 'Plugin must support undo/redo' }
if ($source -notmatch 'surface_get_material') { throw 'Plugin must scan mesh surface materials' }

Write-Output 'Pixel Art Filter plugin contract passed.'
