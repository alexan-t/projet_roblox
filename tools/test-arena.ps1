param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
$rules = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Arena/ArenaRules.lua') -Raw
$stage = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Config/StageConfig.lua') -Raw
$arena = Get-Content -LiteralPath (Join-Path $repoRoot 'src/shared/Config/ArenaConfig.lua') -Raw
$spec = Get-Content -LiteralPath (Join-Path $repoRoot 'src/server/Tests/ArenaRules.spec.lua') -Raw

# Modules purs (aucune API Roblox) : executes tels quels.
$runnerSource = "local ArenaRules = (function()`n$rules`nend)()`n" +
	"local stageConfig = (function()`n$stage`nend)()`n" +
	"local arenaConfig = (function()`n$arena`nend)()`n" +
	"local runTests = (function()`n$spec`nend)()`nrunTests(ArenaRules, stageConfig, arenaConfig)`n"
$runnerPath = Join-Path $testBuild 'arena-rules-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "ArenaRules tests failed (exit $LASTEXITCODE)" }
