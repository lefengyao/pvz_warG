$frontYard = $PSScriptRoot
$brickRoot = Join-Path $frontYard '..\..\Assets\Textures\Road\Brick'
$shaderPath = Join-Path $brickRoot 'stylized_brick.gdshader'
$stoneMaterialPath = Join-Path $brickRoot 'brick_stone_material.tres'
$crackMaterialPath = Join-Path $brickRoot 'brick_crack_material.tres'
$frontYardScene = Get-Content -LiteralPath (Join-Path $frontYard 'FrontYard.tscn') -Raw

foreach ($path in @($shaderPath, $stoneMaterialPath, $crackMaterialPath)) {
	if (-not (Test-Path -LiteralPath $path)) { throw "Missing reusable brick material resource: $path" }
}

$shader = Get-Content -LiteralPath $shaderPath -Raw
$stoneMaterial = Get-Content -LiteralPath $stoneMaterialPath -Raw
$crackMaterial = Get-Content -LiteralPath $crackMaterialPath -Raw

foreach ($identifier in @('shader_type spatial', 'surface_is_crack', 'stone_color', 'grain_color', 'grain_scale', 'grain_strength', 'crack_color', 'damage_contrast', 'ALBEDO', 'ROUGHNESS', 'SPECULAR')) {
	if ($shader -notmatch [regex]::Escape($identifier)) { throw "Brick shader is missing $identifier" }
}
if ($shader -match 'unshaded|EMISSION') { throw 'Brick shader must use regular PBR lighting without emission' }
if ($stoneMaterial -notmatch 'surface_is_crack = false' -or $crackMaterial -notmatch 'surface_is_crack = true') { throw 'Stone and crack material modes are not separated' }

foreach ($name in @('a', 'b', 'c', 'd', 'e')) {
	$scene = Get-Content -LiteralPath (Join-Path $brickRoot "brick_$name.tscn") -Raw
	if ($scene -notmatch 'brick_stone_material\.tres' -or $scene -notmatch 'brick_crack_material\.tres') { throw "brick_$name does not reference both shared materials" }
	if ($scene -notmatch 'surface_material_override/0' -or $scene -notmatch 'surface_material_override/1') { throw "brick_$name does not override both mesh surfaces" }
}

$expectedPositions = @()
for ($index = 0; $index -lt 18; $index++) {
    $x = -8.5 + $index
    $expectedPositions += @{ Name = 'Brick_Bottom_{0:D2}' -f ($index + 1); X = $x; Z = -5.5; Parent = 'Row_Bottom' }
    $expectedPositions += @{ Name = 'Brick_Top_{0:D2}' -f ($index + 1); X = $x; Z = 5.5; Parent = 'Row_Top' }
}
for ($index = 0; $index -lt 8; $index++) {
    $z = -3.5 + $index
    $expectedPositions += @{ Name = 'Brick_Left_{0:D2}' -f ($index + 1); X = -9.5; Z = $z; Parent = 'Column_Left' }
    $expectedPositions += @{ Name = 'Brick_Right_{0:D2}' -f ($index + 1); X = 9.5; Z = $z; Parent = 'Column_Right' }
}
$expectedPositions += @{ Name = 'Brick_Left_Bottom'; X = -9.5; Z = -4.5; Parent = 'Column_Left' }
$expectedPositions += @{ Name = 'Brick_Right_Bottom'; X = 9.5; Z = -4.5; Parent = 'Column_Right' }
$expectedPositions += @{ Name = 'Brick_Left_Top'; X = -9.5; Z = 4.5; Parent = 'Column_Left' }
$expectedPositions += @{ Name = 'Brick_Right_Top'; X = 9.5; Z = 4.5; Parent = 'Column_Right' }
$expectedPositions += @{ Name = 'Brick_Corner_BottomLeft'; X = -9.5; Z = -5.5; Parent = 'Corners' }
$expectedPositions += @{ Name = 'Brick_Corner_BottomRight'; X = 9.5; Z = -5.5; Parent = 'Corners' }
$expectedPositions += @{ Name = 'Brick_Corner_TopLeft'; X = -9.5; Z = 5.5; Parent = 'Corners' }
$expectedPositions += @{ Name = 'Brick_Corner_TopRight'; X = 9.5; Z = 5.5; Parent = 'Corners' }
for ($index = 0; $index -lt 12; $index++) {
    $z = -5.5 + $index
    $expectedPositions += @{ Name = 'Brick_Left_Outer_{0:D2}' -f ($index + 1); X = -10.5; Z = $z; Parent = 'Column_Left_Outer' }
}

