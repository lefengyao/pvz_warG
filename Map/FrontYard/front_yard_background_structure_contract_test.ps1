$frontYard = $PSScriptRoot
$scenePath = Join-Path $frontYard 'FrontYard.tscn'
$grassRoot = Join-Path $frontYard 'Background\Grass'
$scene = Get-Content -LiteralPath $scenePath -Raw
$frontYardSource = Get-Content -LiteralPath (Join-Path $frontYard 'front_yard.gd') -Raw

foreach ($path in @(
    (Join-Path $grassRoot 'lawn_cell_grass.gdshader'),
    (Join-Path $grassRoot 'lawn_cell.gd'),
    (Join-Path $grassRoot 'lawn_grass_settings.gd'),
    (Join-Path $grassRoot 'lawn_grid.gd'),
    (Join-Path $grassRoot 'lawn_render_chunk.gd'),
    (Join-Path $grassRoot 'LawnCell.tscn'),
    (Join-Path $grassRoot 'LawnGrassSettings.tres'),
    (Join-Path $grassRoot 'LawnGrid.tscn'),
    (Join-Path $grassRoot 'LawnRenderChunk.tscn')
)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Grass resource is not organized under Background/Grass: $path" }
}

foreach ($oldPath in @(
    (Join-Path $frontYard 'board.gdshader'),
    (Join-Path $frontYard 'lawn_cell.gd'),
    (Join-Path $frontYard 'lawn_grid.gd'),
    (Join-Path $frontYard 'LawnGrid.tscn')
)) {
    if (Test-Path -LiteralPath $oldPath) { throw "Legacy grass resource remains beside FrontYard: $oldPath" }
}

$requiredNodes = @(
    '[node name="Background" type="Node3D" parent="."',
    '[node name="Grass" type="Node3D" parent="Background"',
    '[node name="Board" type="Node3D" parent="Background/Grass"',
    '[node name="BoardBase" type="MeshInstance3D" parent="Background/Grass/Board"',
    '[node name="LawnGrid" parent="Background/Grass"',
    '[node name="LawnCell_0_0" parent="Background/Grass/LawnGrid"',
    '[node name="Decorations" type="Node3D" parent="Background"',
    '[node name="AnimatedSprite3D" type="AnimatedSprite3D" parent="."'
)
foreach ($node in $requiredNodes) {
    if ($scene -notmatch [regex]::Escape($node)) { throw "FrontYard scene is missing organized node: $node" }
}

foreach ($identifier in @('_build_border', '_add_border_piece', '_border_material', 'BorderTop', 'front_yard_generated')) {
    if ($frontYardSource -match [regex]::Escape($identifier)) { throw "FrontYard must not generate the removed brown lawn border: $identifier" }
}

if ($scene -match 'board\.gdshader|ShaderMaterial_board') { throw 'BoardBase must not reference the removed board shader material' }
if ($scene -notmatch 'StandardMaterial3D_board' -or $scene -notmatch 'albedo_color = Color\(0\.18, 0\.4, 0\.1, 1\)' -or $scene -notmatch 'roughness = 0\.96') {
    throw 'BoardBase must use the configured StandardMaterial3D lawn material'
}

Write-Output 'FrontYard background/grass structure contract passed.'
