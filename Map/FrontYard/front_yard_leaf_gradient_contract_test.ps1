$root = $PSScriptRoot
$grassRoot = Join-Path $root 'Background\Grass'
$settings = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$shader = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell_grass.gdshader') -Raw
$resource = Get-Content -LiteralPath (Join-Path $grassRoot 'LawnGrassSettings.tres') -Raw

foreach ($name in @('grass_root_color', 'grass_tip_color', 'grass_gradient_strength', 'grass_gradient_exponent')) {
    if ($settings -notmatch $name) { throw "Settings is missing $name" }
    if ($grid -notmatch $name) { throw "Grid does not synchronize $name" }
    if ($shader -notmatch $name) { throw "Shader is missing $name" }
}
if ($resource -notmatch 'grass_root_color' -or $resource -notmatch 'grass_tip_color') {
    throw 'Default resource does not serialize gradient colors'
}
if ($grid -notmatch '_grass_materials_by_variant|model_variant_materials') {
    throw 'Grid must cache materials per style and model variant'
}
if ($grid -notmatch '_scale_gradient_color') { throw 'Grid must preserve style contrast when scaling gradient colors' }
if ($shader -notmatch 'grass_variant_height') { throw 'Shader must use per-variant height' }
if ($shader -notmatch 'mix\(grass_root_color') { throw 'Shader must mix root color into albedo' }
Write-Output 'FrontYard leaf gradient contract passed.'
