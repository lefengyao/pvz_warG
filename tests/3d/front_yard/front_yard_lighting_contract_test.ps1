$integrationRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$frontYardModule = Join-Path $integrationRoot '3d/scenes/maps/front_yard'
$root = $frontYardModule
$grassRoot = Join-Path $root 'Background\Grass'
$shader = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell_grass.gdshader') -Raw
$settings = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$scene = Get-Content -LiteralPath (Join-Path $root 'FrontYard.tscn') -Raw

if ($shader -match 'render_mode[^;]*\bunshaded\b' -or $shader -match 'ambient_light_disabled') {
    throw 'Grass shader bypasses scene lighting'
}
foreach ($output in @('ALBEDO', 'ROUGHNESS', 'EMISSION', 'DIFFUSE_LIGHT')) {
    if ($shader -notmatch [regex]::Escape($output)) { throw "Grass shader is missing $output" }
}
if ($shader -match 'ALBEDO\s*=\s*vec3\s*\(\s*0' -and $shader -match 'EMISSION\s*=\s*grass_color') {
    throw 'Grass shader appears to replace albedo with emission'
}
if ($shader -notmatch 'render_mode\s+cull_disabled') { throw 'Grass shader must explicitly support two-sided leaf cards' }
if ($shader -notmatch 'abs\s*\(\s*dot\s*\(\s*normalize\(NORMAL\)') { throw 'Two-sided direct lighting is missing' }
if ($shader -notmatch 'grass_normal_up_strength') { throw 'Normal-up control is missing from shader' }
if ($settings -notmatch 'grass_normal_up_strength') { throw 'Normal-up control is missing from settings' }
if ($grid -notmatch 'set_shader_parameter\("grass_normal_up_strength"') { throw 'Grid does not synchronize normal-up control' }
if ($scene -notmatch 'DirectionalLight3D' -or $scene -notmatch 'shadow_enabled\s*=\s*true') { throw 'Directional light or shadows are not enabled' }
if ($scene -notmatch 'ambient_light_energy\s*=\s*0\.6\b') { throw 'Preserve the pre-integration ambient light energy of 0.6' }

Write-Output 'FrontYard lighting contract passed.'
