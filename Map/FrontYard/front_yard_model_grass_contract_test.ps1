$grassRoot = Join-Path $PSScriptRoot 'Background\Grass'
$settings = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$cell = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell.gd') -Raw
$scene = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'FrontYard.tscn') -Raw

if ($settings -notmatch 'stylized_lawn_demo\.glb') { throw 'New lawn demo GLB is not the default model grass asset' }
if ($settings -notmatch '@export var dark_color: Color') { throw 'Dark model grass color is not exposed in LawnGrassSettings' }
if ($settings -notmatch '@export var light_color: Color') { throw 'Light model grass color is not exposed in LawnGrassSettings' }
if ($settings -notmatch '@export var model_mesh_name_filter: String = ""') { throw 'Model grass mesh filter should default to all meshes' }
if ($settings -notmatch 'model_variant_weights: PackedFloat32Array') { throw 'Model variant weights are not exposed' }
if ($settings -notmatch '@export_range\(1, 200, 1\) var model_clumps_per_cell: int = 25') { throw 'Default model grass density is not set to 25 clumps per cell' }
if ($settings -notmatch '@export_range\(0\.1, 1\.5, 0\.01\) var model_grass_scale: float = 0\.68') { throw 'Default model grass scale is not set to 0.68' }
if ($settings -notmatch 'density_noise_strength' -or $settings -notmatch 'height_noise_strength') { throw 'Model noise controls are missing' }
if ($grid -notmatch '_collect_model_meshes' -or $grid -notmatch 'model_scene') { throw 'LawnGrid does not own model mesh loading' }
if ($grid -match '_prepare_model_materials|_model_grass_materials') { throw 'LawnGrid must not cache materials that depend on a LawnCell boundary' }
if ($cell -notmatch 'transforms_by_variant' -or $cell -notmatch 'get_model_instance_batches') { throw 'LawnCell model instance data generation is missing' }
if ($cell -notmatch 'set_instance_custom_data|custom_data_by_variant') { throw 'LawnCell does not provide per-instance custom data for merged rendering' }
if ($grid -notmatch 'render_chunks|_rebuild_render_chunk') { throw 'LawnGrid does not own merged render chunks' }
if ($cell -notmatch 'func _build_variant_schedule' -or ($cell -notmatch 'maximum remainder' -and $cell -notmatch '最大余数法')) { throw 'Model variant ratios are not guaranteed by a deterministic quota' }
if ($cell -notmatch 'cell_coverage') { throw 'Model grass coverage control is missing' }
if ($cell -notmatch 'density_noise' -or $cell -notmatch 'height_noise') { throw 'LawnCell does not consume both shared noise fields' }
if ($scene -notmatch 'LawnGrid\.tscn') { throw 'FrontYard scene does not instantiate LawnGrid' }

Write-Output 'FrontYard model grass contract passed.'
