$gridPath = Join-Path $PSScriptRoot 'Background\Grass\lawn_grid.gd'
$source = Get-Content -LiteralPath $gridPath -Raw

foreach ($property in @('rows', 'columns', 'cell_size', 'settings', 'editor_preview')) {
    $setter = [regex]::Match($source, "(?s)@export[^\n]*var $property.*?:.*?(?=\n@export|\nvar |\nfunc )").Value
    if (-not $setter) { throw "Could not locate setter for $property" }
    if ($setter -notmatch "if .*==") { throw "Setter for $property must skip unchanged values" }
}

Write-Output 'FrontYard lawn rebuild guard contract passed.'
