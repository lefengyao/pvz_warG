$frontYard = $PSScriptRoot
$grassRoot = Join-Path $frontYard 'Background\Grass'
$settingsSource = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grass_settings.gd') -Raw
$cellSource = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_cell.gd') -Raw
$gridSource = Get-Content -LiteralPath (Join-Path $grassRoot 'lawn_grid.gd') -Raw
$resourceSource = Get-Content -LiteralPath (Join-Path $grassRoot 'LawnGrassSettings.tres') -Raw

$forbidden = @(
    ('use_' + 'simple_grass_plugin'),
    ('pl' + 'ugin_' + 'grass'),
    ('simple' + 'grasstextured'),
    ('Plugin' + 'Grass'),
    ('Ribbon' + 'Grass'),
    ('_build_' + 'pl' + 'ugin_grass'),
    ('_build_' + 'ribbon_grass'),
    ('_make_' + 'ribbon_mesh')
)
foreach ($source in @($settingsSource, $cellSource, $gridSource, $resourceSource)) {
    foreach ($identifier in $forbidden) {
        if ($source -match [regex]::Escape($identifier)) {
            throw "Forbidden non-model grass identifier remains: $identifier"
        }
    }
}

$rebuild = [regex]::Match($cellSource, '(?s)func rebuild\(\).*?(?=\nfunc )').Value
if (-not $rebuild) { throw 'LawnCell rebuild function is missing' }
if ($rebuild -notmatch '_build_model_grass\(\)') { throw 'LawnCell rebuild must call model grass generation' }
if ($rebuild -match 'elif|else:') { throw 'LawnCell rebuild must not select a fallback grass mode' }
if ($gridSource -match 'settings\.[A-Za-z_]*plugin|use_plugin') { throw 'LawnGrid still branches on plugin state' }
if ($settingsSource -notmatch 'var model_scene') { throw 'Model scene setting is missing' }
if ($resourceSource -notmatch 'stylized_lawn_demo\.glb') { throw 'Default model grass resource is missing' }

Write-Output 'FrontYard model-only grass contract passed.'
