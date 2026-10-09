param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }
$wrap = "local game, script, require, Instance, Random, Vector3, CFrame, task = env.game, script or env.script, env.require, env.Instance, env.Random, env.Vector3, env.CFrame, env.task"
function Factory([string]$path) { "function(env, script)`n    $wrap`n$(Source $path)`nend" }

# 1. Suite RewardService : vrai service, vraies RewardRules, vraie RewardConfig, doubles de
#    DataService et des API moteur.
# 2. Integration RewardFlow : vrais CombatEngine, CombatService, ZoneService, QuestService,
#    RewardService et vraies configs ; seuls DataService, PlotService et les API moteur sont des doubles.
$runner = "local RewardRules = $(Module 'src/server/Rewards/RewardRules.lua')`n" +
	"local configs = {`n" +
	"    RewardConfig = $(Module 'src/server/Config/RewardConfig.lua'),`n" +
	"    StageConfig = $(Module 'src/server/Config/StageConfig.lua'),`n" +
	"    QuestConfig = $(Module 'src/server/Config/QuestConfig.lua'),`n" +
	"    CombatConfig = $(Module 'src/server/Config/CombatConfig.lua'),`n" +
	"}`n" +
	"local CombatEngine = $(Module 'src/server/Combat/CombatEngine.lua')`n" +
	"local factories = {`n" +
	"    reward = $(Factory 'src/server/Services/RewardService.lua'),`n" +
	"    quest = $(Factory 'src/server/Services/QuestService.lua'),`n" +
	"    zone = $(Factory 'src/server/Services/ZoneService.lua'),`n" +
	"    combat = $(Factory 'src/server/Services/CombatService.lua'),`n" +
	"}`n" +
	"local ok1, err1 = pcall($(Module 'src/server/Tests/RewardService.spec.lua'), function(env) return factories.reward(env, nil) end, RewardRules, configs.RewardConfig)`n" +
	"local ok2, err2 = pcall($(Module 'src/server/Tests/RewardFlow.spec.lua'), factories, configs, CombatEngine, RewardRules)`n" +
	"if not ok1 then error(err1) end`nif not ok2 then error(err2) end`n"
$runnerPath = Join-Path $testBuild 'reward-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Reward tests failed (exit $LASTEXITCODE)" }
