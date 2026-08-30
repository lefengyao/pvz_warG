$root = $PSScriptRoot
$grassRoot = Join-Path $root 'Background\Grass'
$grid = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$gridScene = Get-Content -LiteralPath (Join-Path $grassRoot 'LawnGrid.tscn') -Raw
$chunk = Join-Path $grassRoot 'lawn_render_chunk.gd'
$chunkScene = Join-Path $grassRoot 'LawnRenderChunk.tscn'
$shader = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell_grass.gdshader') -Raw
$runtime = Get-Content -LiteralPath (Join-Path $root 'front_yard_lawn_runtime_test.gd') -Raw

if ($grid -notmatch 'render_chunk_rows' -or $grid -notmatch 'render_chunk_columns') {
    throw 'LawnGrid must expose independent render chunk dimensions'
}
if ($grid -notmatch 'render_chunk_rows: int = 3' -or $grid -notmatch 'render_chunk_columns: int = 3') {
    throw 'Default render chunk dimensions must be 3 by 3'
}
if ($gridScene -notmatch 'render_chunk_rows = 3' -or $gridScene -notmatch 'render_chunk_columns = 3') {
    throw 'LawnGrid scene must serialize the default render chunk dimensions'
}
if (-not (Test-Path -LiteralPath $chunk)) { throw 'LawnRenderChunk script is missing' }
if (-not (Test-Path -LiteralPath $chunkScene)) { throw 'LawnRenderChunk scene is missing' }
$chunkSource = Get-Content -LiteralPath $chunk -Raw
$chunkSceneSource = Get-Content -LiteralPath $chunkScene -Raw
if ($chunkSource -notmatch 'class_name LawnRenderChunk') { throw 'LawnRenderChunk class name is missing' }
if ($chunkSource -notmatch 'func rebuild\(' -or $chunkSource -notmatch 'MultiMeshInstance3D') {
    throw 'LawnRenderChunk must rebuild MultiMeshInstance3D children'
}
if ($chunkSceneSource -notmatch 'lawn_render_chunk\.gd') { throw 'LawnRenderChunk scene is not bound to its script' }
if ($shader -notmatch 'MODEL_MATRIX' -or $shader -notmatch 'INSTANCE_CUSTOM\.rg') {
    throw 'Merged grass clipping must use transformed world position and per-instance cell center'
}
if ($runtime -notmatch 'render_chunks' -or $runtime -notmatch 'chunk') {
    throw 'Runtime test must validate chunk-level rendering'
}
if ($runtime -notmatch 'get_render_chunk_count' -or $runtime -notmatch 'get_render_instance_count') {
    throw 'Runtime test must validate aggregate chunk counts'
}
Write-Output 'FrontYard render chunk contract passed.'
