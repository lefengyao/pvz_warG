$scriptPath = Join-Path $PSScriptRoot 'front_yard.gd'
$scenePath = Join-Path $PSScriptRoot 'FrontYard.tscn'
$source = Get-Content -LiteralPath $scriptPath -Raw
$scene = Get-Content -LiteralPath $scenePath -Raw

if ($source -match 'CAMERA_ORTHOGONAL|camera_orthographic_size|set_camera_orthographic_size|PROJECTION_ORTHOGONAL') { throw 'Orthographic camera support should be removed' }
if ($source -notmatch '@export_range\(15\.0, 75\.0, 0\.5\) var camera_down_angle: float') { throw 'Camera angle quick control is not exposed on FrontYard' }
if ($source -notmatch '@export_range\(1\.0, 60\.0, 0\.1\) var camera_distance: float') { throw 'Camera distance quick control is not exposed on FrontYard' }
if ($source -notmatch '@export_range\(0\.5, 60\.0, 0\.1\) var camera_height: float') { throw 'Camera height quick control is not exposed on FrontYard' }
if ($source -notmatch '@export_range\(20\.0, 75\.0, 0\.5\) var camera_fov: float') { throw 'Camera FOV quick control is not exposed on FrontYard' }
if ($source -notmatch 'func _apply_camera_controls') { throw 'Camera quick controls do not have an explicit apply path' }
$cameraApplyMatch = [regex]::Match($source, '(?s)func _apply_camera_controls\(\).*?(?=\nfunc )')
if (-not $cameraApplyMatch.Success) { throw 'Camera quick control apply function could not be isolated' }
$cameraApply = $cameraApplyMatch.Value
if ($cameraApply -notmatch 'camera\.position\s*=.*vertical_distance.*horizontal_distance' -or $cameraApply -notmatch 'camera\.rotation_degrees\s*=' -or $cameraApply -notmatch 'camera\.fov\s*=') { throw 'Camera quick controls must synchronize independent distances, angle, and FOV' }
$sourceOutsideCameraApply = $source.Remove($cameraApplyMatch.Index, $cameraApplyMatch.Length)
if ($sourceOutsideCameraApply -match 'camera\.\w+\s*=') { throw 'Camera3D properties may only be written by the explicit quick-control apply function' }
if ($source -match 'camera\.projection\s*=|camera\.current\s*=') { throw 'Projection and Current must remain direct Camera3D Inspector settings' }
if ($source -match 'auto_setup_light|light\.global_position|light\.look_at') { throw 'Directional light must remain fully Inspector-controlled' }
if ($source -notmatch 'lawn_grid\.rebuild_all_cells') { throw 'FrontYard should delegate lawn rebuild to LawnGrid' }
if ($scene -match 'auto_setup_light') { throw 'Removed light option must not be serialized in the scene' }
if ($scene -notmatch '\[node name="DirectionalLight3D" type="DirectionalLight3D"') { throw 'DirectionalLight3D scene node must remain available for Inspector editing' }

Write-Output 'FrontYard camera contract passed.'
