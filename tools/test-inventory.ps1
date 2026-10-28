param([string]$LuauPath = 'luau')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testBuild = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $testBuild | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }

# Inventaire (#72) : InventoryRules (pur) avec les vrais catalogues, puis le vrai InventoryService (remotes en
# lecture seule, vue, identifiants) avec des doubles de DataService et des API moteur.
$runner = "local ItemConfig = $(Module 'src/shared/Config/ItemConfig.lua')`n" +
	"local ResourceConfig = $(Module 'src/shared/Config/ResourceConfig.lua')`n" +
	"local InventoryRules = $(Module 'src/server/Inventory/InventoryRules.lua')`n" +
	"local modules = { Item = ItemConfig, Resource = ResourceConfig, ItemConfig = ItemConfig, ResourceConfig = ResourceConfig, LootConfig = $(Module 'src/server/Config/LootConfig.lua'), RarityConfig = $(Module 'src/shared/Config/RarityConfig.lua'), EquipmentConfig = $(Module 'src/server/Config/EquipmentConfig.lua'), EquipmentRules = $(Module 'src/server/Inventory/EquipmentRules.lua') }`n" +
	"local function createService(env)`n    local game, script, require, Instance = env.game, env.script, env.require, env.Instance`n$(Source 'src/server/Services/InventoryService.lua')`nend`n" +
	"local ok1, err1 = pcall($(Module 'src/server/Tests/InventoryRules.spec.lua'), InventoryRules, modules)`n" +
	"local ok2, err2 = pcall($(Module 'src/server/Tests/InventoryService.spec.lua'), createService, InventoryRules, modules)`n" +
	"if not ok1 then error(err1) end`nif not ok2 then error(err2) end`n"
$runnerPath = Join-Path $testBuild 'inventory-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "Inventory tests failed (exit $LASTEXITCODE)" }
