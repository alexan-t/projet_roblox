param([string]$LuauPath = 'luau')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$build = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
function Source([string]$path) { Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw -Encoding UTF8 }
function Module([string]$path) { "(function()`n$(Source $path)`nend)()" }
function Factory([string]$path) { "function(game, script, require)`n$(Source $path)`nend" }
# Doubles uniquement pour les types moteur et dépendances visuelles non exécutées.
# Le thème, les raretés et les deux contrôleurs sont les vrais modules complets.
$runner = @'
local enumGroup = setmetatable({}, { __index = function(_, key) return key end })
local Enum = setmetatable({}, { __index = function() return enumGroup end })
local Color3 = { fromHex = function(value) return value end }
local Font = { new = function(value) return value end }
local UDim = { new = function(...) return {...} end }
local UDim2 = { fromOffset = function(...) return {...} end }
local TweenInfo = { new = function(time) return { Time = time } end }
'@
$runner += "`nlocal theme = $(Module 'src/shared/Config/UITheme.lua')`n"
$runner += "local rarity = $(Module 'src/shared/Config/RarityConfig.lua')`n"
$runner += "local ultimate = $(Factory 'src/client/Controllers/UltimateEffectController.lua')`n"
$runner += "local summon = $(Factory 'src/client/Controllers/SummonEffectController.lua')`n"
$runner += "local rarityStyle = $(Factory 'src/client/UI/RarityStyle.lua')`n"
$runner += "$(Module 'tests/ui-effects.runtime.luau')(theme, rarity, ultimate, summon, rarityStyle)`n"
$runnerPath = Join-Path $build 'ui-effects-tests.luau'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $LuauPath $runnerPath
if ($LASTEXITCODE -ne 0) { throw "UI effects tests failed (exit $LASTEXITCODE)" }
