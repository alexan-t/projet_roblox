param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Catalogue des items (pur) : vraie ItemConfig contre docs/ITEMS.md § 2 et la vraie RarityConfig.
$runner = "local ItemConfig = $(Module 'src/shared/Config/ItemConfig.lua')`n" +
	"local RarityConfig = $(Module 'src/shared/Config/RarityConfig.lua')`n" +
	"local ok, err = pcall($(Module 'src/server/Tests/ItemConfig.spec.lua'), ItemConfig, RarityConfig)`n" +
	"if not ok then error(err) end`n"
$runnerPath = Join-Path $testBuild 'item-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Item tests failed (exit $LASTEXITCODE)" }
