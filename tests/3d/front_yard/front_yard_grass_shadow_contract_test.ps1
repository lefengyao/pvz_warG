$integrationRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$frontYardModule = Join-Path $integrationRoot '3d/scenes/maps/front_yard'
$grassRoot = Join-Path $frontYardModule 'Background\Grass'
$settings = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$resource = Get-Content -LiteralPath (Join-Path $grassRoot 'LawnGrassSettings.tres') -Raw
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$chunk = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_render_chunk.gd') -Raw

if ($settings -notmatch '@export var grass_cast_shadow: bool = true') {
    throw 'LawnGrassSettings must expose grass_cast_shadow with shadows enabled by default'
}
if ($settings -notmatch 'str\(grass_cast_shadow\)') {
    throw 'Grass shadow mode must participate in the settings signature'
}
if ($resource -notmatch 'grass_cast_shadow\s*=\s*true') {
    throw 'Default LawnGrassSettings resource must serialize grass_cast_shadow'
}
if ($grid -notmatch 'settings\.grass_cast_shadow') {
    throw 'LawnGrid must pass grass_cast_shadow to render chunks'
}
if ($chunk -notmatch 'grass_cast_shadow: bool') {
    throw 'LawnRenderChunk rebuild must accept grass_cast_shadow'
}
if ($chunk -notmatch 'SHADOW_CASTING_SETTING_ON' -or $chunk -notmatch 'SHADOW_CASTING_SETTING_OFF') {
    throw 'LawnRenderChunk must map grass_cast_shadow to ON/OFF shadow casting'
}

Write-Output 'FrontYard grass shadow contract passed.'
