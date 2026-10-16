param([switch]$Strict, [string]$UiDir)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
# -UiDir : autre dossier à contrôler (jeux d'essai de tests/ui-captures.test.mjs).
$uiDir = if ($UiDir) { $UiDir } else { Join-Path $repoRoot 'docs/references/ui' }
$screensDir = Join-Path $uiDir 'ecrans'

# Inventaire des écrans (docs/references/ui/README.md § 3) contre les fichiers de docs/references/ui/ecrans.
# Erreur : numéro ou fichier en double, mauvais nom, écran « capturé » sans fichier, fichier hors inventaire.
# -Strict : erreur aussi s'il reste des écrans « à capturer ».
# Messages et motifs sans accent : le script tourne aussi sous Windows PowerShell 5.1 (fichier sans BOM).
$rows = @(Get-Content -LiteralPath (Join-Path $uiDir 'README.md') -Encoding UTF8 | Where-Object { $_ -match '^\| \d' })
$problems = @()
$todo = @()
$numbers = @{}
$files = @{}
foreach ($row in $rows) {
	$cells = $row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }
	$number, $file, $state = $cells[0], $cells[1].Trim('`'), $cells[-1]
	if ($number -notmatch '^\d{2}$') { $problems += "invalid number: $number"; continue }
	if ($file -notmatch "^${number}_[a-z0-9_]+\.png$") { $problems += "${number}: invalid file name ($file)" }
	if ($numbers.ContainsKey($number)) { $problems += "${number}: duplicate number" }
	if ($files.ContainsKey($file)) { $problems += "${file}: duplicate file" }
	$numbers[$number] = $true
	$files[$file] = $true
	$present = Test-Path -LiteralPath (Join-Path $screensDir $file)
	if ($state -match '^captur\S+ \d{4}-\d{2}-\d{2}$') {
		if (-not $present) { $problems += "${number}: marked as captured but ecrans/$file is missing" }
	} elseif ($state -match '^\S capturer$') {
		$todo += "$number $file"
	} else {
		$problems += "${number}: invalid state ($state)"
	}
}
if ($rows.Count -eq 0) { $problems += 'screen inventory is empty or unreadable' }
if (Test-Path -LiteralPath $screensDir) {
	Get-ChildItem -LiteralPath $screensDir -File | Where-Object { $_.Name -ne '.gitkeep' -and -not $files.ContainsKey($_.Name) } |
		ForEach-Object { $problems += "$($_.Name): file not in the inventory" }
}

Write-Output "Screens in inventory: $($rows.Count), still to capture: $($todo.Count)"
$todo | ForEach-Object { Write-Output "  to capture: $_" }
if ($Strict -and $todo.Count -gt 0) { $problems += "$($todo.Count) screen(s) still to capture" }
if ($problems.Count -gt 0) {
	$problems | ForEach-Object { Write-Output "ERROR: $_" }
	throw "UI captures check failed ($($problems.Count) problem(s))"
}
Write-Output 'UI captures check passed'
