$integrationRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$frontYardModule = Join-Path $integrationRoot '3d/scenes/maps/front_yard'
$root = $frontYardModule
$grassRoot = Join-Path $root 'Background\Grass'
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$shader = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell_grass.gdshader') -Raw
$checklist = Get-Content -LiteralPath (Join-Path $integrationRoot 'docs/maintenance/lawn_optimization_checklist.md') -Raw -Encoding UTF8

if ($grid -notmatch 'func _get_render_chunk_aabb') { throw 'Chunk AABB calculation must remain identifiable for regression testing' }
if ($grid -notmatch 'func _render_signature') { throw 'Render signature API must remain available' }
if ($grid -notmatch 'func _merge_transformed_aabb') { throw 'Chunk bounds must be based on transformed model bounds' }
if ($grid -notmatch 'func _expand_aabb_xz') { throw 'Chunk bounds must reserve horizontal wind displacement' }
if ($grid -match 'model_grass_scale \* 1\.12 \* 3\.0') { throw 'The unconditional 3x chunk-height inflation must be removed' }
if ($grid -notmatch 'var wind_margin := absf\(settings\.grass_wind_strength\)') { throw 'Wind margin must use the world-space wind displacement' }
if ($grid -notmatch '_render_dirty' -or $grid -notmatch '_get_normalized_wind_direction') {
    throw 'Grass optimization seams are not implemented yet'
}
if ($grid -notmatch 'settings\.changed\.connect|changed\.connect') { throw 'LawnGrid must react to settings resource changes' }
if ($grid -notmatch '_signature_poll_elapsed|SIGNATURE_POLL_INTERVAL') { throw 'LawnGrid must retain a bounded fallback poll for unsignaled resource edits' }
if ($grid -match '_last_signature != _render_signature\(\)') {
    throw 'LawnGrid must not build the complete signature every editor frame'
}
if ($shader -notmatch 'MODEL_MATRIX' -or $shader -notmatch 'INSTANCE_CUSTOM\.rg') {
    throw 'Merged-cell world clipping data must remain intact'
}
if ($shader -notmatch 'sin\(' -or $shader -notmatch 'cos\(' -or $shader -notmatch 'pow\(') {
    throw 'Wind and stylized band shaping must remain available for visual parity'
}
if ($shader -notmatch 'SPECULAR_LIGHT\s*=\s*vec3\(0\.0\)') {
    throw 'Zero specular lighting must remain part of the grass material'
}
if ($grid -notmatch '_get_normalized_wind_direction') {
    throw 'Wind direction normalization must move to material preparation'
}
if ($shader -notmatch 'cull_disabled' -or $shader -notmatch 'discard' -or $shader -notmatch 'void light\(') {
    throw 'Grass clipping, two-sided rendering, and custom lighting must remain in one shader path'
}
if ($shader -notmatch 'grass_wind_animated' -or $shader -notmatch 'grass_gradient_strength' -or $shader -notmatch 'grass_highlight_strength') {
    throw 'Existing grass visual controls must remain exposed'
}
$compatibilityClause = -join ([char[]](0x4e0d, 0x5f97, 0x7834, 0x574f, 0x539f, 0x6709, 0x529f, 0x80fd, 0x548c, 0x4ee3, 0x7801))
if ($checklist -notmatch [regex]::Escape($compatibilityClause)) { throw 'Optimization checklist must declare the compatibility constraint' }

Write-Output 'FrontYard grass optimization baseline contract passed.'