foreach ($name in @('a', 'b', 'c', 'd', 'e')) {
    if ($frontYardScene -notmatch "brick_$name\.tscn") { throw "FrontYard does not reference brick_$name for the perimeter layout" }
}

foreach ($groupName in @('Row_Bottom', 'Row_Top', 'Column_Left', 'Column_Right', 'Column_Left_Outer', 'Corners')) {
    if ($frontYardScene -notmatch ('\[node name="' + [regex]::Escape($groupName) + '" type="Node3D" parent="Background/Decorations/Brick"')) {
        throw "Missing brick layout container: $groupName"
    }
}

$brickNodeMatches = [regex]::Matches($frontYardScene, '(?ms)^\[node name="(?<name>Brick_(?:(?:Bottom|Top|Left|Right)_\d{2}|(?:Left|Right)_(?:Bottom|Top)|Left_Outer_\d{2}|Corner_(?:BottomLeft|BottomRight|TopLeft|TopRight)))" parent="Background/Decorations/Brick/(?:Row_Bottom|Row_Top|Column_Left|Column_Right|Column_Left_Outer|Corners)"[^\]]*\](?<body>.*?)(?=^\[node |\z)')
if ($brickNodeMatches.Count -ne 72) { throw "FrontYard must contain 72 grouped brick instances including the left outer row, found $($brickNodeMatches.Count)" }

$brickNodes = @{}
$variantReferences = @{}
foreach ($match in $brickNodeMatches) {
    $name = $match.Groups['name'].Value
    $brickNodes[$name] = $match.Value
    $variant = [regex]::Match($match.Value, 'instance=ExtResource\("(?<id>[^"]+)"\)').Groups['id'].Value
    if (-not [string]::IsNullOrWhiteSpace($variant)) { $variantReferences[$variant] = $true }
}
if ($variantReferences.Count -ne 5) { throw "Perimeter layout must use all five brick variants, found $($variantReferences.Count)" }

foreach ($expected in $expectedPositions) {
    if (-not $brickNodes.ContainsKey($expected.Name)) { throw "Missing perimeter brick node: $($expected.Name)" }
    $expectedParent = 'parent="Background/Decorations/Brick/' + $expected.Parent + '"'
    if ($brickNodes[$expected.Name] -notmatch [regex]::Escape($expectedParent)) { throw "$($expected.Name) must be grouped under $($expected.Parent)" }
    $transform = [regex]::Match($brickNodes[$expected.Name], 'transform = Transform3D\([^\r\n]+\)').Value
    if ($transform -notmatch '^transform = Transform3D\(1, 0, 0, 0, -4\.371139e-08, -1, 0, 1, -4\.371139e-08,') { throw "$($expected.Name) must use the upward-facing +90 degree X rotation" }
    $translation = [regex]::Match($transform, ',\s*(?<x>-?\d+(?:\.\d+)?)\s*,\s*(?<height>-?\d+(?:\.\d+)?)\s*,\s*(?<z>-?\d+(?:\.\d+)?)\)$')
    if (-not $translation.Success) { throw "Could not read transform for $($expected.Name)" }
    $x = [double]$translation.Groups['x'].Value
    $height = [double]$translation.Groups['height'].Value
    $z = [double]$translation.Groups['z'].Value
    if ([math]::Abs($x - [double]$expected.X) -gt 0.0001 -or [math]::Abs($z - [double]$expected.Z) -gt 0.0001) { throw "$($expected.Name) is not at the requested coordinate ($($expected.X), $($expected.Z))" }
    if ([math]::Abs($height - 0.01) -gt 0.0001) { throw "$($expected.Name) must keep the brick height at 0.01" }
}

Write-Output 'FrontYard reusable brick material contract passed.'
