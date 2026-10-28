param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Équipement (#73) : EquipmentRules (pur) avec les vrais ItemConfig, RarityConfig, EquipmentConfig, CombatConfig et la
# vraie progression de niveau, puis le vrai EquipmentService avec des doubles de DataService, HeroService,
# InventoryService, CombatService et des API moteur (horloge comprise).
$runner = "local modules = {`n" +
	"    ItemConfig = $(Module 'src/shared/Config/ItemConfig.lua'),`n" +
	"    RarityConfig = $(Module 'src/shared/Config/RarityConfig.lua'),`n" +
	"    EquipmentConfig = $(Module 'src/server/Config/EquipmentConfig.lua'),`n" +
	"    CombatConfig = $(Module 'src/server/Config/CombatConfig.lua'),`n" +
	"    HeroProgressionConfig = $(Module 'src/server/Config/HeroProgressionConfig.lua'),`n" +
	"    HeroProgressionRules = $(Module 'src/server/Heroes/HeroProgressionRules.lua'),`n" +
	"}`n" +
	"local EquipmentRules = $(Module 'src/server/Inventory/EquipmentRules.lua')`n" +
	"local function createService(env)`n    local game, script, require, Instance, os = env.game, env.script, env.require, env.Instance, env.os`n$(Source 'src/server/Services/EquipmentService.lua')`nend`n" +
	"local ok1, err1 = pcall($(Module 'src/server/Tests/EquipmentRules.spec.lua'), EquipmentRules, modules)`n" +
	"local ok2, err2 = pcall($(Module 'src/server/Tests/EquipmentService.spec.lua'), createService, EquipmentRules, modules)`n" +
	"if not ok1 then error(err1) end`nif not ok2 then error(err2) end`n"
$runnerPath = Join-Path $testBuild 'equipment-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Equipment tests failed (exit $LASTEXITCODE)" }
