param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [string]$PythonPath = 'python'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineExecutable = (Resolve-Path -LiteralPath $GodotPath).Path
$logRoot = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments, [switch]$RetryFontWarmup)
    $outputFile = Join-Path $logRoot "$Name.log"
    & $engineExecutable @Arguments *> $outputFile
    $engineExitCode = $LASTEXITCODE
    Get-Content -LiteralPath $outputFile -Tail 18
    $diagnostics = Select-String -LiteralPath $outputFile -Pattern 'SCRIPT ERROR:|ERROR:|WARNING:|invalid UID|failed to load|Failed loading'
    # Godot initializes the project font before the first asset import. A fresh
    # checkout has no .fontdata yet. Preserve that log and require a clean second
    # import; never retry unrelated resource/script errors or any warning.
    $fontMetadata = Get-Content -LiteralPath (Join-Path $projectRoot 'shared/assets/fonts/Silver.ttf.import') -Raw
    $fontCacheMatch = [regex]::Match($fontMetadata, '(?m)^path="(res://\.godot/imported/[^"\r\n]+\.fontdata)"$')
    $fontCachePattern = if ($fontCacheMatch.Success) { [regex]::Escape($fontCacheMatch.Groups[1].Value) } else { '(?!)' }
    $fontWarmupErrors = @(
        "^ERROR: Cannot open file '$fontCachePattern'\.$",
        "^ERROR: Failed loading resource: $fontCachePattern\.$",
        '^ERROR: Failed loading resource: res://shared/assets/fonts/Silver\.ttf\.$',
        '^ERROR: Error loading custom project font ''res://shared/assets/fonts/Silver\.ttf''$'
    ) -join '|'
    $otherDiagnostics = @($diagnostics | Where-Object { $_.Line -notmatch $fontWarmupErrors })
    $customFontDiagnostic = @($diagnostics | Where-Object { $_.Line -eq "ERROR: Error loading custom project font 'res://shared/assets/fonts/Silver.ttf'" })
    if ($RetryFontWarmup -and $fontCacheMatch.Success -and $engineExitCode -eq 0 -and $customFontDiagnostic.Count -eq 1 -and $otherDiagnostics.Count -eq 0) {
        Copy-Item -LiteralPath $outputFile -Destination (Join-Path $logRoot "$Name.first_import.log") -Force
        Write-Host 'Imported the project font into a cold cache; running strict import again.'
        Invoke-GodotCheck -Name $Name -Arguments $Arguments
        return
    }
    if ($engineExitCode -ne 0 -or $diagnostics) {
        throw "$Name failed (exit $engineExitCode). See $outputFile"
    }
    Write-Host "PASS: $Name"
}

Invoke-GodotCheck -Name 'editor_import' -Arguments @('--headless', '--path', $projectRoot, '--editor', '--import') -RetryFontWarmup
& $PythonPath (Join-Path $PSScriptRoot 'verify_references.py') *> (Join-Path $logRoot 'references.json')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $logRoot 'references.json'); throw 'Resource reference checks failed' }
Get-Content -LiteralPath (Join-Path $logRoot 'references.json')
Invoke-GodotCheck -Name 'main_scene' -Arguments @('--headless', '--path', $projectRoot, '--quit-after', '180')
Invoke-GodotCheck -Name 'project_smoke' -Arguments @('--headless', '--path', $projectRoot, '--scene', 'res://tests/project_smoke.tscn')
Write-Host 'PASS: all resource, import, main scene and gameplay flow checks'
