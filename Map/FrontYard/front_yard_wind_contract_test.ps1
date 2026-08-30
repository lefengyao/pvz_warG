$root = $PSScriptRoot
$grassRoot = Join-Path $root 'Background\Grass'
$settings = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$resource = Get-Content -LiteralPath (Join-Path $grassRoot 'LawnGrassSettings.tres') -Raw
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$cell = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell.gd') -Raw
$shader = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell_grass.gdshader') -Raw

foreach ($name in @('grass_wind_strength', 'grass_wind_animated', 'grass_wind_speed', 'grass_wind_frequency', 'grass_wind_direction')) {
    if ($settings -notmatch $name) { throw "Settings is missing $name" }
    if ($grid -notmatch ('set_shader_parameter\("' + $name + '"')) { throw "Grid does not synchronize $name" }
    if ($shader -notmatch $name) { throw "Shader is missing $name" }
}
if ($resource -notmatch 'grass_wind_animated\s*=') { throw 'Default resource does not serialize wind animation mode' }
if ($settings -notmatch 'var grass_wind_strength: float = 0\.035') { throw 'Settings default wind strength is missing' }
if ($settings -notmatch 'var grass_wind_speed: float = 1\.1') { throw 'Settings default wind speed is missing' }
if ($settings -notmatch 'var grass_wind_frequency: float = 1\.4') { throw 'Settings default wind frequency is missing' }
if ($settings -notmatch 'var grass_wind_direction: Vector2 = Vector2\(1\.0, 0\.25\)') { throw 'Settings default wind direction is missing' }
if ($shader -notmatch '\bTIME\b') { throw 'Shader does not animate wind over time' }
if ($shader -notmatch 'if\s*\(grass_wind_animated\)') { throw 'Shader does not support static wind mode' }
if ($shader -notmatch 'INSTANCE_CUSTOM\.rg' -or $shader -notmatch 'INSTANCE_CUSTOM\.b') {
    throw 'Shader does not vary wind phase per grass clump'
}
if ($shader -notmatch 'VERTEX\.xz\s*\+=\s*wind_offset') { throw 'Shader does not displace grass vertices' }
if ($shader -notmatch 'smoothstep\(0\.05,\s*1\.0,\s*grass_height_value\)') {
    throw 'Shader does not anchor wind at the grass roots'
}
if ($cell -notmatch 'grass_wind_strength' -or $cell -notmatch 'wind_margin') {
    throw 'LawnCell custom AABB does not reserve space for wind displacement'
}
Write-Output 'FrontYard wind contract passed.'
