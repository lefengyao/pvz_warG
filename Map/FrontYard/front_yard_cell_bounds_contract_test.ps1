$frontYard = $PSScriptRoot
$grassRoot = Join-Path $frontYard 'Background\Grass'
$settings = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$cell = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell.gd') -Raw
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$frontYardSource = Get-Content -LiteralPath (Join-Path $frontYard 'front_yard.gd') -Raw
$settingsResource = Get-Content -LiteralPath (Join-Path $grassRoot 'LawnGrassSettings.tres') -Raw
$scene = Get-Content -LiteralPath (Join-Path $frontYard 'FrontYard.tscn') -Raw
$clipShaderPath = Join-Path $grassRoot 'lawn_cell_grass.gdshader'

if (-not (Test-Path -LiteralPath $clipShaderPath)) { throw 'Per-cell grass clipping shader is missing' }
$clipShader = Get-Content -LiteralPath $clipShaderPath -Raw

foreach ($identifier in @('cell_edge_width', 'cell_edge_darkening', 'cell_edge_fraction')) {
    foreach ($source in @($settings, $clipShader, $grid, $frontYardSource, $scene)) {
        if ($source -match $identifier) { throw "Artificial cell-edge shading must not contain $identifier" }
    }
}
foreach ($identifier in @('INSTANCE_CUSTOM', 'cell_size', 'discard')) {
    if ($clipShader -notmatch $identifier) { throw "Cell clipping shader is missing $identifier" }
}
if ($cell -notmatch 'get_model_instance_batches' -or $cell -notmatch 'custom_data_by_variant') { throw 'LawnCell must expose custom data for merged clipping coordinates' }
if ($cell -match '_board_size|board_world_size') { throw 'LawnCell still stores an unused board-size dependency' }
if ($grid -notmatch 'LAWN_GRASS_SHADER|_prepare_grass_materials') { throw 'LawnGrid must own the shared grass clipping materials' }
if ($grid -notmatch '_get_render_chunk_aabb') { throw 'LawnGrid must calculate bounds for merged render chunks' }
if ($grid -match '_model_grass_materials|_prepare_model_materials') { throw 'LawnGrid still owns legacy standard-material caches' }
if ($grid -match 'get_board_size\(\)\s*\)') { throw 'LawnGrid still passes board size into LawnCell configuration' }
if ($frontYardSource -match '_build_board|_make_board_material') { throw 'FrontYard must not generate the board at runtime' }
if ($scene -notmatch '(?s)\[node name="Board".*?\[node name="BoardBase" type="MeshInstance3D" parent="Background/Grass/Board"') { throw 'FrontYard scene must contain a persistent BoardBase node' }
if ($scene -match 'ShaderMaterial_board|board\.gdshader') { throw 'Persistent BoardBase must not use the removed board shader material' }
if ($scene -notmatch 'StandardMaterial3D_board' -or $scene -notmatch 'albedo_color = Color\(0\.18, 0\.4, 0\.1, 1\)' -or $scene -notmatch 'roughness = 0\.96') { throw 'Persistent BoardBase must use the configured StandardMaterial3D lawn material' }
if ($settingsResource -notmatch 'dark_color = Color\(' -or $settingsResource -notmatch 'light_color = Color\(') { throw 'LawnGrassSettings resource must serialize both grass colors' }
if ($scene -notmatch 'rotation_degrees = Vector3\(-30, 0, 0\)' -and $scene -notmatch '0\.8660254, 0\.5, 0, -0\.5, 0\.8660254') { throw 'DirectionalLight3D must pitch down 30 degrees from -Z' }

foreach ($identifier in @('grass_light_wrap', 'grass_highlight_color', 'grass_highlight_strength', 'grass_highlight_threshold', 'grass_highlight_hardness', 'grass_emission_strength')) {
    if ($settings -notmatch $identifier) { throw "LawnGrassSettings is missing material control $identifier" }
    if ($grid -notmatch $identifier) { throw "LawnGrid does not synchronize material control $identifier" }
}
if ($settings -notmatch 'grass_normal_up_strength' -or $grid -notmatch 'grass_normal_up_strength') { throw 'Normal-up lighting control is not exposed and synchronized' }
foreach ($identifier in @('light\s*\(\)', 'DIFFUSE_LIGHT', 'EMISSION', 'COLOR', 'grass_highlight')) {
    if ($clipShader -notmatch $identifier) { throw "Grass material shader is missing $identifier" }
}
foreach ($identifier in @('grass_cell_overflow', 'grass_scale_noise_strength')) {
    if ($settings -notmatch $identifier) { throw "LawnGrassSettings is missing control $identifier" }
    if ($grid -notmatch $identifier -and $cell -notmatch $identifier) { throw "Grass generation does not consume control $identifier" }
}
if ($clipShader -notmatch 'grass_cell_overflow' -or $clipShader -notmatch 'clip_half_size') { throw 'Grass shader does not expose bounded cell overflow clipping' }
if ($clipShader -notmatch 'abs\s*\(\s*dot') { throw 'Grass shader does not use two-sided lighting' }
if ($clipShader -notmatch 'NORMAL\s*=\s*normalize\(mix\(NORMAL,\s*vec3\(0\.0,\s*1\.0,\s*0\.0\)') { throw 'Grass shader does not blend model normals toward up' }
if ($cell -notmatch 'grass_cell_overflow' -or $cell -notmatch 'clip_half_size') { throw 'LawnCell culling AABB does not match expanded grass bounds' }
if ($cell -notmatch 'grass_scale_noise_strength' -or $cell -notmatch 'width_scale') { throw 'LawnCell does not apply overall noise to model scale' }

Write-Output 'FrontYard cell bounds contract passed.'
