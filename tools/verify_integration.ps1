param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [string]$PythonPath = 'python',
    [switch]$Capture
)
$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'

# Reuse the strict import/reference/main/2D flow gates and log checker.
. (Join-Path $PSScriptRoot 'verify_project.ps1') -GodotPath $GodotPath -PythonPath $PythonPath

& $PythonPath (Join-Path $projectRoot 'tests/integration_layout_test.py')
if ($LASTEXITCODE -ne 0) { throw 'Integration layout contract failed' }

$contracts = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests/3d/front_yard') -Filter '*.ps1'
foreach ($contract in $contracts) { & $contract.FullName }

Invoke-GodotCheck -Name 'grass_runtime' -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/3d/front_yard/front_yard_lawn_optimization_runtime_test.gd')
Invoke-GodotCheck -Name 'shared_settings' -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/shared/setting_scene_structure_test.gd')
Invoke-GodotCheck -Name 'integration_scenes' -Arguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/integration_scene_smoke.gd')

$ecsLog = Join-Path $logRoot 'ecsmini.log'
& $PythonPath (Join-Path $projectRoot 'addons/ecsmini/tests/run_tests.py') --godot $engineExecutable *> $ecsLog
if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $ecsLog -Tail 25; throw "ECSmini verification failed: $ecsLog" }
Write-Host 'PASS: ECSmini contracts, examples and both correctness benchmarks'

if ($Capture) {
    Invoke-GodotCheck -Name 'integration_graphics' -Arguments @('--path', $projectRoot, '--resolution', '960x540', '--script', 'res://tests/integration_scene_smoke.gd', '--', '--capture')
    Invoke-GodotCheck -Name 'project_graphics' -Arguments @('--path', $projectRoot, '--resolution', '960x540', '--scene', 'res://tests/project_smoke.tscn', '--', '--capture')
}
Write-Host "PASS: integration ($($contracts.Count) FrontYard contracts)"
