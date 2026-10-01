param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw }
$engine = Source 'src/server/Combat/CombatEngine.lua'
$combatConfig = Source 'src/server/Config/CombatConfig.lua'
$stageConfig = Source 'src/server/Config/StageConfig.lua'
$service = Source 'src/server/Services/CombatService.lua'
$engineSpec = Source 'src/server/Tests/CombatEngine.spec.lua'
$serviceSpec = Source 'src/server/Tests/CombatService.spec.lua'

# Vrais modules (moteur pur, configs, service) ; le service recoit des doubles explicites
# des API moteur, de DataService et de ZoneService. Aucun acces a Studio ou DataStore.
$runner = "local CombatEngine = (function()`n$engine`nend)()`n" +
	"local combatConfig = (function()`n$combatConfig`nend)()`n" +
	"local stageConfig = (function()`n$stageConfig`nend)()`n" +
	"local function createService(env)`n    local game, script, require, Instance, Random, Vector3, CFrame, task = env.game, env.script, env.require, env.Instance, env.Random, env.Vector3, env.CFrame, env.task`n$service`nend`n" +
	"local ok1, err1 = pcall((function()`n$engineSpec`nend)(), CombatEngine, combatConfig, stageConfig)`n" +
	"local ok2, err2 = pcall((function()`n$serviceSpec`nend)(), createService, CombatEngine, combatConfig, stageConfig)`n" +
	"if not ok1 then error(err1) end`nif not ok2 then error(err2) end`n"
$runnerPath = Join-Path $testBuild 'combat-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Combat tests failed (exit $LASTEXITCODE)" }
