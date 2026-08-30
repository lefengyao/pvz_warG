$root = Split-Path $PSScriptRoot -Parent
$grassRoot = Join-Path $PSScriptRoot 'Background\Grass'
$settingsPath = Join-Path $grassRoot 'lawn_grass_settings.gd'
$cellPath = Join-Path $grassRoot 'lawn_cell.gd'
$gridPath = Join-Path $grassRoot 'lawn_grid.gd'
$rootPath = Join-Path $PSScriptRoot 'front_yard.gd'
$gridScenePath = Join-Path $grassRoot 'LawnGrid.tscn'
$cellScenePath = Join-Path $grassRoot 'LawnCell.tscn'
$settingsScenePath = Join-Path $grassRoot 'LawnGrassSettings.tres'

if (-not (Test-Path $settingsPath)) { throw 'LawnGrassSettings script is missing' }
if (-not (Test-Path $settingsScenePath)) { throw 'Default LawnGrassSettings resource is missing' }
if (-not (Test-Path $cellPath)) { throw 'LawnCell script is missing' }
if (-not (Test-Path $gridPath)) { throw 'LawnGrid script is missing' }
if (-not (Test-Path $gridScenePath)) { throw 'LawnGrid scene is missing' }
if (-not (Test-Path $cellScenePath)) { throw 'LawnCell scene is missing' }

$settings = Get-Content -LiteralPath $settingsPath -Raw
$cell = Get-Content -LiteralPath $cellPath -Raw
$grid = Get-Content -LiteralPath $gridPath -Raw
$rootSource = Get-Content -LiteralPath $rootPath -Raw
$gridScene = Get-Content -LiteralPath $gridScenePath -Raw
$cellScene = Get-Content -LiteralPath $cellScenePath -Raw

if ($settings -notmatch 'extends Resource') { throw 'LawnGrassSettings must be a Resource' }
if ($settings -notmatch 'class_name LawnGrassSettings') { throw 'LawnGrassSettings class name is missing' }
if ($settings -notmatch 'stylized_lawn_demo\.glb') { throw 'Default model asset moved out of settings' }
if ($settings -notmatch 'var model_clumps_per_cell: int = 25') { throw 'Default model density is missing from settings' }
if ($settings -notmatch 'var density_noise_strength: float = 0\.35') { throw 'Density noise strength is not exposed' }
if ($settings -notmatch 'var height_noise_strength: float = 0\.20') { throw 'Height noise strength is not exposed' }
if ($settings -notmatch 'func make_signature') { throw 'Settings signature is missing' }

if ($cell -notmatch 'class_name LawnCell') { throw 'LawnCell class name is missing' }
if ($cell -notmatch 'var density_override: int = -1') { throw 'LawnCell density override is missing' }
if ($cell -notmatch 'var style_override: int = -1') { throw 'LawnCell style override is missing' }
if ($cell -notmatch 'var height_multiplier: float = 1\.0') { throw 'LawnCell height override is missing' }
if ($cell -notmatch 'func configure\(' -or $cell -notmatch 'func rebuild\(') { throw 'LawnCell configure/rebuild API is missing' }
if ($cell -notmatch 'GrassRenderer') { throw 'LawnCell must own a GrassRenderer child' }
if ($cell -notmatch 'get_model_instance_batches' -or $cell -notmatch 'transforms_by_variant') { throw 'LawnCell must generate cached model instance batches' }
if ($grid -notmatch 'render_chunks|_rebuild_render_chunk') { throw 'LawnGrid must own merged MultiMesh render chunks' }
if ($cell -notmatch 'FastNoiseLite') { throw 'LawnCell must consume shared FastNoiseLite instances' }

if ($grid -notmatch '@tool') { throw 'LawnGrid must run in the editor' }
if ($grid -notmatch 'class_name LawnGrid') { throw 'LawnGrid class name is missing' }
if ($grid -notmatch 'func rebuild_all_cells') { throw 'LawnGrid full rebuild API is missing' }
if ($grid -notmatch 'func rebuild_cell') { throw 'LawnGrid local rebuild API is missing' }
if ($grid -notmatch 'func set_cell_grass_density' -or $grid -notmatch 'func set_cell_grass_style') { throw 'LawnGrid compatibility APIs are missing' }
if ($grid -notmatch 'FastNoiseLite') { throw 'LawnGrid must create shared noise objects' }
if ($grid -notmatch 'model_grass_scene|model_scene') { throw 'Model resource should be loaded by LawnGrid' }
if ($grid -match 'GrassRenderer.*parent="\."') { throw 'Generated grass must not be a direct FrontYard child' }

if ($gridScene -notmatch 'lawn_grid\.gd') { throw 'LawnGrid scene is not bound to lawn_grid.gd' }
if ($cellScene -notmatch 'lawn_cell\.gd') { throw 'LawnCell scene is not bound to lawn_cell.gd' }
if ($rootSource -match '_build_model_grass_chunks|_build_grass_chunks|_model_grass_meshes|chunk_nodes') { throw 'FrontYard still owns grass generation or caches' }
if ($rootSource -notmatch 'LawnGrid') { throw 'FrontYard does not reference LawnGrid' }
if ($rootSource -notmatch 'lawn_grid\.set_cell_grass_density|lawn_grid\.set_cell_grass_style') { throw 'FrontYard does not forward cell APIs' }

Write-Output 'FrontYard lawn architecture contract passed.'
