param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Loot (#72, pur) : vraie LootConfig + vraies LootRules contre les vrais catalogues ItemConfig /
# ResourceConfig / RarityConfig. Invariants de zone, determinisme a graine, garanties, validation.
$runner = "local catalogs = { Item = $(Module 'src/shared/Config/ItemConfig.lua'), Resource = $(Module 'src/shared/Config/ResourceConfig.lua'), Rarity = $(Module 'src/shared/Config/RarityConfig.lua') }`n" +
	"local ok, err = pcall($(Module 'src/server/Tests/LootRules.spec.lua'), $(Module 'src/server/Loot/LootRules.lua'), $(Module 'src/server/Config/LootConfig.lua'), catalogs)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'loot-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Loot tests failed (exit $LASTEXITCODE)" }
