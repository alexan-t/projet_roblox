param([string]$LuauPath = 'luau', [ValidateSet('all', 'rules', 'migrations', 'summon')][string]$Suite = 'all')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# 1. HeroRules (pur) avec les vraies HeroConfig et CombatConfig.
# 2. Migrations v1 -> v2 (pur).
# 3. HeroService réel (starter, invocation, HeroObtained, modèles client) avec les vraies configs,
#    HeroRules et SummonRules, et des doubles de DataService, PlotService, KingdomService et des API moteur.
$runner = "local HeroRules = $(Module 'src/server/Heroes/HeroRules.lua')`n" +
	"local SummonRules = (function(script, require)`n$(Source 'src/server/Heroes/SummonRules.lua')`nend)({ Parent = { HeroRules = HeroRules } }, function(m) return m end)`n" +
	"local modules = {`n" +
	"    HeroRules = HeroRules, SummonRules = SummonRules,`n" +
	"    HeroConfig = $(Module 'src/shared/Config/HeroConfig.lua'),`n" +
	"    CombatConfig = $(Module 'src/server/Config/CombatConfig.lua'),`n" +
	"    SummonConfig = $(Module 'src/server/Config/SummonConfig.lua'),`n" +
	"    Migrations = $(Module 'src/server/Data/Migrations.lua'),`n" +
	"}`n" +
	"local function createService(env)`n    local game, script, require, Instance, Random, Vector3, task = env.game, env.script, env.require, env.Instance, env.Random, env.Vector3, env.task`n$(Source 'src/server/Services/HeroService.lua')`nend`n" +
	"local suite = '$Suite'`n" +
	"local results = {}`n" +
	"if suite == 'all' or suite == 'rules' then table.insert(results, { pcall($(Module 'src/server/Tests/HeroRules.spec.lua'), HeroRules, modules.HeroConfig, modules.CombatConfig) }) end`n" +
	"if suite == 'all' or suite == 'migrations' then table.insert(results, { pcall($(Module 'src/server/Tests/Migrations.spec.lua'), modules.Migrations, HeroRules, modules.HeroConfig.HotbarSize) }) end`n" +
	"if suite == 'all' or suite == 'summon' then table.insert(results, { pcall($(Module 'src/server/Tests/HeroService.spec.lua'), createService, modules) }) end`n" +
	"for _, r in results do if not r[1] then error(r[2]) end end`n"
$runnerPath = Join-Path $testBuild "hero-tests-$Suite.luau"
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Hero tests ($Suite) failed (exit $LASTEXITCODE)" }
