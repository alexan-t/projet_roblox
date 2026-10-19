param(
	[string]$LuauPath = 'luau',
	[int]$Seed = 1,
	[int]$Runs = 200,
	[int]$Players = 1000,
	[ValidateSet('Normal', 'Elite')][string]$Mode = 'Normal',
	[ValidateRange(0, 5)][int]$Stage = 0
)

# Simulation deterministe du loot de la Zone 1 (#72). OUTIL A LA DEMANDE : ni test, ni CI.
# Rejoue les vraies LootRules sur la vraie LootConfig avec un PRNG propre (mulberry32, pas math.random) :
# memes parametres = memes chiffres. Sortie : console + build/loot-sim/loot-sim-<mode>-<stage>-seed<S>-runs<R>.txt.
#   -Seed     graine (defaut 1)              -Runs    victoires par joueur (defaut 200, 1..100000)
#   -Players  joueurs independants (1000)    -Mode    Normal | Elite
#   -Stage    1..5 = ce stage seulement ; 0 (defaut) = cycle 1-1 .. 1-5
# ALPHA 0.0.2 PROVISOIRE : les valeurs de LootConfig sont des placeholders ; ce rapport n'est pas un fait de design.
$ErrorActionPreference = 'Stop'
if ($Runs -lt 1 -or $Runs -gt 100000) { throw 'Runs doit etre entre 1 et 100000' }
if ($Players -lt 1 -or $Players -gt 100000) { throw 'Players doit etre entre 1 et 100000' }
if ($Seed -lt 0) { throw 'Seed doit etre >= 0' }
$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot 'build/loot-sim'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

$runner = "local catalogs = { Item = $(Module 'src/shared/Config/ItemConfig.lua'), Resource = $(Module 'src/shared/Config/ResourceConfig.lua'), Rarity = $(Module 'src/shared/Config/RarityConfig.lua') }`n" +
	"local LootRules = $(Module 'src/server/Loot/LootRules.lua')`n" +
	"local LootConfig = $(Module 'src/server/Config/LootConfig.lua')`n" +
	"local problems = LootRules.problems(LootConfig, catalogs)`n" +
	"if #problems > 0 then error('LootConfig invalide : ' .. table.concat(problems, ' | ')) end`n" +
	"local lines = $(Module 'tools/simulate-loot.luau')(LootRules, LootConfig, catalogs, { Seed = $Seed, Runs = $Runs, Players = $Players, Mode = '$Mode', Stage = $Stage })`n" +
	"for _, text in lines do print(text) end`n"
$runnerPath = Join-Path $repoRoot 'build/loot-sim-runner.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$stageName = if ($Stage -gt 0) { "1-$Stage" } else { 'cycle' }
$outPath = Join-Path $outDir "loot-sim-$($Mode.ToLower())-$stageName-seed$Seed-runs$Runs.txt"
$output = & $LuauPath $runnerPath 2>&1
if ($LASTEXITCODE -ne 0) { throw "Loot simulation failed (exit $LASTEXITCODE): $($output -join "`n")" }
[System.IO.File]::WriteAllText($outPath, (($output -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
$output | ForEach-Object { Write-Output $_ }
Write-Output "Rapport ecrit : $outPath"
