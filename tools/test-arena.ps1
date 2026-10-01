param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw }
$rules = Source 'src/server/Arena/ArenaRules.lua'
$prep = Source 'src/server/Arena/ArenaPrep.lua'
$placement = Source 'src/client/Arena/PlacementState.lua'
$stage = Source 'src/server/Config/StageConfig.lua'
$arena = Source 'src/shared/Config/ArenaConfig.lua'
$rulesSpec = Source 'src/server/Tests/ArenaRules.spec.lua'
$prepSpec = Source 'src/server/Tests/ArenaPrep.spec.lua'
$placementSpec = Source 'src/client/Tests/PlacementState.spec.lua'

# Modules purs (aucune API Roblox) : executes tels quels. ArenaPrep recoit le vrai ArenaRules.
$runnerSource = "local ArenaRules = (function()`n$rules`nend)()`n" +
	"local ArenaPrep = (function()`n    local script, require = { Parent = { ArenaRules = ArenaRules } }, function(m) return m end`n$prep`nend)()`n" +
	"local PlacementState = (function()`n$placement`nend)()`n" +
	"local stageConfig = (function()`n$stage`nend)()`n" +
	"local arenaConfig = (function()`n$arena`nend)()`n" +
	"local ok1, err1 = pcall((function()`n$rulesSpec`nend)(), ArenaRules, stageConfig, arenaConfig)`n" +
	"local ok2, err2 = pcall((function()`n$prepSpec`nend)(), ArenaPrep)`n" +
	"local ok3, err3 = pcall((function()`n$placementSpec`nend)(), PlacementState)`n" +
	"if not ok1 then error(err1) end`nif not ok2 then error(err2) end`nif not ok3 then error(err3) end`n"
$runnerPath = Join-Path $testBuild 'arena-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runnerSource, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Arena tests failed (exit $LASTEXITCODE)" }
