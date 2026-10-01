param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw }
$rules = Source 'src/server/Heroes/HeroRules.lua'
$heroConfig = Source 'src/shared/Config/HeroConfig.lua'
$combatConfig = Source 'src/server/Config/CombatConfig.lua'
$spec = Source 'src/server/Tests/HeroRules.spec.lua'

# Modules purs (aucune API Roblox) : executes tels quels.
$runnerSource = "local HeroRules = (function()`n$rules`nend)()`n" +
	"local heroConfig = (function()`n$heroConfig`nend)()`n" +
	"local combatConfig = (function()`n$combatConfig`nend)()`n" +
	"local runTests = (function()`n$spec`nend)()`nrunTests(HeroRules, heroConfig, combatConfig)`n"
$runnerPath = Join-Path $testBuild 'hero-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Hero tests failed (exit $LASTEXITCODE)" }
